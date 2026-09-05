
(in-package #:cl-cowsay/test)

(defun %materialize-streaming-bubble-lines (lines mode)
  "Return the streaming bubble output as a list of lines for assertions."
  (let ((rendered (with-output-to-string (stream)
                    (cl-cowsay::%write-bubble lines mode stream))))
    (with-input-from-string (stream rendered)
      (loop for line = (read-line stream nil :eof)
            until (eq line :eof)
            collect line))))

(describe "streaming bubble"
  (it "wraps a single line in a three-row box"
    (let ((lines (%materialize-streaming-bubble-lines (list "hi") :speech)))
      (expect (= (length lines) 3) :to-be-truthy)))

  (it "produces one content row per input line, plus a top and bottom rule"
    (let ((lines (%materialize-streaming-bubble-lines (list "one" "two" "three") :speech)))
      (expect (= (length lines) 5) :to-be-truthy)))

  (it "still produces a three-row box for an empty line list"
    (let ((lines (%materialize-streaming-bubble-lines '() :speech)))
      (expect (= (length lines) 3) :to-be-truthy)))

  (it "uses \"_\" on the top rule and \"-\" on the bottom rule"
    (let ((lines (%materialize-streaming-bubble-lines (list "hi") :speech)))
      (with-soft-assertions
        (expect (every (lambda (char) (char= char #\_)) (subseq (first lines) 1))
                :to-be-truthy)
        (expect (every (lambda (char) (char= char #\-)) (subseq (third lines) 1))
                :to-be-truthy))))

  (it-each ((:speech #\|) (:thought #\:))
      "in ~S mode, uses ~S as the side character"
      (mode side)
    (let ((line (second (%materialize-streaming-bubble-lines (list "hi") mode))))
      (with-soft-assertions
        (expect (char= (char line 0) side) :to-be-truthy)
        (expect (char= (char line (1- (length line))) side) :to-be-truthy))))

  (it "pads every content row to the width of the longest input line"
    (let ((lines (%materialize-streaming-bubble-lines (list "a" "much longer line") :speech)))
      (expect (= (length (second lines)) (length (third lines))) :to-be-truthy)))
  (it-property "always produces (length lines)+2 rows with equal-width content rows"
      ((lines (gen-list (gen-string :min-length 0 :max-length 12 :alphabet "abc")
                        :min-length 0 :max-length 6))
       (mode (gen-member '(:speech :thought))))
    (let* ((result (%materialize-streaming-bubble-lines lines mode))
           (content (butlast (rest result))))
      (with-soft-assertions
        (expect (= (length result) (if lines (+ (length lines) 2) 3)) :to-be-truthy)
        (expect (= (length (remove-duplicates (mapcar #'length content) :test #'=)) 1)
                :to-be-truthy))))

  (it "writes the expected rows, including for combining characters"
    (let* ((combining (code-char #x0301))
           (cjk (code-char #x4E2D))
           (content (list (format nil "A~C" cjk)
                          (format nil "e~C" combining)))
           (expected (format nil " _____~%: A~C :~%: e~C   :~% -----"
                             cjk combining)))
      (expect (string= expected
                       (with-output-to-string (stream)
                         (cl-cowsay::%write-bubble content :thought stream)))
              :to-be-truthy))))
