;;;; t/bubble-test.lisp

(in-package #:cl-cowsay/test)

(describe "bubble-lines"
  (it "wraps a single line in a three-row box"
    (let ((lines (cl-cowsay::bubble-lines (list "hi") :speech)))
      (expect (= (length lines) 3) :to-be-truthy)))

  (it "produces one content row per input line, plus a top and bottom rule"
    (let ((lines (cl-cowsay::bubble-lines (list "one" "two" "three") :speech)))
      (expect (= (length lines) 5) :to-be-truthy)))

  (it "still produces a three-row box for an empty line list"
    (let ((lines (cl-cowsay::bubble-lines '() :speech)))
      (expect (= (length lines) 3) :to-be-truthy)))

  (it "uses \"_\" on the top rule and \"-\" on the bottom rule"
    (let ((lines (cl-cowsay::bubble-lines (list "hi") :speech)))
      (with-soft-assertions
        (expect (every (lambda (char) (char= char #\_)) (subseq (first lines) 1))
                :to-be-truthy)
        (expect (every (lambda (char) (char= char #\-)) (subseq (third lines) 1))
                :to-be-truthy))))

  (it-each ((:speech #\|) (:thought #\:))
      "in ~S mode, uses ~S as the side character"
      (mode side)
    (let ((line (second (cl-cowsay::bubble-lines (list "hi") mode))))
      (with-soft-assertions
        (expect (char= (char line 0) side) :to-be-truthy)
        (expect (char= (char line (1- (length line))) side) :to-be-truthy))))

  (it "pads every content row to the width of the longest input line"
    (let ((lines (cl-cowsay::bubble-lines (list "a" "much longer line") :speech)))
      ;; Both content rows (indices 1 and 2) must end up the same length.
      (expect (= (length (second lines)) (length (third lines))) :to-be-truthy)))

  ;; Generalizes the row-count and equal-padding cases above across
  ;; arbitrary generated line lists: LINES rows plus a top and bottom rule
  ;; (or exactly 3 for an empty LINES), and every content row padded to one
  ;; shared width.
  (it-property "always produces (length lines)+2 rows with equal-width content rows"
      ((lines (gen-list (gen-string :min-length 0 :max-length 12 :alphabet "abc")
                        :min-length 0 :max-length 6))
       (mode (gen-member '(:speech :thought))))
    (let* ((result (cl-cowsay::bubble-lines lines mode))
           (content (butlast (rest result))))
      (with-soft-assertions
        (expect (= (length result) (if lines (+ (length lines) 2) 3)) :to-be-truthy)
        (expect (= (length (remove-duplicates (mapcar #'length content) :test #'=)) 1)
                :to-be-truthy))))

  (it "writes the same rows as BUBBLE-LINES, including for combining characters"
    (let ((content (list (format nil "A~C" (code-char #x4E2D))
                          (format nil "e~C" (code-char #x0301)))))
      (expect (string= (format nil "~{~A~^~%~}" (cl-cowsay::bubble-lines content :thought))
                        (with-output-to-string (stream)
                          (cl-cowsay::%write-bubble content :thought stream)))
              :to-be-truthy))))

(describe "single-line streaming bubble"
  (it "renders from the precomputed width"
    (let ((actual (with-output-to-string (stream)
                    (cl-cowsay::%write-single-line-bubble "hello" 5 :speech stream))))
      (expect (string= " _______
| hello |
 -------" actual) :to-be-truthy))))
