;;;; src/bubble.lisp
;;;;
;;;; Runtime bubble rendering operations. Preallocated character runs are
;;;; defined separately in src/bubble-data.lisp.
;;;;
;;;; The absence of an IN-PACKAGE form here is deliberate: cl-cowsay.asd
;;;; binds *PACKAGE* to CL-COWSAY around every compile through
;;;; :AROUND-COMPILE, so these definitions land in CL-COWSAY without one.
;;;; Note also that every source file that does carry an IN-PACKAGE form is
;;;; on the coverage gate's exclusion list in t/package.lisp, while every
;;;; file the gate measures -- this one included -- omits it.

(defun %write-repeated-bubble-character (character count stream)
  "Write CHARACTER (one of #\\Space, #\\_, or #\\-) COUNT times to STREAM, in
slices off the matching preallocated chunk above rather than building a
fresh string of length COUNT."
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
  "Write the multi-line bubble for LINES (already wrapped, one entry per
row) directly to STREAM. This is the canonical streaming bubble renderer
used by the library and its tests."
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
  "Return the single character used on both sides of every bubble content
line for MODE (:SPEECH or :THOUGHT). The two modes render visibly differently
so a reader can tell which was used without looking at the character art."
  (ecase mode
    (:speech #\|)
    (:thought #\:)))

(defun %bubble-thoughts-character (mode)
  "Return the connector character FILL-TEMPLATE-LINE substitutes for
${thoughts} in the character art below the bubble, for MODE."
  (ecase mode
    (:speech #\\)
    (:thought #\o)))
