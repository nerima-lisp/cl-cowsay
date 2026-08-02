;;;; t/cli-test.lisp

(in-package #:cl-cowsay/test)

(defun %run-cowsay (argv &key stdin)
  "Run *COWSAY-APP* against ARGV (a list of strings starting with the
program name, as RUN-APP expects) and return (VALUES STDOUT-STRING
EXIT-CODE). STDIN, when given, feeds *STANDARD-INPUT* for the run; omitted,
the run sees whatever standard input this process already has (each ARGV
below carries positional words, so no test exercising the default relies on
this)."
  (let (code)
    (values (with-output-to-string (out)
              (setf code (flet ((run () (run-app *cowsay-app* :argv argv :stdout out)))
                           (if stdin
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
        (expect (= code 0) :to-be-truthy)
        (expect (search "hello world" output) :to-be-truthy)
        (expect (find #\| output) :to-be-truthy))))

  (it "reads the message from standard input when no positional words are given"
    (let ((output (%run-cowsay '("cl-cowsay") :stdin "piped in")))
      (expect (search "piped in" output) :to-be-truthy)))

  (it "signals a bounded error instead of reading unbounded standard input"
    ;; A single newline-free run longer than the internal cap: the scenario a
    ;; naive line-based reader would read forever (e.g. `cat /dev/zero |
    ;; cl-cowsay`), tested here with a bounded fake stream instead of an
    ;; actually-huge or infinite one. run-app (cl-cli) catches any signaled
    ;; ERROR from the handler and reports exit code 70 (EX_SOFTWARE).
    (let* ((huge (make-string (1+ cl-cowsay/cli::*max-stdin-message-length*)
                              :initial-element #\a))
           (stdout (make-string-output-stream))
           (stderr (make-string-output-stream))
           (code (with-input-from-string (*standard-input* huge)
                   (run-app *cowsay-app* :argv '("cl-cowsay")
                                              :stdout stdout :stderr stderr))))
      (with-soft-assertions
        (expect (= code 70) :to-be-truthy)
        (expect (zerop (length (get-output-stream-string stdout))) :to-be-truthy)
        (expect (search "exceeded" (get-output-stream-string stderr)) :to-be-truthy))))

  (it "draws a \":\"-sided bubble when --think is given"
    (let ((output (%run-cowsay '("cl-cowsay" "-T" "hi"))))
      (expect (find #\: output) :to-be-truthy)))

  (it "exits 0 on --help without invoking the message handler"
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--help"))
      (with-soft-assertions
        (expect (= code 0) :to-be-truthy)
        (expect (search "cl-cowsay" output) :to-be-truthy))))

  (it "exits 0 on --version and prints the app's version"
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--version"))
      (with-soft-assertions
        (expect (= code 0) :to-be-truthy)
        (expect (search "cl-cowsay" output) :to-be-truthy))))

  (it "prints every character name and exits 0 on --list, without touching a message"
    ;; No :stdin is given here on purpose: --list must return before
    ;; %MESSAGE-FROM-INVOCATION would ever try to read standard input.
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--list"))
      (with-soft-assertions
        (expect (= code 0) :to-be-truthy)
        (expect (every (lambda (name) (search name output)) (list-characters))
                :to-be-truthy))))

  (it "renders one of the built-in characters' art on --random"
    ;; Character art never spells out its own name (it's ASCII shapes, not
    ;; letters), so this can't SEARCH for a name in OUTPUT -- it instead
    ;; checks OUTPUT against every character's actual SAY output byte for
    ;; byte, which also exercises %PICK-RANDOM-CHARACTER as a black box.
    (let ((output (%run-cowsay '("cl-cowsay" "-r" "hi"))))
      (expect (some (lambda (name)
                      (string= output (format nil "~A~%" (say "hi" :character name))))
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
      (expect (= (count #\| output) 2) :to-be-truthy))))

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
    ;; (SETF *DEFAULT-PATHNAME-DEFAULTS* ...) after this case -- a mock
    ;; replaces a function's definition, not a special variable's value.
    (let ((*default-pathname-defaults* *default-pathname-defaults*)
          captured-code)
      (with-mocked-functions (((symbol-function 'host-kit:quit)
                                (lambda (code) (setf captured-code code)))
                               ((symbol-function 'current-process-argv)
                                (lambda () '("cl-cowsay" "hi"))))
        (let ((*standard-output* (make-broadcast-stream)))
          (image-entry-point)))
      (expect captured-code :to-be 0))))
