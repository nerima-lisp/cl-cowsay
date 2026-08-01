;;;; t/conditions-test.lisp

(in-package #:cl-cowsay/test)

(describe "unknown-character"
  (it "is a cl-cowsay-error"
    (expect (typep (make-condition 'unknown-character :name "nope") 'cl-cowsay-error)
            :to-be-truthy))

  (it "exposes the offending name via unknown-character-name"
    (expect (string= (unknown-character-name (make-condition 'unknown-character :name "nope"))
                     "nope")
            :to-be-truthy))

  (it "reports the offending name and the list of known characters"
    (let ((text (princ-to-string (make-condition 'unknown-character :name "nope"))))
      (with-soft-assertions
        (expect (search "nope" text) :to-be-truthy)
        (expect (search "cow" text) :to-be-truthy)))))

(describe "invalid-message"
  (it "is a cl-cowsay-error"
    (expect (typep (make-condition 'invalid-message :width 0) 'cl-cowsay-error)
            :to-be-truthy))

  (it "exposes the offending width via invalid-message-width"
    (expect (= (invalid-message-width (make-condition 'invalid-message :width -1)) -1)
            :to-be-truthy))

  (it "reports the offending width"
    (expect (search "0" (princ-to-string (make-condition 'invalid-message :width 0)))
            :to-be-truthy)))

(describe "stdin-too-large"
  (it "is a cl-cowsay-error"
    (expect (typep (make-condition 'stdin-too-large :limit 65536) 'cl-cowsay-error)
            :to-be-truthy))

  (it "exposes the configured limit via stdin-too-large-limit"
    (expect (= (stdin-too-large-limit (make-condition 'stdin-too-large :limit 65536)) 65536)
            :to-be-truthy))

  (it "reports the limit"
    (expect (search "65536" (princ-to-string (make-condition 'stdin-too-large :limit 65536)))
            :to-be-truthy)))
