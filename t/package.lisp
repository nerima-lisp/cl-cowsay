;;;; t/package.lisp
(defpackage #:cl-cowsay/test
  (:use #:cl #:cl-cowsay)
  ;; DESCRIBE clashes with CL:DESCRIBE, so shadow-import cl-weave's.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   ;; Registration and assertions
   #:it #:it-each #:expect #:signals #:run-all
   ;; Soft (all-failures-collected) assertions
   #:with-soft-assertions
   ;; Mocks and spies
   #:with-mocked-functions
   ;; Property-based and fuzz testing
   #:it-property #:it-fuzz #:gen-string #:gen-member #:gen-list)
  (:import-from #:cl-cowsay/cli
   #:*cowsay-app*
   #:main
   #:image-entry-point)
  (:import-from #:cl-cli
   #:parse-argv
   #:run-app
   #:option-value
   #:positional-value
   #:cli-invalid-option-value
   #:current-process-argv)
  (:export #:run-tests))

(in-package #:cl-cowsay/test)

(defun run-tests (&key coverage)
  "Run every registered spec and signal an error when any spec fails. When COVERAGE is true, enforce 100% executable expression and branch coverage for the instrumented source tree."
  (unless
      (if coverage
          (let ((src (asdf:component-pathname
                      (asdf:find-system "cl-cowsay"))))
            (flet ((src-file (name)
                     (merge-pathnames name src)))
              (run-all
               :reporter :spec
               :timeout-ms 10000
               :coverage t
               :coverage-reset t
               :coverage-include-pathnames (list src)
               :coverage-exclude-pathnames
               (mapcar
                (function src-file)
                (list "package.lisp"
                      "macros.lisp"
                      "conditions.lisp"
                      "characters-data.lisp"
                      "characters-definitions.lisp"
                      "eyes-data.lisp"
                      "bubble-data.lisp"
                      "cli-package.lisp"
                      "cli-configuration.lisp"
                      "cli-definition.lisp"))
               :coverage-minimum-expression 100
               :coverage-minimum-branch 100)))
          (run-all :reporter :spec :timeout-ms 10000))
    (error "cl-cowsay test suite failed"))
  (format t "~&cl-cowsay/test: successful completion with 0 failures~%")
  t)

(defun render-to-string (message &rest keys) "Collect WRITE-SAY output for test expectations." (with-output-to-string (stream) (apply (function write-say) message stream keys)))
