;;;; src/cli.lisp
;;;;
;;;; Runtime handlers for the single-shot `cl-cowsay` command. The application
;;;; declaration is in src/cli-definition.lisp; limits are in
;;;; src/cli-configuration.lisp.
;;;;
;;;; There is deliberately no IN-PACKAGE form in this file. CL-COWSAY/CLI's
;;;; :AROUND-COMPILE clause in cl-cowsay.asd binds *PACKAGE* around every file
;;;; it compiles, so one here would be redundant. The omission is also a
;;;; convention worth keeping: this file is measured by the 100% expression and
;;;; branch coverage gate in t/package.lisp, and every source file that does
;;;; carry an IN-PACKAGE form is on that gate's exclude list. The split falls
;;;; out of what SB-COVER can measure at all, not out of what a test can
;;;; reach: an excluded file's top-level forms run while the system loads,
;;;; before instrumentation is applied, so SB-COVER reports it at 0% however
;;;; thoroughly the definitions it installs are later exercised. Tests do
;;;; exercise them -- t/conditions-test.lisp drives the :REPORT lambdas from
;;;; src/conditions.lisp, and every render calls the DEFSTRUCT accessors from
;;;; src/characters-definitions.lisp -- and the percentage does not move.
;;;; Excluding those files is what makes a 100% gate over the remainder
;;;; meaningful instead of a demand for tests that assert nothing. Do not add
;;;; one here.

