
(in-package #:cl-cowsay/test)

(defun %run-cowsay (argv &key (stdin nil stdin-p))
  "Run *COWSAY-APP* and return its output and exit code."
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
    (let ((message (make-string 5000 :initial-element #\a)))
      (with-input-from-string (*standard-input* message)
        (expect (string= message (cl-cowsay/cli::%read-stdin-message)) :to-be-truthy))))

  (it "signals a bounded error instead of reading unbounded standard input"
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
    (multiple-value-bind (output code) (%run-cowsay '("cl-cowsay" "--list"))
      (with-soft-assertions
        (expect (zerop code) :to-be-truthy)
        (expect (every (lambda (name) (search name output)) (list-characters))
                :to-be-truthy))))

  (it "renders one of the built-in characters' art on --random"
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
  (it "main parses argv, renders, and quits with the handler's exit code"
    (let (captured-code)
      (with-mocked-functions (((symbol-function 'host-kit:quit)
                                (lambda (code) (setf captured-code code))))
        (let ((*standard-output* (make-broadcast-stream)))
          (main '("cl-cowsay" "hi"))))
      (expect captured-code :to-be 0)))

  (it "image-entry-point rebinds *default-pathname-defaults*, then runs main"
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
  (:documentation "Input stream that stalls during READ-SEQUENCE."))

(defmethod sb-gray:stream-read-sequence
    ((stream %stalling-input-stream) sequence &optional start end)
  (declare (ignore sequence end))
  (setf (%read-attempted stream) t)
  (sleep 5)
  (or start 0))

(defclass %stalling-output-stream (sb-gray:fundamental-character-output-stream)
  ((write-attempted :initform nil :accessor %write-attempted))
  (:documentation "Output stream that stalls during STREAM-WRITE-CHAR."))

(defmethod sb-gray:stream-write-char
    ((stream %stalling-output-stream) character)
  (setf (%write-attempted stream) t)
  (sleep 5)
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
    (let* ((condition (make-condition 'simple-error
                                      :format-control "a~C~Cb"
                                      :format-arguments (list #\Escape (code-char 127))))
           (raw (princ-to-string condition))
           (safe (cl-cowsay/cli::%terminal-safe-report condition)))
      (with-soft-assertions
        (expect (equal (map 'list #'char-code raw) (list 97 27 127 98)) :to-be-truthy)
        (expect (equal (map 'list #'char-code safe) (list 97 32 32 98)) :to-be-truthy))))

  (it "returns a report with no control characters unchanged"
    (let ((condition (make-condition 'simple-error
                                     :format-control "no control characters here")))
      (expect (string= (cl-cowsay/cli::%terminal-safe-report condition)
                       "no control characters here")
              :to-be-truthy))))

(describe "%report-cli-error"
  (it "folds a control character out of the bytes it writes to standard error"
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
