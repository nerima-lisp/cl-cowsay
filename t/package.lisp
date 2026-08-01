;;;; t/package.lisp
(defpackage #:cl-cowsay/test
  (:use #:cl #:cl-cowsay)
  ;; DESCRIBE clashes with CL:DESCRIBE, so shadow-import cl-weave's.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   ;; Registration and assertions
   #:it #:expect #:signals #:run-all
   ;; Soft (all-failures-collected) assertions
   #:with-soft-assertions)
  (:import-from #:cl-cowsay/cli
   #:make-cowsay-app)
  (:import-from #:cl-cli
   #:parse-argv
   #:run-app
   #:option-value
   #:positional-value
   #:cli-invalid-option-value)
  (:export #:run-tests))

(in-package #:cl-cowsay/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP
fails."
  (unless (run-all :reporter :spec :timeout-ms 10000)
    (error "cl-cowsay test suite failed"))
  (format t "~&cl-cowsay/test: successful completion with 0 failures~%")
  t)