(defun %read-stdin-message ()
  "Read standard input up to *MAX-STDIN-MESSAGE-LENGTH*, and return it with
trailing newlines trimmed.

This establishes no wall-clock deadline of its own, deliberately. It used to
open a WITH-OPERATION-TIMEOUT of (:READ-STDIN TIMEOUT-SECONDS), and the
argument reaching it was the very same number %COWSAY-HANDLER had already
opened (:CLI TIMEOUT-SECONDS) with -- always, on every path, since the handler
is the only caller that supplies one. An inner deadline equal to an outer one
and started strictly later cannot fire first on its own merits, so it bounded
nothing the outer one did not already bound. What it did do was mislabel the
outer one. WITH-OPERATION-TIMEOUT (src/macros.lisp) wraps SB-EXT:WITH-TIMEOUT
in a HANDLER-CASE on SB-EXT:TIMEOUT, and HANDLER-CASE selects on the
condition's type, not on which timer signalled it: when the handler's deadline
expired with control parked in this function, the inner HANDLER-CASE caught
that expiry and reported `Operation :READ-STDIN exceeded its timeout'. Since
%REPORT-CLI-ERROR now prints an OPERATION-TIMEOUT report straight to standard
error, that wrong label became user-visible where it had been buried behind
cl-cli's `Internal error:' prefix.

So this function establishes no deadline. That is the whole of the claim, and
it is narrower than it may look: the CLI path still has TWO deadlines, not
one. %COWSAY-HANDLER's (:CLI TIMEOUT-SECONDS) passes the same number to
WRITE-SAY as :TIMEOUT-SECONDS, which opens (:WRITE-SAY TIMEOUT-SECONDS)
around its own body (src/render.lisp). Deleting that one was never an option
-- WRITE-SAY's :TIMEOUT-SECONDS is public library API
(docs/src/reference/api.md) and bounds embedded callers who have no outer
deadline at all -- so the mislabelling it produced is fixed where it belongs,
in WITH-OPERATION-TIMEOUT itself, whose docstring states the nesting contract
that now makes the outermost expired deadline the one the report names.
Removing the deadline here was still worth doing: it bounded nothing the
handler's deadline did not already bound.

The bound this function does enforce is on size rather than time, and it is
not redundant with anything: *MAX-STDIN-MESSAGE-LENGTH* is what keeps
`cat /dev/zero | cl-cowsay' from consuming memory without limit."
  (let* ((chunk-size 4096)
         (chunk (make-string chunk-size))
         (buffer (make-array chunk-size
                             :element-type 'character
                             :adjustable t
                             :fill-pointer 0)))
    (loop for count = (read-sequence chunk *standard-input*)
          while (plusp count)
          do (let ((end (+ (fill-pointer buffer) count)))
               (when (> end *max-stdin-message-length*)
                 (error 'stdin-too-large :limit *max-stdin-message-length*))
               (adjust-array buffer end :fill-pointer end)
               (replace buffer chunk :start1 (- end count) :end2 count)))
    (string-right-trim (list #\Newline #\Return) buffer)))

(defun %message-from-invocation (invocation)
  "Return the positional words joined by spaces, or, when there are none, the
message read from standard input.

Takes no timeout argument: it had one only to thread down to
%READ-STDIN-MESSAGE, which no longer establishes a deadline. Keeping the
parameter would have left a signature promising a bound this function does not
apply, and SBCL reports the unused variable as a STYLE-WARNING besides."
  (let ((words (positional-value invocation :message)))
    (if words (format nil "~{~A~^ ~}" words)
      (%read-stdin-message))))

(defun %pick-random-character ()
  "Return a character name chosen uniformly at random from LIST-CHARACTERS.
A tiny wrapper around CL:RANDOM purely so tests can assert on its result
(true randomness itself is not something a spec can pin down)."
  (let ((names (list-characters)))
    (nth (random (length names)) names)))

(defun %resolve-eyes (invocation)
  "Return the explicit --eyes value or the selected eyes preset for WRITE-SAY."
  (or
   (option-value invocation :eyes)
   (let ((preset (option-value invocation :eyes-preset)))
     (and preset (eyes-preset-string preset)))))

(defun %cowsay-app ()
  "Return the live application spec defined by DEFINE-APP."
  (symbol-value '*cowsay-app*))

(defun %list-characters-handler (invocation)
  "Print every built-in character name, one per line, and return exit code
0. Does not touch the message or standard input at all, so `cl-cowsay
--list` never blocks waiting on a pipe that was never going to feed it."
  (dolist (name (list-characters))
    (write-line name (invocation-stdout invocation)))
  0)

(defun %terminal-safe-report (condition)
  "Return CONDITION's own report text with every C0 control character and DEL
folded to a space, so nothing a report interpolates can move the cursor,
repaint a line, or open an escape sequence on the user's terminal. Folding
rather than deleting keeps the report the same length as the text that was
signalled, so a caller diffing or column-aligning stderr sees no shift.

CL-CLI sanitizes its own diagnostics for the same hazard (%RUNTIME-
DIAGNOSTIC-TEXT, over the private %TERMINAL-SAFE-TEXT), but it is a
DIFFERENT rule, not this one restated, and the differences run both ways.
CL-CLI folds only Newline, Return and Tab to a space and DROPS every other
control character outright, so its output can be shorter than its input; and
its range is wider, covering C1 (128-159) as well as C0 and DEL. This one
folds uniformly and stops at DEL. Neither helper is exported by the other's
package, so there is no shared implementation to converge on -- if the C1
range is ever wanted here it has to be added here.

The hazard is latent, not live, at the two call sites %REPORT-CLI-ERROR has
today. STDIN-TOO-LARGE interpolates ~D of an internal integer and
OPERATION-TIMEOUT interpolates ~S of one of three keywords written in this
source, so no byte of stdin or argv can reach stderr along either path. It
becomes live as soon as a HANDLER-CASE clause is added for a condition that
interpolates user text: UNKNOWN-CHARACTER (src/conditions.lisp) prints its
NAME slot with ~S, and PRIN1 escapes only the double quote and the backslash,
letting ESC through untouched."
  (map 'string
       (lambda (character)
         (let ((code (char-code character)))
           (if (or (< code 32) (= code 127)) #\Space character)))
       (princ-to-string condition)))

(defun %report-cli-error (condition invocation exit-code)
  "Print CONDITION's own report, folded through %TERMINAL-SAFE-REPORT, to
INVOCATION's standard error with no `Internal error:' prefix, and return
EXIT-CODE.

This exists to keep the failures a user caused and can act on out of the
software-fault bucket. CL-CLI's RUN-APP catches every error that escapes a
handler, labels it `Internal error:' and exits 70 (EX_SOFTWARE), which is the
honest description of a bug in this program and a misleading one for input
that was merely too long or a --timeout that merely expired. RUN-APP takes an
integer returned by a handler as the process exit code directly, so returning
EXIT-CODE here is the whole of the wiring.

INVOCATION-STDERR is read unguarded because CL-CLI declares that slot with no
default -- it is NIL on an invocation built by bare PARSE-ARGV, but RUN-APP
assigns it and every in-tree path arrives here through RUN-APP, so an (OR
... *ERROR-OUTPUT*) fallback would add a branch no test could take and this
file's 100% branch gate would reject it.

Every parameter is required and positional because none of them has a
defensible default, not because of coverage. SB-COVER's known hazard here is
narrower and concerns &KEY specifically: it marks a keyword default init form
as unexecuted even on runs that omit the keyword and take that default, as a
minimal COMPILE-FILE/LOAD reproduction confirmed. &OPTIONAL init forms are
not affected -- MAIN below carries one, (ARGV (CURRENT-PROCESS-ARGV)), and
this file still meets its gate. (%READ-STDIN-MESSAGE and %MESSAGE-FROM-
INVOCATION each carried one too until the redundant :READ-STDIN deadline came
out; both lost their whole parameter with it, so MAIN is the surviving
example.)"
  (format (invocation-stderr invocation) "~&~A~%" (%terminal-safe-report condition))
  exit-code)

(defun %cowsay-handler (invocation)
  (handler-case
      (let ((timeout-seconds (option-value invocation :timeout)))
        (with-operation-timeout (:cli timeout-seconds)
          (cond
            ((option-value invocation :completion) (%completion-handler invocation))
            ((option-value invocation :list) (%list-characters-handler invocation))
            (t
             (let ((message (%message-from-invocation invocation))
                   (character
                    (if (option-value invocation :random) (%pick-random-character)
                      (option-value invocation :character)))
                   (mode
                    (if (option-value invocation :think) :thought
                      :speech))
                   (eyes (%resolve-eyes invocation))
                   (tongue (option-value invocation :tongue))
                   (width (option-value invocation :width))
                   (no-wrap (option-value invocation :no-wrap)))
               (write-say
                message
                (invocation-stdout invocation)
                :character
                character
                :mode
                mode
                :eyes
                eyes
                :tongue
                tongue
                :width
                width
                :no-wrap
                no-wrap
                :timeout-seconds
                timeout-seconds)
               (terpri (invocation-stdout invocation))
               0)))))
    ;; Both clauses sit OUTSIDE WITH-OPERATION-TIMEOUT rather than inside it.
    ;; That macro signals OPERATION-TIMEOUT from its own HANDLER-CASE on
    ;; SB-EXT:TIMEOUT (src/macros.lisp), i.e. after the body has already
    ;; unwound, so a handler established within the body could never see it.
    ;; Nothing broader is caught here: an error this file did not anticipate
    ;; should still reach RUN-APP's `Internal error:'/70 path, which is the
    ;; accurate label for it.
    (stdin-too-large (condition)
      (%report-cli-error condition invocation +exit-data-error+))
    (operation-timeout (condition)
      (%report-cli-error condition invocation +exit-temporary-failure+))))

