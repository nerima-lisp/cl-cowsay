;;;; src/cli.lisp
;;;;
;;;; The `cl-cowsay` command line: a single root command (no subcommands, per
;;;; cl-cli's "root positional" pattern) that reads a message from its
;;;; positional arguments or, absent those, from standard input, renders it
;;;; with CL-COWSAY:SAY, and prints the result. One shot: no loop, no
;;;; raw-mode terminal takeover.

(in-package #:cl-cowsay/cli)

(defun %cowsay-version ()
  "The running CL-COWSAY system's :VERSION, the single source of truth also
read by flake.nix and enforced by release.yml against the git tag."
  (let ((system (asdf:find-system "cl-cowsay" nil)))
    (if system (asdf:component-version system) "0.0.0")))

(defparameter *max-stdin-message-length* (* 64 1024)
  "Upper bound, in characters, on how much %READ-STDIN-MESSAGE will read from
*STANDARD-INPUT* before signaling STDIN-TOO-LARGE. cl-cowsay is a cosmetic
terminal toy, not a document processor, so this is generous rather than
tight -- large enough that no legitimate piped message could hit it, small
enough that an unbounded or accidental huge input source (`cat /dev/zero |
cl-cowsay`) cannot grow memory without bound or hang before any rendering
happens.")

(defun %read-stdin-message ()
  "Read at most *MAX-STDIN-MESSAGE-LENGTH* characters of *STANDARD-INPUT*
into a string, with a trailing newline (the one a shell-supplied EOF
typically leaves) removed so it does not become an extra blank wrapped line.
Reads one character at a time rather than by line, because a source with no
newline at all (e.g. /dev/zero) would otherwise let a single READ-LINE call
grow without bound; signals STDIN-TOO-LARGE once the limit is reached
instead of continuing to read."
  (let ((buffer (make-array 0 :element-type 'character :adjustable t :fill-pointer 0)))
    (loop for char = (read-char *standard-input* nil nil)
          while char
          do (when (>= (fill-pointer buffer) *max-stdin-message-length*)
               (error 'stdin-too-large :limit *max-stdin-message-length*))
             (vector-push-extend char buffer))
    (string-right-trim '(#\Newline) buffer)))

(defun %message-from-invocation (invocation)
  "Return the message to render: the positional words joined by a single
space when any were given on the command line, otherwise everything on
standard input."
  (let ((words (positional-value invocation :message)))
    (if words
        (format nil "~{~A~^ ~}" words)
        (%read-stdin-message))))

(defun %pick-random-character ()
  "Return a character name chosen uniformly at random from LIST-CHARACTERS.
A tiny wrapper around CL:RANDOM purely so tests can assert on its result
(true randomness itself is not something a spec can pin down)."
  (let ((names (list-characters)))
    (nth (random (length names)) names)))

(defun %resolve-eyes (invocation)
  "Return the ${eyes} override to pass SAY: an explicit --eyes value when
given, else the string for --eyes-preset when given, else NIL (SAY's own
\"oo\" default). --eyes always wins over a preset when both are given."
  (or (option-value invocation :eyes)
      (let ((preset (option-value invocation :eyes-preset)))
        (and preset (eyes-preset-string preset)))))

(defun %list-characters-handler (invocation)
  "Print every built-in character name, one per line, and return exit code
0. Does not touch the message or standard input at all, so `cl-cowsay
--list` never blocks waiting on a pipe that was never going to feed it."
  (dolist (name (list-characters))
    (write-line name (invocation-stdout invocation)))
  0)

(defun %cowsay-handler (invocation)
  (if (option-value invocation :list)
      (%list-characters-handler invocation)
      (let ((message (%message-from-invocation invocation))
            (character (if (option-value invocation :random)
                           (%pick-random-character)
                           (option-value invocation :character)))
            (mode (if (option-value invocation :think) :thought :speech))
            (eyes (%resolve-eyes invocation))
            (tongue (option-value invocation :tongue))
            (width (option-value invocation :width))
            (no-wrap (option-value invocation :no-wrap)))
        (write-string (say message :character character :mode mode
                                   :eyes eyes :tongue tongue :width width
                                   :no-wrap no-wrap)
                      (invocation-stdout invocation))
        (terpri (invocation-stdout invocation))
        0)))

(define-app *cowsay-app*
    (:name "cl-cowsay"
     :version (%cowsay-version)
     :summary "Render an ASCII-art character saying or thinking a message."
     :description
     "Word-wraps MESSAGE -- given as positional words, or read from standard
input when none are given -- into a speech or thought bubble drawn above a
built-in ASCII-art character."
     :handler #'%cowsay-handler)
  (:option "character" :short #\c :kind :value
   :choices (list-characters)
   :default "cow"
   :description "Built-in character to draw.")
  (:option "think" :short #\T :kind :flag
   :description "Use a thought bubble instead of a speech bubble.")
  (:option "eyes" :short #\e :kind :value
   :description "Override the character's eyes (default \"oo\").")
  (:option "eyes-preset" :short #\E :kind :value
   :choices (list-eye-presets)
   :description "Preset eyes (borg, dead, greedy, paranoid, stoned, tired, wired, youthful); --eyes overrides this.")
  (:option "tongue" :short #\t :kind :value
   :description "Override the character's tongue (default empty).")
  (:option "width" :short #\w :kind :value :type :integer :min 1
   :default 40
   :description "Column width to wrap MESSAGE to.")
  (:option "no-wrap" :short #\n :kind :flag
   :description "Do not word-wrap MESSAGE; only its own embedded newlines break lines.")
  (:option "list" :short #\l :kind :flag
   :description "List every built-in character name and exit.")
  (:option "random" :short #\r :kind :flag
   :description "Pick a random built-in character, ignoring --character.")
  (:positional :message :rest-p t
   :description "Words of the message. Reads standard input when omitted."))

(defun main (&optional (argv (current-process-argv)))
  "Parse ARGV against *COWSAY-APP* and exit the process with the resulting
code. The default ARGV is the live process argv, so this is safe to call
directly from a toplevel form."
  (quit (run-app *cowsay-app* :argv argv)))

(defun image-entry-point ()
  "Toplevel of the delivered `cl-cowsay` executable, named by :ENTRY-POINT in
cl-cowsay.asd. A dumped image comes back with the state it was dumped with,
which for a packaged build is a build sandbox that no longer exists; this
puts the process back in touch with the machine it is actually running on
before the CLI sees an argument. GETCWD and QUIT are HOST-KIT's, not UIOP's --
this executable is SBCL-only already (see :BUILD-OPERATION in
cl-cowsay.asd), so UIOP's cross-implementation portability buys nothing here.
UIOP:SETUP-TEMPORARY-DIRECTORY has no HOST-KIT equivalent; it stays, since
cl-tty-kit's raw-mode/pty machinery may need it even though cl-cowsay itself
never opens a temporary file."
  (setf *default-pathname-defaults* (getcwd))
  (uiop:setup-temporary-directory)
  (main))
