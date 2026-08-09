;;;; t/cli-test.lisp

(in-package #:cl-cowsay/test)

(defun %run-cowsay (argv &key (stdin nil stdin-p))
  "Run *COWSAY-APP* against ARGV (a list of strings starting with the
program name, as RUN-APP expects) and return (VALUES STDOUT-STRING
EXIT-CODE). When STDIN is supplied, even as the empty string, it feeds
*STANDARD-INPUT* for the run; when omitted, the caller standard input is used."
  (let (code)
    (values (with-output-to-string (out)
              (setf code (flet ((run () (run-app *cowsay-app* :argv argv :stdout out)))
                           (if stdin-p
                               (with-input-from-string (*standard-input* stdin) (run))
                               (run)))))
            code)))

(describe "the cl-cowsay app spec: flag parsing round-trips"
  (it "collects positional words under :message"
    (let ((invocation (parse-argv *cowsay-app* '("cl-cowsay" "hello" "world"))))
      (expect (equal (positional-value invocation :message) '("hello" "world"))
              :to-be-truthy)))

  (it "defaults :character to \"cow\" when --character is not given"
    (let ((invocation (parse-argv *cowsay-app* '("cl-cowsay" "hi"))))
      (expect (string= (option-value invocation :character) "cow") :to-be-truthy)))

  (it "parses --character/-c"
    (let ((invocation (parse-argv *cowsay-app* '("cl-cowsay" "-c" "cat" "hi"))))
      (expect (string= (option-value invocation :character) "cat") :to-be-truthy)))

  (it "defaults :width to 40 and parses --width/-w as an integer"
    (with-soft-assertions
      (expect (= (option-value (parse-argv *cowsay-app* '("cl-cowsay" "hi")) :width) 40)
              :to-be-truthy)
      (expect (= (option-value (parse-argv *cowsay-app* '("cl-cowsay" "-w" "10" "hi"))
                               :width)
                 10)
              :to-be-truthy)))
    (it "rejects invalid --width values"
    (with-soft-assertions
      (signals cli-invalid-option-value
          (parse-argv *cowsay-app*
                      (list "cl-cowsay" "--width" "0" "hi")))
      (signals cli-invalid-option-value
          (parse-argv *cowsay-app*
                      (list "cl-cowsay" "--width" "not-an-integer" "hi")))))

  (it "parses --think/-T as a flag, defaulting to false"
    (with-soft-assertions
      (expect (not (option-value (parse-argv *cowsay-app* '("cl-cowsay" "hi")) :think))
              :to-be-truthy)
      (expect (option-value (parse-argv *cowsay-app* '("cl-cowsay" "-T" "hi")) :think)
              :to-be-truthy)))

  (it "parses --eyes and --tongue overrides"
    (let ((invocation (parse-argv *cowsay-app*
                                  '("cl-cowsay" "--eyes" "^^" "--tongue" "U" "hi"))))
      (with-soft-assertions
        (expect (string= (option-value invocation :eyes) "^^") :to-be-truthy)
        (expect (string= (option-value invocation :tongue) "U") :to-be-truthy))))

  (it "parses --eyes-preset/-E"
    (let ((invocation (parse-argv *cowsay-app* '("cl-cowsay" "-E" "borg" "hi"))))
      (expect (string= (option-value invocation :eyes-preset) "borg") :to-be-truthy)))

  (it "rejects an unknown --eyes-preset value"
    (signals cli-invalid-option-value
        (parse-argv *cowsay-app* '("cl-cowsay" "-E" "not-a-preset" "hi"))))

  (it "parses --no-wrap/-n and --list/-l and --random/-r as flags, defaulting to false"
    (let ((invocation (parse-argv *cowsay-app* '("cl-cowsay" "hi"))))
      (with-soft-assertions
        (expect (not (option-value invocation :no-wrap)) :to-be-truthy)
        (expect (not (option-value invocation :list)) :to-be-truthy)
        (expect (not (option-value invocation :random)) :to-be-truthy))))

  (it "rejects an unknown --character value"
    (signals cli-invalid-option-value
        (parse-argv *cowsay-app* '("cl-cowsay" "-c" "not-a-character" "hi")))))

(describe "the cl-cowsay app spec: end-to-end run-app"
  (it "prints a rendered bubble for a positional message and exits 0"
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "hello" "world"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (search "hello world" output) :to-be-truthy)
        (expect (find #\| output) :to-be-truthy))))

  (it "normalizes a single trailing newline from stdin"
    (multiple-value-bind (with-newline with-code)
        (%run-cowsay (list "cl-cowsay") :stdin (format nil "boundary~%"))
      (multiple-value-bind (without-newline without-code)
          (%run-cowsay (list "cl-cowsay") :stdin "boundary")
        (with-soft-assertions
          (expect (zerop with-code) :to-be-truthy)
          (expect (zerop without-code) :to-be-truthy)
          (expect (string= with-newline without-newline) :to-be-truthy)))))

  (it "distinguishes omitted stdin from explicitly empty stdin"
    (with-input-from-string (*standard-input* "ambient")
      (multiple-value-bind (omitted-output omitted-code)
          (%run-cowsay (list "cl-cowsay"))
        (multiple-value-bind (empty-output empty-code)
            (%run-cowsay (list "cl-cowsay") :stdin "")
          (with-soft-assertions
            (expect (zerop omitted-code) :to-be-truthy)
            (expect (search "ambient" omitted-output) :to-be-truthy)
            (expect (zerop empty-code) :to-be-truthy)
            (expect (not (search "ambient" empty-output)) :to-be-truthy))))))

  (it "reads a piped message across the internal chunk boundary"
    ;; %READ-STDIN-MESSAGE reads in 4096-character chunks; 5000 characters
    ;; forces a second READ-SEQUENCE call to pick up where the first left off.
    (let ((message (make-string 5000 :initial-element #\a)))
      (with-input-from-string (*standard-input* message)
        (expect (string= message (cl-cowsay/cli::%read-stdin-message)) :to-be-truthy))))

  (it "signals a bounded error instead of reading unbounded standard input"
    ;; A single newline-free run longer than the internal cap: the scenario a
    ;; naive line-based reader would read forever (e.g. `cat /dev/zero |
    ;; cl-cowsay`), tested here with a bounded fake stream instead of an
    ;; actually-huge or infinite one.
    ;;
    ;; %COWSAY-HANDLER's own HANDLER-CASE intercepts STDIN-TOO-LARGE and
    ;; returns +EXIT-DATA-ERROR+ (65), so cl-cli's blanket "escaping error"
    ;; path -- `Internal error:' on standard error and exit 70 (EX_SOFTWARE) --
    ;; is no longer reached. Both halves of that are asserted: 65 rather than
    ;; 70, and the absence of the `Internal error' prefix. Without the second
    ;; assertion this case would still pass if someone reinstated the prefix
    ;; while keeping the code, and the prefix is exactly what makes an
    ;; over-long input look like a bug in this program rather than input a
    ;; user can shorten.
    (let* ((huge (make-string (1+ cl-cowsay/cli::*max-stdin-message-length*)
                              :initial-element #\a))
           (stdout (make-string-output-stream))
           (stderr (make-string-output-stream))
           (code (with-input-from-string (*standard-input* huge)
                   (run-app *cowsay-app* :argv '("cl-cowsay")
                                              :stdout stdout :stderr stderr)))
           (errors (get-output-stream-string stderr)))
      (with-soft-assertions
        (expect (= code 65) :to-be-truthy)
        (expect (= code cl-cowsay/cli::+exit-data-error+) :to-be-truthy)
        (expect (zerop (length (get-output-stream-string stdout))) :to-be-truthy)
        (expect (search "exceeded" errors) :to-be-truthy)
        (expect (not (search "Internal error" errors)) :to-be-truthy))))

  (it "draws a \":\"-sided bubble when --think is given"
    (let ((output (%run-cowsay '("cl-cowsay" "-T" "hi"))))
      (expect (find #\: output) :to-be-truthy)))

  (it "exits 0 on --help without invoking the message handler"
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--help"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (search "cl-cowsay" output) :to-be-truthy))))

  (it "exits 0 on --version and prints the app's version"
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--version"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (search "cl-cowsay" output) :to-be-truthy))))

  (it "prints every character name and exits 0 on --list, without touching a message"
    ;; No :stdin is given here on purpose: --list must return before
    ;; %MESSAGE-FROM-INVOCATION would ever try to read standard input.
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--list"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (every (lambda (name) (search name output)) (list-characters))
                :to-be-truthy))))

  (it "renders one of the built-in characters' art on --random"
    ;; Character art never spells out its own name (it's ASCII shapes, not
    ;; letters), so this can't SEARCH for a name in OUTPUT -- it instead
    ;; checks OUTPUT against every character's actual WRITE-SAY output byte for
    ;; byte, which also exercises %PICK-RANDOM-CHARACTER as a black box.
    (let ((output (%run-cowsay '("cl-cowsay" "-r" "hi"))))
      (expect (some (lambda (name)
                      (string= output (format nil "~A~%" (render-to-string "hi" :character name))))
                    (list-characters))
              :to-be-truthy)))

  (it "applies --eyes-preset, and lets an explicit --eyes override it"
    (with-soft-assertions
      (expect (search "==" (%run-cowsay '("cl-cowsay" "-E" "borg" "hi"))) :to-be-truthy)
      (expect (search "^^" (%run-cowsay '("cl-cowsay" "-E" "borg" "--eyes" "^^" "hi")))
              :to-be-truthy)))

  (it "does not wrap the message on --no-wrap even past the default width"
    (let* ((long (make-string 60 :initial-element #\a))
           (output (%run-cowsay (list "cl-cowsay" "--no-wrap" long))))
      (expect (= (count #\| output) 2) :to-be-truthy)))
  (it "forwards rendering options through run-app"
    (multiple-value-bind (output code)
        (%run-cowsay
         (list "cl-cowsay" "--character" "cat" "--eyes" "^^"
               "--tongue" "U" "--width" "10" "hello" "world"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (string= output
                         (format nil "~A~%"
                                 (render-to-string "hello world"
                                      :character "cat"
                                      :eyes "^^"
                                      :tongue "U"
                                      :width 10)))
                :to-be-truthy))))

  ;; No :stdin is given, for the same reason as --list above: --completion
  ;; must return before %MESSAGE-FROM-INVOCATION would ever try to read
  ;; standard input.
  (it-each (("bash") ("zsh") ("fish") ("powershell") ("nushell") ("elvish"))
      "prints a ~A completion script naming the app and exits 0"
      (shell)
    (multiple-value-bind (output code) (%run-cowsay (list "cl-cowsay" "--completion" shell))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (search "cl-cowsay" output) :to-be-truthy))))

  (it "rejects an unknown --completion shell name"
    (signals cli-invalid-option-value
        (parse-argv *cowsay-app* '("cl-cowsay" "--completion" "not-a-shell")))))

(describe "main and image-entry-point"
  ;; Both ultimately call HOST-KIT:QUIT, which would tear down this test
  ;; process if actually invoked -- WITH-MOCKED-FUNCTIONS replaces it with a
  ;; capture instead, restoring the real function on exit (including a
  ;; non-local one).
  (it "main parses argv, renders, and quits with the handler's exit code"
    (let (captured-code)
      (with-mocked-functions (((symbol-function 'host-kit:quit)
                                (lambda (code) (setf captured-code code))))
        (let ((*standard-output* (make-broadcast-stream)))
          (main '("cl-cowsay" "hi"))))
      (expect captured-code :to-be 0)))

  (it "image-entry-point rebinds *default-pathname-defaults*, then runs main"
    ;; The LET, not WITH-MOCKED-FUNCTIONS, is what undoes IMAGE-ENTRY-POINT's
    ;; two SETFs after this case -- a mock replaces a function's definition,
    ;; not a special variable's value. Both variables it assigns need an entry
    ;; here, and rebinding each to its own current value is enough: the SETF
    ;; then writes the fresh dynamic binding, which this LET discards on exit.
    ;;
    ;; *RANDOM-STATE* is the entry that is easy to miss and expensive to omit.
    ;; IMAGE-ENTRY-POINT sets it to (MAKE-RANDOM-STATE T), i.e. seeded from OS
    ;; entropy; without the rebinding that state would outlive this case and
    ;; become the test image's global one, making every later CL:RANDOM draw in
    ;; the run irreproducible -- including cl-weave's GEN-STRING, GEN-MEMBER
    ;; and GEN-LIST, which the property and fuzz specs draw from.
    ;;
    ;; *RANDOM-STATE* is bound to (MAKE-RANDOM-STATE NIL) -- a copy -- rather
    ;; than to its own current value. Binding a special to itself protects the
    ;; identity but shares the object, so an in-place CL:RANDOM mutation inside
    ;; the body would still be visible to the outer binding on exit. Binding to
    ;; a copy makes the containment hold whatever the body does, instead of only
    ;; because IMAGE-ENTRY-POINT's SETF happens to precede every draw.
    (let ((*default-pathname-defaults* *default-pathname-defaults*)
          (*random-state* (make-random-state nil))
          captured-code)
      (with-mocked-functions (((symbol-function 'host-kit:quit)
                                (lambda (code) (setf captured-code code)))
                               ((symbol-function 'current-process-argv)
                                (lambda () '("cl-cowsay" "hi"))))
        (let ((*standard-output* (make-broadcast-stream)))
          (image-entry-point)))
      (expect captured-code :to-be 0)))

  (it "image-entry-point reseeds *random-state* from machine entropy, not from a copy of the inherited state"
    ;; The defect this pins: SBCL's initial *RANDOM-STATE* is identical in
    ;; every fresh process, and SAVE-LISP-AND-DIE preserves whatever state the
    ;; image was dumped with, so a command that draws exactly once per run
    ;; returns a constant -- `cl-cowsay --random' produced the same character
    ;; on every invocation.
    ;;
    ;; The whole of the fix is the argument T in (MAKE-RANDOM-STATE T), so the
    ;; oracle has to discriminate on exactly that. EQ-identity does not:
    ;; (MAKE-RANDOM-STATE NIL) returns a *copy* of the current state, which is a
    ;; fresh object of type RANDOM-STATE, so it satisfies both (NOT (EQ ...))
    ;; and TYPEP while reinstating the defect verbatim -- every process would
    ;; inherit the same state, copy it, and draw the same character forever.
    ;;
    ;; EQUALP is the oracle instead, because it descends SBCL's RANDOM-STATE
    ;; structure and compares the seed vector itself. Verified in this
    ;; implementation: (EQUALP S (MAKE-RANDOM-STATE NIL)) is T for the copy and
    ;; (EQUALP S (MAKE-RANDOM-STATE T)) is NIL for an entropy seed. So this
    ;; assertion goes red on the T-to-NIL mutation and carries no probability of
    ;; its own -- unlike comparing drawn numbers, which is only "almost always"
    ;; different and would be a flake.
    ;;
    ;; The *DEFAULT-PATHNAME-DEFAULTS* and *RANDOM-STATE* bindings serve the
    ;; same containment purpose as in the case above, and STATE-BEFORE names the
    ;; very object IMAGE-ENTRY-POINT inherits -- the LET* order matters, since
    ;; it must read the fresh binding rather than the suite's global state.
    (let* ((*default-pathname-defaults* *default-pathname-defaults*)
           (*random-state* (make-random-state nil))
           (state-before *random-state*)
           captured-code)
      (with-mocked-functions (((symbol-function 'host-kit:quit)
                                (lambda (code) (setf captured-code code)))
                               ((symbol-function 'current-process-argv)
                                (lambda () '("cl-cowsay" "hi"))))
        (let ((*standard-output* (make-broadcast-stream)))
          (image-entry-point)))
      (with-soft-assertions
        (expect captured-code :to-be 0)
        (expect (typep *random-state* 'random-state) :to-be-truthy)
        (expect (not (eq state-before *random-state*)) :to-be-truthy)
        (expect (not (equalp state-before *random-state*)) :to-be-truthy)))))

(defclass %stalling-input-stream (sb-gray:fundamental-character-input-stream)
  ((read-attempted :initform nil :accessor %read-attempted))
  (:documentation
   "A standard-input stand-in whose READ-SEQUENCE never returns, so a run can
be observed with control parked inside %READ-STDIN-MESSAGE's body when a
deadline expires.

This is a Gray stream rather than a WITH-MOCKED-FUNCTIONS replacement because
the only stallable call in that body is CL:READ-SEQUENCE, and CL is a locked
package in SBCL -- assigning its SYMBOL-FUNCTION signals a package-lock
violation rather than installing a mock. The stall has to come from the object
READ-SEQUENCE is handed instead of from the function it names. READ-ATTEMPTED
does the job MOCK-CALLED does in the sibling spec below: it is what makes
\"the deadline expired during the read\" an observation rather than an
assumption, since a run that never touched the stream could expire elsewhere
and still produce the same exit code.

Only STREAM-READ-SEQUENCE is specialized, because that is the single generic
CL:READ-SEQUENCE dispatches to for this stream class; a STREAM-READ-CHAR
method would be unreachable code here.

WHAT THE SPEC USING THIS STREAM DOES NOT ESTABLISH, stated so the coverage it
provides is not read as broader than it is. The stall here happens inside a
Gray-stream method -- ordinary Lisp code running in this thread, which SBCL's
timer interrupt unwinds cleanly. Real standard input is an FD-STREAM blocked
in read(2), and interrupting a thread parked in a blocking syscall is a
materially different problem: it depends on the signal being delivered to the
right thread and on the read being restarted or failing with EINTR rather than
swallowing the interrupt. Nothing in this suite exercises that. What the spec
does establish is the labelling: that the deadline fires with control inside
%READ-STDIN-MESSAGE's body and that the report names :CLI rather than a
deadline further in. Whether `cl-cowsay < /dev/fd/N` on a pipe nobody writes
to actually honours --timeout is not tested here, and would need a real pipe
and a real subprocess to test."))

(defmethod sb-gray:stream-read-sequence
    ((stream %stalling-input-stream) sequence &optional start end)
  (declare (ignore sequence end))
  (setf (%read-attempted stream) t)
  (sleep 5)
  ;; Never reached -- the deadline unwinds the SLEEP above. Returning START
  ;; (the "updated nothing" answer READ-SEQUENCE expects) rather than a bare 0
  ;; keeps that unreachability from being load-bearing.
  (or start 0))

(defclass %stalling-output-stream (sb-gray:fundamental-character-output-stream)
  ((write-attempted :initform nil :accessor %write-attempted))
  (:documentation
   "A standard-output stand-in whose first character write never returns, so a
run can be observed with control parked inside WRITE-SAY's own body when the
CLI deadline expires.

This is the OUTPUT-side counterpart of %STALLING-INPUT-STREAM above, and it
exists to reach a place that stream cannot: the region bounded by BOTH
WITH-OPERATION-TIMEOUT forms on the CLI path -- %COWSAY-HANDLER's (:CLI ...)
and, nested inside it, WRITE-SAY's own (:WRITE-SAY ...) (src/render.lisp).
Stalling the render by mocking WRITE-SAY, as the two cases above do, replaces
the inner deadline rather than entering it, so a mocked run cannot see what
the nesting does. The render here is the real, unmocked one.

Only STREAM-WRITE-CHAR is specialized. SB-GRAY's default
STREAM-WRITE-STRING for this stream class loops over STREAM-WRITE-CHAR, so
the one method covers every write WRITE-SAY performs; a STREAM-WRITE-STRING
method of our own would be a second copy of the same stall. WRITE-ATTEMPTED
does the job MOCK-CALLED does in the sibling cases: it is what makes \"the
deadline expired inside the render\" an observation rather than an
assumption."))

(defmethod sb-gray:stream-write-char
    ((stream %stalling-output-stream) character)
  (setf (%write-attempted stream) t)
  (sleep 5)
  ;; Never reached -- the deadline unwinds the SLEEP above. Returning
  ;; CHARACTER (what STREAM-WRITE-CHAR is specified to return) rather than a
  ;; bare NIL keeps that unreachability from being load-bearing.
  character)

(describe "timeout option"
  (it "defaults and parses long and short timeout options"
    (with-soft-assertions
      (expect (= (option-value (parse-argv *cowsay-app* (list "cl-cowsay" "hi")) :timeout)
                 +default-timeout-seconds+)
              :to-be-truthy)
      (expect (= (option-value (parse-argv *cowsay-app*
                                           (list "cl-cowsay" "--timeout" "2.5" "hi"))
                               :timeout)
                 2.5)
              :to-be-truthy)
      (expect (= (option-value (parse-argv *cowsay-app*
                                           (list "cl-cowsay" "-o" "1.5" "hi"))
                               :timeout)
                 1.5)
              :to-be-truthy)))

  (it "rejects a non-positive timeout"
    (signals cli-invalid-option-value
        (parse-argv *cowsay-app* (list "cl-cowsay" "--timeout" "0" "hi"))))

  (it "applies the timeout through run-app"
    (multiple-value-bind (output code)
        (%run-cowsay (list "cl-cowsay" "--timeout" "1" "hi"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (search "hi" output) :to-be-truthy))))

  (it "reports an expired timeout and exits 75 instead of the blanket 70"
    ;; A mock, not a wall-clock race: WRITE-SAY is replaced by a lambda that
    ;; overruns the deadline by an order of magnitude, so the expiry is a
    ;; certainty rather than a contest between this test and the scheduler.
    ;; The message is given as a positional word on purpose -- with one, no
    ;; standard-input read happens, so this case exercises the expiry on the
    ;; shortest path to it. The ":CLI" assertion below pins the label:
    ;; OPERATION-TIMEOUT reports as "Operation ~S exceeded its timeout", and
    ;; every other assertion here is satisfied identically whatever operation
    ;; the report names.
    ;;
    ;; %COWSAY-HANDLER's (:CLI ...) is now the only deadline on the CLI path,
    ;; so this case can no longer be misattributed even in principle;
    ;; %READ-STDIN-MESSAGE used to open a second, redundant (:READ-STDIN ...)
    ;; one that caught and mislabelled the handler's expiry. The case that
    ;; guards that -- the one where the read is actually in progress when the
    ;; deadline lands, which is where the mislabelling was visible -- is the
    ;; next one below; this case never entered the read, so it passed on the
    ;; defective source too.
    ;;
    ;; The deadline is 0.5 s against a 5 s sleep rather than 0.1 s against 1 s.
    ;; The ratio -- and so the certainty of expiry -- is the same, but the
    ;; window between entering WITH-OPERATION-TIMEOUT and reaching the mocked
    ;; call gets 5x more slack. Under multi-session load on this machine a
    ;; 100 ms window is a plausible intermittent red: the timer fires before the
    ;; mock, MOCK-CALLED stays NIL, and the case fails for a scheduling reason
    ;; rather than a code one. 0.5 s still sits well inside the 10 s per-spec
    ;; timeout configured in t/package.lisp.
    ;;
    ;; MOCK-CALLED is what makes this an observation rather than an
    ;; assumption. If the replacement were never consulted -- an inlined or
    ;; block-compiled call, a stale FASL -- the deadline could still expire
    ;; somewhere else and hand back 75, and the case would pass while proving
    ;; nothing about the path it names. The flag fails first in that world.
    ;;
    ;; :STDERR is passed explicitly because %RUN-COWSAY only passes :STDOUT,
    ;; and the whole point here is that a report gets written to standard
    ;; error -- left to default it would land on the real *ERROR-OUTPUT* and
    ;; spatter the suite's own output.
    (let ((mock-called nil)
          (stdout (make-string-output-stream))
          (stderr (make-string-output-stream))
          code)
      (with-mocked-functions (((symbol-function 'write-say)
                                (lambda (&rest arguments)
                                  (declare (ignore arguments))
                                  (setf mock-called t)
                                  (sleep 5))))
        (setf code (run-app *cowsay-app*
                            :argv (list "cl-cowsay" "--timeout" "0.5" "hi")
                            :stdout stdout
                            :stderr stderr)))
      (let ((errors (get-output-stream-string stderr)))
        (with-soft-assertions
          (expect mock-called :to-be-truthy)
          (expect (= code 75) :to-be-truthy)
          (expect (= code cl-cowsay/cli::+exit-temporary-failure+) :to-be-truthy)
          (expect (search "exceeded its timeout" errors) :to-be-truthy)
          (expect (search ":CLI" errors) :to-be-truthy)
          (expect (not (search "Internal error" errors)) :to-be-truthy)))))

  (it "names the CLI deadline, not the stdin read, when the timeout expires mid-read"
    ;; The sibling case above takes its message from a positional word, so no
    ;; standard-input read happens and its ":CLI" assertion holds for a reason
    ;; that is incidental to this defect: there was only ever one deadline
    ;; live. This case is the one the defect was about. No positional message
    ;; is given, so %MESSAGE-FROM-INVOCATION goes to %READ-STDIN-MESSAGE, and
    ;; the stream it reads never returns -- so when the handler's own (:CLI
    ;; ...) deadline expires, control is parked inside %READ-STDIN-MESSAGE.
    ;;
    ;; What went wrong there: %READ-STDIN-MESSAGE used to open a second
    ;; WITH-OPERATION-TIMEOUT of its own, with the same number. That macro
    ;; wraps SB-EXT:WITH-TIMEOUT in a HANDLER-CASE on SB-EXT:TIMEOUT, and a
    ;; HANDLER-CASE catches the condition by type regardless of which timer
    ;; signalled it -- so the inner one converted the OUTER timer's expiry and
    ;; reported `Operation :READ-STDIN exceeded its timeout'. The inner
    ;; deadline could never fire first on its own merits (same value, started
    ;; strictly later), so all it ever did was mislabel the outer one. The
    ;; :READ-STDIN assertion below is the guard on that; without it the case
    ;; passes on both the defective and the fixed source, since every other
    ;; assertion here is satisfied identically either way.
    ;;
    ;; WRITE-SAY is mocked for the same MOCK-CALLED reason as above, read in
    ;; the negative: the render must NOT have been reached. If it were, the
    ;; expiry happened somewhere downstream of the read and this case would be
    ;; naming a path it did not take. The mock also keeps a non-expiring run
    ;; from spattering a rendered bubble across the suite's output.
    ;;
    ;; :STDERR is passed explicitly because %RUN-COWSAY only passes :STDOUT,
    ;; and the report under test is written to standard error.
    (let ((stdin (make-instance '%stalling-input-stream))
          (write-say-called nil)
          (stdout (make-string-output-stream))
          (stderr (make-string-output-stream))
          code)
      (with-mocked-functions (((symbol-function 'write-say)
                                (lambda (&rest arguments)
                                  (declare (ignore arguments))
                                  (setf write-say-called t))))
        (let ((*standard-input* stdin))
          (setf code (run-app *cowsay-app*
                              :argv (list "cl-cowsay" "--timeout" "0.5")
                              :stdout stdout
                              :stderr stderr))))
      (let ((errors (get-output-stream-string stderr)))
        (with-soft-assertions
          (expect (%read-attempted stdin) :to-be-truthy)
          (expect (not write-say-called) :to-be-truthy)
          (expect (= code cl-cowsay/cli::+exit-temporary-failure+) :to-be-truthy)
          (expect (search "exceeded its timeout" errors) :to-be-truthy)
          (expect (search ":CLI" errors) :to-be-truthy)
          (expect (not (search ":READ-STDIN" errors)) :to-be-truthy)
          (expect (not (search "Internal error" errors)) :to-be-truthy)))))

  (it "names the CLI deadline, not the render, when the timeout expires inside a real write-say"
    ;; The two cases above mock WRITE-SAY, so neither of them ever enters the
    ;; second deadline the CLI path actually establishes. %COWSAY-HANDLER
    ;; opens (:CLI TIMEOUT-SECONDS) and then hands the SAME number to WRITE-SAY
    ;; as :TIMEOUT-SECONDS, and WRITE-SAY opens (:WRITE-SAY TIMEOUT-SECONDS)
    ;; around its whole body (src/render.lisp). That is the identical structure
    ;; %READ-STDIN-MESSAGE's redundant (:READ-STDIN ...) had, one call deeper:
    ;; the inner HANDLER-CASE selects SB-EXT:TIMEOUT by type, so it caught the
    ;; OUTER timer's expiry and reported `Operation :WRITE-SAY exceeded its
    ;; timeout' for a deadline the user set with --timeout.
    ;;
    ;; Deleting the inner deadline was not available as a fix: WRITE-SAY's
    ;; :TIMEOUT-SECONDS is public library API (docs/src/reference/api.md) and
    ;; must keep bounding embedded callers who have no outer deadline at all.
    ;; WITH-OPERATION-TIMEOUT (src/macros.lisp) instead records its own
    ;; deadline before scheduling and, on catching SB-EXT:TIMEOUT, re-signals
    ;; unchanged unless that deadline has actually passed -- so the inner form
    ;; declines an expiry it does not own and the outer one claims it.
    ;;
    ;; The stall is on the OUTPUT stream, which is what keeps the render real:
    ;; a mock would replace the inner deadline instead of entering it. The
    ;; message is a positional word, so no standard-input read happens and the
    ;; only deadlines live are the two under test. WRITE-ATTEMPTED is the
    ;; observation that control was inside WRITE-SAY when the deadline landed;
    ;; without it a run that expired before reaching the render would produce
    ;; the same 75 and prove nothing about the nesting.
    ;;
    ;; 0.5 s against a 5 s stall, for the same reason the sibling cases use it:
    ;; the expiry is a certainty rather than a race, with enough slack that
    ;; multi-session load on this machine cannot turn a scheduling delay into
    ;; an intermittent red, and well inside t/package.lisp's 10 s per-spec cap.
    (let ((stdout (make-instance '%stalling-output-stream))
          (stderr (make-string-output-stream))
          code)
      (setf code (run-app *cowsay-app*
                          :argv (list "cl-cowsay" "--timeout" "0.5" "hi")
                          :stdout stdout
                          :stderr stderr))
      (let ((errors (get-output-stream-string stderr)))
        (with-soft-assertions
          (expect (%write-attempted stdout) :to-be-truthy)
          (expect (= code cl-cowsay/cli::+exit-temporary-failure+) :to-be-truthy)
          (expect (search "exceeded its timeout" errors) :to-be-truthy)
          (expect (search ":CLI" errors) :to-be-truthy)
          (expect (not (search ":WRITE-SAY" errors)) :to-be-truthy)
          (expect (not (search "Internal error" errors)) :to-be-truthy))))))

(describe "%terminal-safe-report"
  (it "folds C0 control characters and DEL to spaces and leaves the rest alone"
    ;; The assertions are on character codes, not on a literal "a  b": a source
    ;; literal carrying two consecutive spaces is easy for an editor or a
    ;; whitespace-trimming hook to mangle, after which the case would pass or
    ;; fail for a reason that has nothing to do with the helper. Asserting the
    ;; RAW codes as well as the SAFE ones is what makes the fixture itself
    ;; checked rather than assumed -- if PRINC-TO-STRING ever stopped producing
    ;; exactly (97 27 127 98) here, the second assertion would be measuring a
    ;; different input than the comment claims.
    ;;
    ;; The input covers both arms of the helper's (OR (< CODE 32) (= CODE 127))
    ;; predicate and both of its outcomes: ESC takes (< CODE 32) true, DEL takes
    ;; it false and then (= CODE 127) true, and `a' and `b' take both false.
    (let* ((condition (make-condition 'simple-error
                                      :format-control "a~C~Cb"
                                      :format-arguments (list #\Escape (code-char 127))))
           (raw (princ-to-string condition))
           (safe (cl-cowsay/cli::%terminal-safe-report condition)))
      (with-soft-assertions
        (expect (equal (map 'list #'char-code raw) (list 97 27 127 98)) :to-be-truthy)
        (expect (equal (map 'list #'char-code safe) (list 97 32 32 98)) :to-be-truthy))))

  (it "returns a report with no control characters unchanged"
    ;; The expected value is written out as an independent literal rather than
    ;; as (PRINC-TO-STRING CONDITION), which is the helper's own first step and
    ;; would make the comparison route through the code under test.
    (let ((condition (make-condition 'simple-error
                                     :format-control "no control characters here")))
      (expect (string= (cl-cowsay/cli::%terminal-safe-report condition)
                       "no control characters here")
              :to-be-truthy))))

(describe "%report-cli-error"
  (it "folds a control character out of the bytes it writes to standard error"
    ;; The two cases above call %TERMINAL-SAFE-REPORT directly, which leaves
    ;; its WIRING untested: deleting the %TERMINAL-SAFE-REPORT call from
    ;; %REPORT-CLI-ERROR and leaving the bare (FORMAT ... "~&~A~%" CONDITION)
    ;; kept the whole suite green. The two CLI-path cases could not catch it
    ;; either -- they assert on "exceeded" and ":CLI", and neither condition
    ;; reachable from %COWSAY-HANDLER's HANDLER-CASE (STDIN-TOO-LARGE reports
    ;; ~D of an internal integer, OPERATION-TIMEOUT ~S of a keyword written in
    ;; this source) can carry a control character in the first place. So this
    ;; case drives one through %REPORT-CLI-ERROR itself. It goes red on that
    ;; deletion; it was run against the deleted call to confirm that.
    ;;
    ;; A CL-CLI invocation from PARSE-ARGV is used rather than a hand-rolled
    ;; stand-in because INVOCATION-STDERR is a DEFSTRUCT accessor, not a
    ;; generic function -- nothing else can answer to it. PARSE-ARGV leaves
    ;; that slot NIL (RUN-APP is what assigns it, src/runtime.lisp), so the
    ;; SETF below is the smallest thing that puts a readable stream where
    ;; %REPORT-CLI-ERROR looks.
    ;;
    ;; The assertions are on character codes rather than on a literal "a b",
    ;; for the reason spelled out in the sibling block above: a source literal
    ;; whose meaning rests on which whitespace character sits between two
    ;; letters is one editor or trimming hook away from passing or failing for
    ;; a reason unrelated to the code. Asserting the RAW codes too is what
    ;; makes the fixture checked rather than assumed. The written text is
    ;; trimmed of newlines first because the "~&~A~%" framing is not what is
    ;; under test here.
    (let* ((condition (make-condition 'simple-error
                                      :format-control "a~Cb"
                                      :format-arguments (list #\Escape)))
           (raw (princ-to-string condition))
           (stderr (make-string-output-stream))
           (invocation (parse-argv *cowsay-app* (list "cl-cowsay" "hi")))
           code)
      (setf (cl-cli:invocation-stderr invocation) stderr)
      (setf code (cl-cowsay/cli::%report-cli-error condition invocation 75))
      (let ((written (string-trim (list #\Newline) (get-output-stream-string stderr))))
        (with-soft-assertions
          (expect (equal (map 'list #'char-code raw) (list 97 27 98)) :to-be-truthy)
          (expect (equal (map 'list #'char-code written) (list 97 32 98)) :to-be-truthy)
          (expect (not (find 27 written :key #'char-code)) :to-be-truthy)
          (expect (= code 75) :to-be-truthy))))))
