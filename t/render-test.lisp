;;;; t/render-test.lisp

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

(describe "say"
  ;; A snapshot, not piecemeal SEARCH/FIND assertions, is what actually
  ;; guards the bubble's exact layout -- box width, connector placement,
  ;; and the character art's alignment all move together on any change to
  ;; BUBBLE-LINES, FILL-TEMPLATE-LINE, or the "cow" character data, and a
  ;; partial match would miss a regression in any of the whitespace
  ;; between them. :TO-MATCH-INLINE-SNAPSHOT compares against
  ;; (WRITE-TO-STRING ACTUAL :ESCAPE T :READABLY NIL), so the literal below
  ;; is SAY's return value re-printed with escaping -- quote marks and each
  ;; backslash doubled -- not the raw rendered text.
  (it "renders \"hi\" with the default cow character exactly"
    (expect (say "hi")
            :to-match-inline-snapshot
            "\" ____
| hi |
 ----
        \\\\   ^__^
         \\\\  (oo)
            (__)
             u  u\""))

  (it "renders every built-in character without error"
    (expect (every (lambda (name) (stringp (say "hello" :character name)))
                   (list-characters))
            :to-be-truthy))

  (it "defaults to the \"cow\" character"
    (expect (string= (say "hi") (say "hi" :character "cow")) :to-be-truthy))

  (it "is case-insensitive about the character name"
    (expect (string= (say "hi" :character "COW") (say "hi" :character "cow"))
            :to-be-truthy))

  (it "signals unknown-character for an unregistered character"
    (signals unknown-character (say "hi" :character "not-a-real-character")))

  (it "signals invalid-message for a non-positive width"
    (signals invalid-message (say "hi" :width 0)))

  (it "signals invalid-message for a non-integer width"
    (signals invalid-message (say "hi" :width 3.5)))

  (it "renders an empty message without error"
    (expect (stringp (say "")) :to-be-truthy))

  (it "hard-wraps a single word longer than the requested width"
    (let* ((word (make-string 80 :initial-element #\a))
           (result (say word :width 20))
           (lines '())
           (start 0))
      (loop for newline = (position #\Newline result :start start)
            do (push (subseq result start (or newline (length result))) lines)
            while newline
            do (setf start (1+ newline)))
      ;; No line of output may exceed the bubble's own generated width, so a
      ;; wrapped word cannot leak an 80-character run into a single line.
      (expect (every (lambda (line) (<= (length line) 24)) lines) :to-be-truthy)))

  (it "honors embedded newlines in a multi-line message as forced breaks"
    (let ((result (say (format nil "line one~%line two"))))
      (with-soft-assertions
        (expect (search "line one" result) :to-be-truthy)
        (expect (search "line two" result) :to-be-truthy))))

  (it "applies an :eyes override"
    (expect (search "^^" (say "hi" :eyes "^^")) :to-be-truthy))

  (it "applies a :tongue override"
    (expect (search "U" (say "hi" :character "cow" :tongue "U")) :to-be-truthy))

  (it "uses a backslash thoughts connector in :speech mode"
    (expect (search "\\" (say "hi" :mode :speech)) :to-be-truthy))

  (it "uses an \"o\" thoughts connector in :thought mode"
    (expect (search (string #\o) (say "hi" :mode :thought)) :to-be-truthy))

  (it "draws a \"|\"-sided bubble in :speech mode and a \":\"-sided one in :thought mode"
    (with-soft-assertions
      (expect (find #\| (say "hi" :mode :speech)) :to-be-truthy)
      (expect (find #\: (say "hi" :mode :thought)) :to-be-truthy)))

  (it "keeps a message on a single bubble line when :no-wrap is true, even past width"
    ;; Exactly one content row means exactly two "|" characters in the whole
    ;; rendering (the row's left and right sides) -- a wrapped message would
    ;; produce more than one content row and so more than two.
    (let* ((long (make-string 60 :initial-element #\a))
           (result (say long :no-wrap t :width 10)))
      (expect (= (count #\| result) 2) :to-be-truthy)))

  (it "still honors embedded newlines as forced breaks when :no-wrap is true"
    (let ((result (say (format nil "line one~%line two") :no-wrap t)))
      (with-soft-assertions
        (expect (search "line one" result) :to-be-truthy)
        (expect (search "line two" result) :to-be-truthy))))

  (it "renders an empty message without error when :no-wrap is true"
    (expect (stringp (say "" :no-wrap t)) :to-be-truthy))

  ;; A fixed, always-valid :character and :width means the only two
  ;; conditions SAY ever signals (UNKNOWN-CHARACTER, INVALID-MESSAGE) are
  ;; both impossible here -- so a MESSAGE that makes it crash some other
  ;; way, on any generated string at all, is a real bug in SAY itself.
  (it-fuzz "never crashes on an arbitrary generated message"
      ((message (gen-string :min-length 0 :max-length 200)))
      (:trials 200 :timeout-per-trial 2)
    (say message))

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
  (it "matches say for normal and staged-placeholder substitutions"
    (let ((message "hello world")
          (keys (list :character "cow" :mode :speech :eyes "^^" :tongue "U" :width 12)))
      (expect (string= (apply #'say message keys)
                        (with-output-to-string (stream)
                          (apply #'cl-cowsay::%write-say message stream keys)))
              :to-be-truthy))
    (let ((message (format nil "first line~%second line"))
          (keys (list :character "cow" :mode :thought :eyes "${tongue}" :tongue "U" :width 8)))
      (expect (string= (apply #'say message keys)
                        (with-output-to-string (stream)
                          (apply #'cl-cowsay::%write-say message stream keys)))
              :to-be-truthy)))

  (it "matches say for :no-wrap"
    (let ((message (format nil "line one~%line two"))
          (keys (list :character "cow" :no-wrap t)))
      (expect (string= (apply #'say message keys)
                        (with-output-to-string (stream)
                          (apply #'cl-cowsay::%write-say message stream keys)))
              :to-be-truthy)))

  (it "matches fill-template-line for every placeholder slot"
    (let ((line "${thoughts} (${eyes}) ${tongue}"))
      (expect (string= (cl-cowsay::fill-template-line line :eyes "oo" :tongue "U" :thoughts "\\")
                        (with-output-to-string (stream)
                          (cl-cowsay::%write-template-line line stream "oo" "U" "\\" nil)))
              :to-be-truthy))))

(describe "Unicode stream wrapping"
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