(defun %completion-handler (invocation)
  "Print a shell completion script for *COWSAY-APP*, for the shell named by
--completion, and return exit code 0. Does not touch the message or standard
input at all, so `cl-cowsay --completion bash` never blocks waiting on a pipe
that was never going to feed it. Defined after *COWSAY-APP* itself, which it
renders -- CL-CLI's RENDER-COMPLETION walks the live app spec (its options,
their :choices, and this docstring's own :description text) rather than a
second, hand-written copy of it."
  (render-completion
   (%cowsay-app)
   (option-value invocation :completion)
   (invocation-stdout invocation))
  0)

(defun main (&optional (argv (current-process-argv)))
  "Parse ARGV against *COWSAY-APP* and exit the process with the resulting
code. The default ARGV is the live process argv, so this is safe to call
directly from a toplevel form."
  (quit (run-app (%cowsay-app) :argv argv)))

(defun image-entry-point ()
  "Toplevel of the delivered cl-cowsay executable, named by :ENTRY-POINT in
cl-cowsay.asd. A dumped image comes back with the state it was dumped with,
which for a packaged build is a build sandbox that no longer exists; this puts
the process back in touch with the machine it is actually running on before
the CLI sees an argument.

*DEFAULT-PATHNAME-DEFAULTS* is the loud case: it still names the sandbox
directory, so it is re-read from the live process. *RANDOM-STATE* is the same
class of problem with a quiet symptom. SAVE-LISP-AND-DIE preserves the random
state the image was dumped with, and a fresh SBCL starts from a fixed initial
state in any case, so the sequence is identical in every process. This command
draws from it exactly once per run, which turns a repeated sequence into a
plain constant: without the reseed below, `cl-cowsay --random' returns the
same character forever. (MAKE-RANDOM-STATE T) seeds from the running machine
instead.

The reseed belongs here, at the process boundary, and deliberately not in MAIN
or %PICK-RANDOM-CHARACTER. Keeping those two free of entropy is what lets a
test bind *RANDOM-STATE* around them and assert on the draw, and what lets a
caller who embeds MAIN stay reproducible.

GETCWD and QUIT are provided by HOST-KIT, not UIOP -- this executable is
SBCL-only already (see :BUILD-OPERATION in cl-cowsay.asd), so UIOP
cross-implementation portability buys nothing here. No
UIOP:SETUP-TEMPORARY-DIRECTORY call either: CL-COWSAY uses
CL-TTY-KIT:CHAR-WIDTH and CL-TTY-KIT:STRING-WIDTH for pure string
measurements. It does not open a pty, enter raw terminal mode, or create a
temporary file, so a stale UIOP temporary-directory path cannot affect
rendering."
  (setf *default-pathname-defaults* (getcwd))
  (setf *random-state* (make-random-state t))
  (main))
