;;;; run-tests.lisp
;;;;
;;;; Bootstrap script: register this checkout, inherit the caller's ASDF
;;;; configuration for dependencies, and run the test system.
;;;;
;;;; The process exit goes through HOST-KIT:QUIT, not UIOP:QUIT. cl-cowsay
;;;; does not use UIOP anywhere -- src/cli.lisp's IMAGE-ENTRY-POINT and the
;;;; cl-host-kit input in flake.nix both record why -- and this file was the
;;;; last caller left over.
;;;;
;;;; HOST-KIT cannot be named literally in the form that runs the suite.
;;;; `sbcl --script` reads and evaluates one toplevel form at a time, and the
;;;; package does not exist until ASDF has loaded the test system's dependency
;;;; closure (cl-cowsay/test -> cl-cowsay/cli -> cl-host-kit), which happens
;;;; while that same form is being evaluated. So the symbol is resolved at run
;;;; time instead -- the shape cl-cli's own bootstrap uses, for this reason.
;;;;
;;;; Be precise about what the exit status does and does not tell you. A
;;;; failing suite exited non-zero before this change too -- ASDF's TEST-OP
;;;; signalled, nothing caught it, and the script aborted with a backtrace.
;;;; What changed is that the failure is now a named one-line diagnostic and a
;;;; deliberate exit rather than an escaping condition, and that the success
;;;; exit is reached by falling out of a handler rather than by an
;;;; unconditional (uiop:quit 0) that would have printed the same zero however
;;;; little had run. A zero here still means "TEST-OP signalled nothing"; it is
;;;; not a claim about how many specs were selected. For that, read the
;;;; "N passed, ... N total" summary line, which is the only surface that
;;;; distinguishes a green suite from an empty one.

(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(defun configure-local-source-registry (root)
  (asdf:initialize-source-registry
   `(:source-registry
     (:tree ,root)
     :inherit-configuration)))

(defun quit-with (code)
  "Flush both standard streams, then exit the process with CODE through
HOST-KIT:QUIT. Signals when HOST-KIT is absent, which means the test system's
dependency closure never loaded -- a different failure from a failing suite,
and one worth saying out loud rather than hiding behind a plain exit."
  (finish-output *standard-output*)
  (finish-output *error-output*)
  (let* ((package (or (find-package "HOST-KIT")
                      (error "HOST-KIT is unavailable: cl-host-kit did not load.")))
         (quit (or (find-symbol "QUIT" package)
                   (error "HOST-KIT does not provide QUIT."))))
    (funcall quit code)))

(let ((root (script-directory)))
  (configure-local-source-registry root)
  (handler-case (asdf:test-system "cl-cowsay")
    (error (condition)
      (format *error-output* "~&cl-cowsay tests failed: ~A~%" condition)
      (quit-with 1)))
  (quit-with 0))
