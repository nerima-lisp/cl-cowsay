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

(defparameter *coverage-measured-sources*
  '("bubble.lisp"
    "characters.lisp"
    "cli.lisp"
    "eyes.lisp"
    "render.lisp"
    "template.lisp"
    "wrap.lisp")
  "The exact src/ files the coverage gate is required to have measured.

PINNED LITERALLY, and pinned INDEPENDENTLY of the :COVERAGE-EXCLUDE-PATHNAMES
argument in RUN-TESTS. Deriving it -- \"every .lisp in src/ that is not in the
exclusion list\" -- is the one shape that cannot work here, because the hole
this list closes is somebody widening the exclusion list, and a derived
expectation narrows in step with it and stays green.

CHANGING THE MEASURED SET THEREFORE TAKES TWO EDITS THAT MUST AGREE: this
list, and the :COVERAGE-EXCLUDE-PATHNAMES list in RUN-TESTS below. The
duplication is the mechanism, not an oversight; a reviewer seeing only one of
the two edits is seeing an incomplete change.

Names rather than a count, because a count of seven is equally satisfied by
dropping one file and admitting another. Names rather than an expression or
branch total, because those move on every ordinary edit to src/ and a gate
that fails for reasons unrelated to its subject gets loosened.")

(defun coverage-measured-sources (include-pathnames exclude-pathnames)
  "Return, sorted, the file names SB-COVER holds coverage data for under the
same filtering CL-WEAVE:COVERAGE-STATISTICS applies before it sums anything.

This mirrors cl-weave 1.3.0 src/runner-coverage.lisp:122-143 step for step --
the same REFRESH-COVERAGE-BITS, the same *CODE-COVERAGE-INFO* table, a matcher
from the same COVERAGE-SOURCE-MATCHER over the same two lists, the same
(PROBE-FILE SOURCE) guard. That is deliberate: the result is not an
approximation of the set the thresholds were computed over, it is that set.
Both alternatives answer a subtly different question -- scraping the HTML
report counts files sb-cover chose to render (and sb-cover supersedes report
files rather than clearing the directory, so a previous run's leftovers would
pad the count), and reimplementing the matcher here would compare against a
set cl-weave never used.

The cost is naming three cl-weave internals. It is a cost worth paying because
its failure mode is safe: if a later cl-weave renames any of them, this call
signals at gate time rather than quietly measuring less.

SB-COVER is reached through cl-weave's FIND-SYMBOL wrappers rather than read
syntax because that package does not exist in the ordinary uninstrumented run
that loads this same file, where the reader would fail on SB-COVER:: outright."
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
  "Assert that the coverage run measured exactly *COVERAGE-MEASURED-SOURCES*.

Defends against a PARTIAL measurement, which the thresholds cannot see. They
compare a ratio: CHECK-COVERAGE-THRESHOLDS
(cl-weave/src/runner-coverage.lisp:148-158) reads only the covered/total
quotient, and COVERAGE-PERCENTAGE (:145-146) answers 100.0 when the total is
zero. Neither ever looks at how much was totalled. cl-weave's one emptiness
guard (:171-174) fires only when NO file matched at all, and the report it
guards is built from the very same include/exclude lists as the statistics
(:128 and :163), so narrowing those lists narrows the guard with them.

So the cheapest way to make this gate green when it goes red is a one-line
edit: add the offending file to :COVERAGE-EXCLUDE-PATHNAMES. Six files still
match, the emptiness guard stays silent, the ratio is still 100%, the spec
count is untouched -- and a whole source file's coverage requirement has been
deleted with nothing to show for it in the output. That is the move this
function exists to stop, and it is worth stopping precisely because it is the
one a future session under time pressure will reach for first.

Comparing the measured NAMES also happens to catch two failures the ratio
cannot: a src/ file dropped from cl-cowsay.asd's :components is never compiled,
so sb-cover has no entry for it and it goes missing from this set; and a run
where instrumentation was never proclaimed populates no entries at all, so the
set is empty rather than scoring a vacuous 100%."
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
    ;; Say what was measured even when it is correct. A gate that prints only
    ;; on failure asks the reader to trust that it ran; this one line is the
    ;; difference between a log that shows the breadth check firing and a log
    ;; in which its absence and its success look identical.
    (format t "~&cl-cowsay/test: coverage measured ~D file~:P: ~{~A~^ ~}~%"
            (length measured) measured)
    measured))

