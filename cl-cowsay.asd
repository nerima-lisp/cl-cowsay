;;;; cl-cowsay.asd

;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current. Saying it makes
;;; the file self-contained. Package definitions belong in src/package.lisp,
;;; not here.
(in-package #:asdf-user)

(defsystem "cl-cowsay"
  :description "A one-shot ASCII-art talking-animal rendering library for SBCL."
  :long-description "Word-wraps a message into a speech or thought bubble drawn above one of a
small set of original, hand-written ASCII-art characters. Not a clone of the .cow/Perl file
format used by upstream cowsay -- characters are Lisp data with a minimal ${eyes}/${tongue}/
${thoughts} substitution scheme."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "1.0.0"
  :homepage "https://github.com/nerima-lisp/cl-cowsay"
  :bug-tracker "https://github.com/nerima-lisp/cl-cowsay/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cowsay.git")
  :depends-on ("cl-tty-kit")
  :pathname "src"
  :serial t
  :around-compile
  (lambda (thunk)
    (let ((*package* (or (find-package "CL-COWSAY") *package*)))
      (funcall thunk)))
  :components
  ((:file "package")
   (:file "macros")
   (:file "conditions")
   (:file "template")
   (:file "characters-definitions")
   (:file "characters")
   (:file "characters-data")
   (:file "eyes-data")
   (:file "eyes")
   (:file "bubble-data")
   (:file "bubble")
   (:file "wrap")
   (:file "render"))
  :in-order-to ((test-op (test-op "cl-cowsay/test"))))

;;; The test system is `cl-cowsay/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-cowsay-test` and NOT `cl-cowsay/tests`.
(defsystem "cl-cowsay/cli"
  :description "Command-line executable for the cl-cowsay rendering library."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "1.0.0"
  :homepage "https://github.com/nerima-lisp/cl-cowsay"
  :bug-tracker "https://github.com/nerima-lisp/cl-cowsay/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cowsay.git")
  :depends-on ("cl-cowsay" "cl-cli" "cl-host-kit")
  :pathname "src"
  :serial t
  :around-compile
  (lambda (thunk)
    (let ((*package* (or (find-package "CL-COWSAY/CLI") *package*)))
      (funcall thunk)))
  :components
  ((:file "cli-package")
   (:file "cli-configuration")
   (:file "cli")
   (:file "cli-definition"))
  :build-operation "program-op"
  :build-pathname "cl-cowsay"
  :entry-point "cl-cowsay/cli::image-entry-point")

(defsystem "cl-cowsay/test"
  :description "Test system for cl-cowsay."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "1.0.0"
  :homepage "https://github.com/nerima-lisp/cl-cowsay"
  :bug-tracker "https://github.com/nerima-lisp/cl-cowsay/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cowsay.git")
  :depends-on ("cl-cowsay/cli" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "macros-test")
   (:file "template-test")
   (:file "characters-test")
   (:file "characters-data-test")
   (:file "eyes-test")
   (:file "bubble-test")
   (:file "conditions-test")
   (:file "render-test")
   (:file "cli-test"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (unless (funcall (symbol-function (find-symbol "RUN-TESTS" "CL-COWSAY/TEST")))
               (error "cl-cowsay test suite failed"))))
