
(in-package #:cl-cowsay/test)

(defmacro check-cowsay-condition (name (initarg value) reader &rest report-substrings)
  "Register common inheritance, accessor, and report checks for a condition."
  `(describe ,(string-downcase (symbol-name name))
     (it "is a cl-cowsay-error"
       (expect (typep (make-condition ',name ,initarg ,value) 'cl-cowsay-error)
               :to-be-truthy))

     (it ,(format nil "exposes the value via ~(~A~)" reader)
       (expect (equal (,reader (make-condition ',name ,initarg ,value)) ,value)
               :to-be-truthy))

     (it "reports every expected substring"
       (let ((text (princ-to-string (make-condition ',name ,initarg ,value))))
         (with-soft-assertions
           ,@(mapcar (lambda (substring) `(expect (search ,substring text) :to-be-truthy))
                     report-substrings))))))

(describe "cl-cowsay-error"
  (it "reports a generic message when signaled directly"
    (expect (search "cl-cowsay" (princ-to-string (make-condition 'cl-cowsay-error)))
            :to-be-truthy)))

(check-cowsay-condition unknown-character (:name "nope") unknown-character-name
  "nope" "cow")

(check-cowsay-condition unknown-eyes-preset (:name "nope") unknown-eyes-preset-name
  "nope" "borg")

(check-cowsay-condition invalid-message (:width 0) invalid-message-width
  "0")

(check-cowsay-condition stdin-too-large (:limit 65536) stdin-too-large-limit
  "65536")

(check-cowsay-condition invalid-timeout (:seconds 0) invalid-timeout-seconds "0")

(check-cowsay-condition operation-timeout (:operation :test) operation-timeout-operation "TEST")

(describe "operation timeouts"
  (it "returns the body value within a positive timeout"
    (expect (= (with-operation-timeout (:test 1) 42) 42) :to-be-truthy))

  (it "rejects non-positive and non-real timeouts"
    (with-soft-assertions
      (signals invalid-timeout (with-operation-timeout (:test 0) t))
      (signals invalid-timeout (with-operation-timeout (:test -1) t))
      (signals invalid-timeout (with-operation-timeout (:test "1") t))))

  (it "signals operation-timeout after the deadline"
    (signals operation-timeout (with-operation-timeout (:test 0.001) (sleep 0.05)))))