(defun run-tests (&key coverage)
  "Run every registered spec and signal an error when any spec fails. When
COVERAGE is true, enforce 100% executable expression and branch coverage
for the instrumented source tree.

The coverage branch below is armed against the three ways this gate can report
green while measuring nothing, or nearly nothing. None of the three announces
itself: an empty suite, an empty coverage measurement, and a measurement over
a silently shortened file list all print the same success line a real run
prints. That is why the first two need arguments passed explicitly rather than
left at their permissive defaults, and why the third needs an assertion
(CHECK-COVERAGE-BREADTH) that cl-weave has no argument for at all."
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
                        ;; Defends against ZERO EXPRESSIONS MEASURED. The two
                        ;; thresholds below cannot detect their own vacuity:
                        ;; cl-weave computes a percentage as (if (zerop total)
                        ;; 100.0 ...), so a run where sb-cover recorded nothing
                        ;; at all -- instrumentation never proclaimed, the
                        ;; system loaded from stale FASLs instead of
                        ;; recompiled, the include/exclude filters drifted
                        ;; until they select no file -- scores a perfect 100%
                        ;; against both minimums and passes. cl-weave's only
                        ;; emptiness check lives in its report writer, which it
                        ;; runs solely when a report directory is supplied;
                        ;; supplying one is therefore what arms it, and it
                        ;; errors with "did not capture any coverage data"
                        ;; instead of certifying the void.
                        ;;
                        ;; It stops at ZERO, though. Against a measurement that
                        ;; is merely SHORTER than it should be it is silent,
                        ;; because it is built from the same two lists as the
                        ;; statistics. CHECK-COVERAGE-BREADTH below is what
                        ;; covers that case.
                        ;;
                        ;; The directory is relative, so it resolves against
                        ;; the process working directory: the build tree under
                        ;; the Nix coverage derivation, this checkout in a dev
                        ;; shell. It is deliberately NOT the name cl-nix-forge's
                        ;; own runner writes (that report is the derivation's
                        ;; published $out and must not be overwritten by this
                        ;; filtered one), and the org-standard .gitignore
                        ;; already reserves this name.
                        :coverage-report-directory #P"coverage-report/"
                        :coverage-minimum-expression 100
                        :coverage-minimum-branch 100
                        ;; Defends against ALL SPECS MISSING -- see the plain
                        ;; branch below, where the reasoning and the limits of
                        ;; that defence are spelled out.
                        :pass-with-no-tests nil)))
                ;; Defends against a PARTIAL measurement, the one hole neither
                ;; argument above reaches. Runs after RUN-ALL because the
                ;; thresholds are evaluated in its unwind, so by this point the
                ;; sb-cover state is exactly the state they were computed from.
                (check-coverage-breadth include-pathnames exclude-pathnames)
                passed)))
          ;; Defends against ALL SPECS MISSING. RUN-ALL answers "did every
          ;; collected spec pass?", and over an empty collection that is
          ;; vacuously true: its PASS-WITH-NO-TESTS default of T makes an empty
          ;; run indistinguishable from a green one. Passing NIL makes an empty
          ;; collection a failure, which is the same choice cl-weave makes for
          ;; its own bootstrap.
          ;;
          ;; Be exact about the reach of this, because it is narrower than it
          ;; looks: it fires only when the collection is EMPTY. Dropping ONE
          ;; spec file from cl-cowsay.asd's :components -- or renaming one out
          ;; of the component list, or reordering loads so one file registers
          ;; nothing -- still leaves the other eight registering their specs,
          ;; and the run is green with the lost file's coverage simply gone.
          ;; What this argument rejects is the total collapse: every component
          ;; gone, the test package failing to load, a filter matching nothing.
          ;; Nothing here reconciles the nine spec files on disk against the
          ;; nine in :components, and until something does, that gap is open.
          (run-all :reporter :spec :timeout-ms 10000
                   :pass-with-no-tests nil))
    (error "cl-cowsay test suite failed"))
  (format t "~&cl-cowsay/test: successful completion with 0 failures~%")
  t)

(defun render-to-string (message &rest keys)
  "Collect WRITE-SAY output for test expectations."
  (with-output-to-string (stream)
    (apply #'write-say message stream keys)))
