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

  (it "uses \"|\" as the side character in :speech mode"
    (let ((line (second (cl-cowsay::bubble-lines (list "hi") :speech))))
      (with-soft-assertions
        (expect (char= (char line 0) #\|) :to-be-truthy)
        (expect (char= (char line (1- (length line))) #\|) :to-be-truthy))))

  (it "uses \":\" as the side character in :thought mode, distinct from :speech"
    (let ((line (second (cl-cowsay::bubble-lines (list "hi") :thought))))
      (with-soft-assertions
        (expect (char= (char line 0) #\:) :to-be-truthy)
        (expect (char= (char line (1- (length line))) #\:) :to-be-truthy))))

  (it "pads every content row to the width of the longest input line"
    (let ((lines (cl-cowsay::bubble-lines (list "a" "much longer line") :speech)))
      ;; Both content rows (indices 1 and 2) must end up the same length.
      (expect (= (length (nth 1 lines)) (length (nth 2 lines))) :to-be-truthy))))
