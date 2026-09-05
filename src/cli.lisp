(defun %read-stdin-message ()
  "Read standard input up to the configured limit and trim trailing newlines."
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
  "Return positional words joined by spaces, or read the message from stdin."
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
  "Print built-in character names and return zero."
  (dolist (name (list-characters))
    (write-line name (invocation-stdout invocation)))
  0)

(defun %terminal-safe-report (condition)
  "Return the condition report with C0 controls and DEL replaced by spaces."
  (map 'string
       (lambda (character)
         (let ((code (char-code character)))
           (if (or (< code 32) (= code 127)) #\Space character)))
       (princ-to-string condition)))

(defun %report-cli-error (condition invocation exit-code)
  "Report CONDITION to the invocation standard error and return EXIT-CODE."
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
    (stdin-too-large (condition)
      (%report-cli-error condition invocation +exit-data-error+))
    (operation-timeout (condition)
      (%report-cli-error condition invocation +exit-temporary-failure+))))

(defun %completion-handler (invocation)
  "Render the requested shell completion script and return zero."
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
  "Entry point for the delivered executable."
  (setf *default-pathname-defaults* (getcwd))
  (setf *random-state* (make-random-state t))
  (main))
