
(in-package #:cl-cowsay/test)

(describe "%split-on-newlines"
  (it-each (("" (""))
            ("no newlines here" ("no newlines here"))
            ("a
b" ("a" "b"))
            ("a

b" ("a" "" "b"))
            ("trailing
" ("trailing" "")))
      "splits ~S into ~S"
      (message expected)
    (expect (equal (cl-cowsay::%split-on-newlines message) expected) :to-be-truthy)))

(describe "write-say"
  (it "renders \"hi\" with the default cow character exactly"
    (expect (render-to-string "hi")
            :to-match-inline-snapshot
            "\" ____
| hi |
 ----
        \\\\   ^__^
         \\\\  (oo)
            (__)
             u  u\""))

  (it "renders every built-in character without error"
    (expect (every (lambda (name) (stringp (render-to-string "hello" :character name)))
                   (list-characters))
            :to-be-truthy))

  (it "defaults to the \"cow\" character"
    (expect (string= (render-to-string "hi") (render-to-string "hi" :character "cow")) :to-be-truthy))
  (it "uses WRITE-SAY's documented defaults when no keyword overrides are supplied"
    (let* ((short (make-string 35 :initial-element #\a))
           (long (format nil "~A ~A" short short))
           (short-render (render-to-string short))
           (long-render (render-to-string long)))
      (with-soft-assertions
        (expect (search "^__^" short-render) :to-be-truthy)
        (expect (search "(oo)" short-render) :to-be-truthy)
        (expect (search "u  u" short-render) :to-be-truthy)
        (expect (find #\| short-render) :to-be-truthy)
        (expect (not (find #\: short-render)) :to-be-truthy)
        (expect (find #\\ short-render) :to-be-truthy)
        (expect (= (count #\| short-render) 2) :to-be-truthy)
        (expect (= (count #\| long-render) 4) :to-be-truthy)
        (expect (string= (subseq short-render 0 (+ 3 (length short)))
                         (format nil " ~A" (make-string (+ 2 (length short))
                                                        :initial-element #\_)))
                :to-be-truthy))))

  (it "is case-insensitive about the character name"
    (expect (string= (render-to-string "hi" :character "COW") (render-to-string "hi" :character "cow"))
            :to-be-truthy))

  (it "signals unknown-character for an unregistered character"
    (signals unknown-character (render-to-string "hi" :character "not-a-real-character")))

  (it "signals invalid-message for a non-positive width"
    (signals invalid-message (render-to-string "hi" :width 0)))

  (it "signals invalid-message for a non-integer width"
    (signals invalid-message (render-to-string "hi" :width 3.5)))

  (it "signals type-error for a non-string message"
    (signals type-error (render-to-string 42)))

  (it "signals type-error for an unsupported mode"
    (signals type-error (render-to-string "hi" :mode :invalid)))

  (it "renders an empty message without error"
    (expect (stringp (render-to-string "")) :to-be-truthy))

  (it "hard-wraps a single word longer than the requested width"
    (let* ((word (make-string 80 :initial-element #\a))
           (result (render-to-string word :width 20))
           (lines '())
           (start 0))
      (loop for newline = (position #\Newline result :start start)
            do (push (subseq result start (or newline (length result))) lines)
            while newline
            do (setf start (1+ newline)))
      (expect (every (lambda (line) (<= (length line) 24)) lines) :to-be-truthy)))

  (it "honors embedded newlines in a multi-line message as forced breaks"
    (let ((result (render-to-string (format nil "line one~%line two"))))
      (with-soft-assertions
        (expect (search "line one" result) :to-be-truthy)
        (expect (search "line two" result) :to-be-truthy))))

  (it "applies an :eyes override"
    (expect (search "^^" (render-to-string "hi" :eyes "^^")) :to-be-truthy))

  (it "applies a :tongue override"
    (expect (search "U" (render-to-string "hi" :character "cow" :tongue "U")) :to-be-truthy))

  (it "uses a backslash thoughts connector in :speech mode"
    (expect (search "\\" (render-to-string "hi" :mode :speech)) :to-be-truthy))

  (it "uses an \"o\" thoughts connector in :thought mode"
    (expect (search (string #\o) (render-to-string "hi" :mode :thought)) :to-be-truthy))

  (it "draws a \"|\"-sided bubble in :speech mode and a \":\"-sided one in :thought mode"
    (with-soft-assertions
      (expect (find #\| (render-to-string "hi" :mode :speech)) :to-be-truthy)
      (expect (find #\: (render-to-string "hi" :mode :thought)) :to-be-truthy)))

  (it "keeps a message on a single bubble line when :no-wrap is true, even past width"
    (let* ((long (make-string 60 :initial-element #\a))
           (result (render-to-string long :no-wrap t :width 10)))
      (expect (= (count #\| result) 2) :to-be-truthy)))

  (it "still honors embedded newlines as forced breaks when :no-wrap is true"
    (let ((result (render-to-string (format nil "line one~%line two") :no-wrap t)))
      (with-soft-assertions
        (expect (search "line one" result) :to-be-truthy)
        (expect (search "line two" result) :to-be-truthy))))

  (it "renders an empty message without error when :no-wrap is true"
    (expect (stringp (render-to-string "" :no-wrap t)) :to-be-truthy))

  (it "renders empty paragraphs through the Unicode wrapper"
    (expect (= (count #\| (render-to-string (format nil "~%"))) 4) :to-be-truthy))
  (it-fuzz "renders non-empty output with the basic cow art"
      ((message (gen-string :min-length 0 :max-length 200)))
      (:trials 200 :timeout-per-trial 2)
    (let ((output (render-to-string message)))
      (with-soft-assertions
        (expect (plusp (length output)) :to-be-truthy)
        (expect (search "^__^" output) :to-be-truthy)
        (expect (search "(oo)" output) :to-be-truthy))))

  (it "combines ASCII validation with allocation-free wrapping analysis"
    (multiple-value-bind (width ascii-p) (cl-cowsay::%ascii-wrapped-maximum-width "hello  world" 40)
      (with-soft-assertions
        (expect ascii-p :to-be-truthy)
        (expect (= width 11) :to-be-truthy)))
    (multiple-value-bind (width ascii-p)
        (cl-cowsay::%ascii-wrapped-maximum-width (format nil "hello~%world") 40)
      (with-soft-assertions
        (expect (null width) :to-be-truthy)
        (expect (null ascii-p) :to-be-truthy)))))

(describe "stream rendering"
  (it "matches write-say for normal and staged-placeholder substitutions"
    (let ((message "hello world")
          (keys (list :character "cow" :mode :speech :eyes "^^" :tongue "U" :width 12)))
      (expect (string= (apply #'render-to-string message keys)
                        (with-output-to-string (stream)
                          (apply #'write-say message stream keys)))
              :to-be-truthy))
    (let ((message (format nil "first line~%second line"))
          (keys (list :character "cow" :mode :thought :eyes "${tongue}" :tongue "U" :width 8)))
      (expect (string= (apply #'render-to-string message keys)
                        (with-output-to-string (stream)
                          (apply #'write-say message stream keys)))
              :to-be-truthy)))

  (it "matches write-say for :no-wrap"
    (let ((message (format nil "line one~%line two"))
          (keys (list :character "cow" :no-wrap t)))
      (expect (string= (apply #'render-to-string message keys)
                        (with-output-to-string (stream)
                          (apply #'write-say message stream keys)))
              :to-be-truthy)))

  (it-property "matches write-say for generated ASCII messages"
      ((message (gen-string :min-length 0 :max-length 60 :alphabet "abc ")))
    (expect (string= (render-to-string message)
                     (with-output-to-string (stream)
                       (write-say message stream)))
            :to-be-truthy))

  (it "matches fill-template-line for every placeholder slot"
    (let ((line "${thoughts} (${eyes}) ${tongue}"))
      (expect
       (string=
        (cl-cowsay::fill-template-line line
                                       :eyes "oo"
                                       :tongue "U"
                                       :thoughts "\\")
        (with-output-to-string (stream)
          (cl-cowsay::%write-staged-template-line line stream "oo" "U" "\\")))
       :to-be-truthy)))

  (it "validates write-say stream and text arguments"
    (with-soft-assertions
      (signals type-error (write-say "hi" 42))
      (signals type-error
        (write-say "hi" (make-string-output-stream) :character 42))
      (signals type-error
        (write-say "hi" (make-string-output-stream) :eyes 42))
      (signals type-error
        (write-say "hi" (make-string-output-stream) :tongue 42)))))

(describe "Unicode stream wrapping"
  (it "renders a CJK message with its display width through the public renderer"
    (let ((cjk (code-char #x4E2D)))
      (expect
       (string=
        (format nil " _____~%| A~C |~% -----~%        \\   ^__^~%         \\  (oo)~%            (__)~%             u  u"
                cjk)
        (render-to-string (format nil "A~C" cjk) :width 40))
       :to-be-truthy)))
  (it "renders consecutive spaces in a Unicode message through the public renderer"
    (let ((cjk (code-char #x4E2D)))
      (expect
       (string=
        (format nil " _____~%| A~C |~%| B   |~% -----~%        \\   ^__^~%         \\  (oo)~%            (__)~%             u  u"
                cjk)
        (render-to-string (format nil "A~C  B" cjk) :width 4))
       :to-be-truthy)))

  (it "matches cl-tty-kit wrapping for combining characters, newlines, and hard splits"
    (flet ((expect-match (message width &optional (mode :speech))
             (let ((expected (with-output-to-string (stream)
                                (cl-cowsay::%write-bubble (cl-tty-kit:wrap-string message width)
                                                           mode stream)))
                   (actual (multiple-value-bind (bubble-width character-widths)
                               (cl-cowsay::%wrapped-maximum-width message width)
                             (with-output-to-string (stream)
                               (cl-cowsay::%write-wrapped-bubble message width bubble-width mode
                                                                  stream character-widths)))))
               (expect (string= expected actual) :to-be-truthy))))
      (let ((combining (code-char #x0301))
            (cjk (code-char #x4E2D)))
        (expect-match (format nil "e~Ce~C word~%~C~C" combining combining cjk combining) 3)
        (expect-match (format nil "e~Ce~Ce~C" combining combining combining) 1)
        (expect-match (format nil "~C~C a ~C~C" cjk combining cjk combining) 3)
        (expect-match (format nil "~%~C~%~%" cjk) 1 :thought)))))

(describe "write-say timeouts"
  (it "accepts the timeout keyword at the public rendering boundary"
    (expect (plusp (length (render-to-string "hi" :timeout-seconds 1)))
            :to-be-truthy))

  (it "rejects an invalid timeout at the public rendering boundary"
    (signals invalid-timeout
      (write-say "hi" (make-string-output-stream) :timeout-seconds 0))))
