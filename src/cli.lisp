;;;; src/cli.lisp
;;;;
;;;; Runtime handlers for the single-shot `cl-cowsay` command. The application
;;;; declaration is in src/cli-definition.lisp; limits are in
;;;; src/cli-configuration.lisp.
(defun %read-stdin-message (&optional (timeout-seconds +default-timeout-seconds+))
  "Read bounded standard input under a wall-clock timeout."
  (with-operation-timeout (:read-stdin timeout-seconds)
    (let* ((chunk-size 4096)
           (chunk (make-string chunk-size))
           (buffer
            (make-array
             chunk-size
             :element-type
             (quote character)
             :adjustable
             t
             :fill-pointer
             0)))
      (loop for
            count = (read-sequence chunk *standard-input*)
            while (plusp count)
            do (let ((end (+ (fill-pointer buffer) count)))
                 (when (> end *max-stdin-message-length*)
                   (error (quote stdin-too-large) :limit *max-stdin-message-length*))
                 (adjust-array buffer end :fill-pointer end)
                 (replace buffer chunk :start1 (- end count) :end2 count)))
      (string-right-trim (list #\Newline #\Return) buffer))))

(defun %message-from-invocation (invocation &optional (timeout-seconds +default-timeout-seconds+))
  "Return positional words or read standard input under TIMEOUT-SECONDS."
  (let ((words (positional-value invocation :message)))
    (if words (format nil "~{~A~^ ~}" words)
      (%read-stdin-message timeout-seconds))))

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
(defun %cowsay-app () "Return the live application spec defined by DEFINE-APP." (symbol-value (quote *cowsay-app*)))

(defun %list-characters-handler (invocation)
  "Print every built-in character name, one per line, and return exit code
0. Does not touch the message or standard input at all, so `cl-cowsay
--list` never blocks waiting on a pipe that was never going to feed it."
  (dolist (name (list-characters))
    (write-line name (invocation-stdout invocation)))
  0)

(defun %cowsay-handler (invocation)
  (let ((timeout-seconds (option-value invocation :timeout)))
    (with-operation-timeout (:cli timeout-seconds)
      (cond
        ((option-value invocation :completion) (%completion-handler invocation))
        ((option-value invocation :list) (%list-characters-handler invocation))
        (t
         (let ((message (%message-from-invocation invocation timeout-seconds))
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
           0))))))

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
  "Toplevel of the delivered cl-cowsay executable, named by :ENTRY-POINT in cl-cowsay.asd. A dumped image comes back with the state it was dumped with, which for a packaged build is a build sandbox that no longer exists; this puts the process back in touch with the machine it is actually running on before the CLI sees an argument. GETCWD and QUIT are provided by HOST-KIT, not UIOP -- this executable is SBCL-only already (see :BUILD-OPERATION in cl-cowsay.asd), so UIOP cross-implementation portability buys nothing here. No UIOP:SETUP-TEMPORARY-DIRECTORY call either: CL-COWSAY uses CL-TTY-KIT:CHAR-WIDTH and CL-TTY-KIT:STRING-WIDTH for pure string measurements. It does not open a pty, enter raw terminal mode, or create a temporary file, so a stale UIOP temporary-directory path cannot affect rendering."
  (setf *default-pathname-defaults* (getcwd))
  (main))
