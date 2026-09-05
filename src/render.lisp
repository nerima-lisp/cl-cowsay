(defun %split-on-newlines (message)
  "Split MESSAGE into lines at #\\Newline without wrapping."
  (labels ((%scan-cps (start k)
             (let ((newline (position #\Newline message :start start)))
               (if newline
                   (%scan-cps (1+ newline)
                              (lambda (rest-lines)
                                (funcall k (cons (subseq message start newline) rest-lines))))
                   (funcall k (list (subseq message start (length message))))))))
    (%scan-cps 0 #'identity)))

(defun %write-staged-template-line (line output eyes tongue thoughts)
  "Write LINE to OUTPUT after staged placeholder substitution."
  (write-string (fill-template-line line
                                      :eyes eyes
                                      :tongue tongue
                                      :thoughts thoughts)
                output))

(defun write-say (message stream
                  &rest options
                  &key character mode eyes tongue width no-wrap timeout-seconds)
  "Write MESSAGE's rendering directly to STREAM.
MESSAGE must be a string, MODE must be either :SPEECH or :THOUGHT, and
TIMEOUT-SECONDS must be a positive real number."
  (let* ((character (if (member :character options)
                        character
                        "cow"))
         (mode (if (member :mode options)
                    mode
                    :speech))
         (width (if (member :width options)
                     width
                     40))
         (timeout-seconds
           (if (member :timeout-seconds options)
               timeout-seconds
               +default-timeout-seconds+)))
    (with-operation-timeout (:write-say timeout-seconds)
      (check-type message string)
      (check-type mode (member :speech :thought))
      (check-type stream stream)
      (check-type character string)
      (check-type eyes (or null string))
      (check-type tongue (or null string))
      (unless (and (integerp width) (plusp width))
        (error 'invalid-message :width width))
      (let* ((template (find-character-template character))
             (eyes (or eyes "oo"))
             (tongue (or tongue ""))
             (thoughts (string (%bubble-thoughts-character mode)))
             (staged-substitution-p (or (search "${" eyes)
                                         (search "${" tongue)
                                         (search "${" thoughts))))
        (if no-wrap
            (%write-bubble (%split-on-newlines message) mode stream)
            (multiple-value-bind (bubble-width ascii-p) (%ascii-wrapped-maximum-width message width)
              (if ascii-p
                  (%write-ascii-wrapped-bubble message width bubble-width mode stream)
                  (multiple-value-bind (unicode-bubble-width character-widths)
                      (%wrapped-maximum-width message width)
                    (%write-wrapped-bubble message width unicode-bubble-width mode stream
                                           character-widths)))))
        (loop for line in (character-template-lines template)
              for chunks in (character-template-chunks template)
              do (terpri stream)
                 (if staged-substitution-p
                     (%write-staged-template-line line stream eyes tongue thoughts)
                     (%write-compiled-template-line chunks stream eyes tongue thoughts)))))))
