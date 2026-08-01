;;;; cl-cowsay.asd

;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current. Saying it makes
;;; the file self-contained. Package definitions belong in src/package.lisp,
;;; not here.
(in-package #:asdf-user)

(defsystem "cl-cowsay"
  ;; All eight metadata fields are mandatory. :homepage, :bug-tracker and
  ;; :source-control are what let a consumer find the project from a
  ;; Quicklisp or ASDF listing alone.
  :description "A one-shot ASCII-art talking-animal message tool for SBCL."
  :long-description "Word-wraps a message into a speech or thought bubble drawn above one of a
small set of original, hand-written ASCII-art characters. Not a clone of the .cow/Perl file
format used by upstream cowsay -- characters are Lisp data with a minimal ${eyes}/${tongue}/
${thoughts} substitution scheme."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  ;; Single source of truth for the version. flake.nix reads this form, and
  ;; release.yml refuses to publish a tag that disagrees with it.
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cowsay"
  :bug-tracker "https://github.com/nerima-lisp/cl-cowsay/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cowsay.git")
  ;; How the `cl-cowsay` executable is delivered belongs here, not in a build
  ;; system: `(asdf:operate 'asdf:program-op "cl-cowsay")` and `nix build`
  ;; must produce the same binary. See cl-weave.asd for the pattern this
  ;; follows.
  :build-operation "program-op"
  :build-pathname "cl-cowsay"
  :entry-point "cl-cowsay/cli::image-entry-point"
  ;; cl-tty-kit supplies display-width-aware word wrapping (WRAP-STRING) and
  ;; padding; cl-cli supplies the argument parser and --help/--version
  ;; scaffolding. Both are dependency-free L1 utilities within this org.
  :depends-on ("cl-tty-kit" ; word-wrap and padding for the message bubble
               "cl-cli")    ; declarative CLI parsing, --help/--version
  :pathname "src"
  :serial t
  :components
  ;; src/ is flat and every defpackage lives in src/package.lisp.
  ((:file "package")
   (:file "conditions")
   (:file "template")
   (:file "characters")
   (:file "bubble")
   (:file "render")
   (:file "cli"))
  ;; Mandatory. Without it `asdf:test-system "cl-cowsay"` succeeds while
  ;; running zero tests.
  :in-order-to ((test-op (test-op "cl-cowsay/test"))))

;;; The test system is `cl-cowsay/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-cowsay-test` and NOT `cl-cowsay/tests`.
(defsystem "cl-cowsay/test"
  :description "Test system for cl-cowsay."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cowsay"
  :bug-tracker "https://github.com/nerima-lisp/cl-cowsay/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cowsay.git")
  ;; cl-weave is the org's test framework everywhere. Do not introduce
  ;; FiveAM, parachute, rove or prove.
  :depends-on ("cl-cowsay" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "template-test")
   (:file "characters-test")
   (:file "bubble-test")
   (:file "conditions-test")
   (:file "render-test")
   (:file "cli-test"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (unless (funcall (symbol-function (find-symbol "RUN-TESTS" "CL-COWSAY/TEST")))
               (error "cl-cowsay test suite failed"))))
