(defpackage #:cl-cowsay/test
  (:use #:cl #:cl-cowsay)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:it-each #:expect #:signals #:run-all
   #:with-soft-assertions
   #:with-mocked-functions
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

(defparameter *coverage-measured-sources*
  '("bubble.lisp"
    "characters.lisp"
    "cli.lisp"
    "eyes.lisp"
    "render.lisp"
    "template.lisp"
    "wrap.lisp")
  "Source names required by the coverage gate.")

(defun coverage-measured-sources (include-pathnames exclude-pathnames)
  "Return source names included by the coverage matcher."
  (let ((refresh (cl-weave::coverage-internal-symbol "REFRESH-COVERAGE-BITS" t))
        (info (cl-weave::coverage-internal-symbol "*CODE-COVERAGE-INFO*" t))
        (matcher (cl-weave::coverage-source-matcher include-pathnames
                                                    exclude-pathnames))
        (names '()))
    (funcall refresh)
    (maphash (lambda (source coverage-record)
               (declare (ignore coverage-record))
               (when (and (funcall matcher source) (probe-file source))
                 (pushnew (file-namestring source) names :test #'string=)))
             (cl-weave::coverage-info-hash-table info))
    (sort names #'string<)))

(defun check-coverage-breadth (include-pathnames exclude-pathnames)
  "Assert that coverage measured the expected source set."
  (let ((measured (coverage-measured-sources include-pathnames exclude-pathnames))
        (expected (sort (copy-list *coverage-measured-sources*) #'string<)))
    (unless (equal measured expected)
      (error "cl-cowsay coverage breadth check failed.~@
              ~2Tmeasured: ~{~A~^ ~}~@
              ~2Texpected: ~{~A~^ ~}~@
              The 100% expression and branch thresholds are ratios and cannot ~
              detect this: they are equally satisfied by fewer files. If the ~
              measured set shrank, something removed a file from measurement ~
              -- most likely a new entry in :COVERAGE-EXCLUDE-PATHNAMES, or a ~
              src/ file dropped from cl-cowsay.asd's :components. If the ~
              change was intended, edit *COVERAGE-MEASURED-SOURCES* in the ~
              same commit and say why."
             measured expected))
    (format t "~&cl-cowsay/test: coverage measured ~D file~:P: ~{~A~^ ~}~%"
            (length measured) measured)
    measured))

(defun run-tests (&key coverage)
  "Run the test suite, optionally with coverage."
  (unless
      (if coverage
          (let ((src (asdf:component-pathname
                      (asdf:find-system "cl-cowsay"))))
            (flet ((src-file (name)
                     (merge-pathnames name src)))
              (let* ((include-pathnames (list src))
                     (exclude-pathnames
                       (mapcar
                        #'src-file
                        (list "package.lisp"
                              "macros.lisp"
                              "conditions.lisp"
                              "characters-data.lisp"
                              "characters-definitions.lisp"
                              "eyes-data.lisp"
                              "bubble-data.lisp"
                              "cli-package.lisp"
                              "cli-configuration.lisp"
                              "cli-definition.lisp")))
                     (passed
                       (run-all
                        :reporter :spec
                        :timeout-ms 10000
                        :coverage t
                        :coverage-reset t
                        :coverage-include-pathnames include-pathnames
                        :coverage-exclude-pathnames exclude-pathnames
                        :coverage-report-directory #P"coverage-report/"
                        :coverage-minimum-expression 100
                        :coverage-minimum-branch 100
                        :pass-with-no-tests nil)))
                (check-coverage-breadth include-pathnames exclude-pathnames)
                passed)))
          (run-all :reporter :spec :timeout-ms 10000
                   :pass-with-no-tests nil))
    (error "cl-cowsay test suite failed"))
  (format t "~&cl-cowsay/test: successful completion with 0 failures~%")
  t)

(defun render-to-string (message &rest keys)
  "Collect WRITE-SAY output for test expectations."
  (with-output-to-string (stream)
    (apply #'write-say message stream keys)))
