;;;; t/render-test.lisp

(in-package #:cl-cowsay/test)

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
    (expect (stringp (say "" :no-wrap t)) :to-be-truthy)))
