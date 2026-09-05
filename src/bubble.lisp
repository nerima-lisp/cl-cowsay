
(defun %write-repeated-bubble-character (character count stream)
  "Write CHARACTER (one of #\\Space, #\\_, or #\\-) COUNT times to STREAM."
  (let ((chunk (ecase character
                 (#\Space +bubble-space-chunk+)
                 (#\_ +bubble-underscore-chunk+)
                 (#\- +bubble-dash-chunk+))))
    (loop while (plusp count)
          for end = (min count (length chunk))
          do (write-string chunk stream :end end)
             (decf count end))))

(defun %write-bubble-rule-character (character width stream)
  "Write one bubble rule row to STREAM: a leading space, then CHARACTER
repeated WIDTH+2 times."
  (write-char #\Space stream)
  (%write-repeated-bubble-character character (+ width 2) stream))

(defun %write-bubble-line (line line-width width side padding stream)
  "Write one bubble content row to STREAM: SIDE, a space, LINE, enough of
PADDING to reach WIDTH, a space, and SIDE again. LINE-WIDTH is LINE's
already-known display width; PADDING is a run of spaces at least
(- WIDTH LINE-WIDTH) long."
  (write-char side stream)
  (write-char #\Space stream)
  (write-string line stream)
  (write-string padding stream :end (- width line-width))
  (write-char #\Space stream)
  (write-char side stream))

(defun %write-bubble (lines mode stream)
  "Write the multi-line bubble for already-wrapped LINES to STREAM."
  (let* ((content (or lines (list "")))
         (widths (mapcar #'cl-tty-kit:string-width content))
         (width (reduce #'max widths :initial-value 0))
         (side (%bubble-side-character mode))
         (padding (make-string width :initial-element #\Space)))
    (%write-bubble-rule-character #\_ width stream)
    (loop for line in content
          for line-width in widths
          do (terpri stream)
             (%write-bubble-line line line-width width side padding stream))
    (terpri stream)
    (%write-bubble-rule-character #\- width stream)))

(defun %bubble-side-character (mode)
  "Return MODE's bubble side character."
  (ecase mode
    (:speech #\|)
    (:thought #\:)))

(defun %bubble-thoughts-character (mode)
  "Return the connector character FILL-TEMPLATE-LINE substitutes for
${thoughts} in the character art below the bubble, for MODE."
  (ecase mode
    (:speech #\\)
    (:thought #\o)))
