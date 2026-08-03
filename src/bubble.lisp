;;;; src/bubble.lisp
;;;;
;;;; Draws a plain ASCII box around already-wrapped message lines. Deliberately
;;;; a simple uniform rectangle -- top/bottom rules of "_"/"-" and a pair of
;;;; side characters that differ between speech and thought mode -- rather
;;;; than a tapered speech-bubble shape: a taper needs per-line corner
;;;; characters keyed off each line's position within the bubble, which would
;;;; roughly double this file's logic for a cosmetic difference a terminal
;;;; user is unlikely to notice.

(in-package #:cl-cowsay)

(defparameter +bubble-space-chunk+ (make-string 256 :initial-element #\Space)
  "A preallocated run of spaces %WRITE-REPEATED-BUBBLE-CHARACTER slices from,
so writing N padding spaces need not MAKE-STRING a fresh one per call.")
(defparameter +bubble-underscore-chunk+ (make-string 256 :initial-element #\_)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's top-rule \"_\" run.")
(defparameter +bubble-dash-chunk+ (make-string 256 :initial-element #\-)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's bottom-rule \"-\" run.")

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

(defun %write-single-line-bubble (line width mode stream)
  "Write the bubble for one already-ASCII LINE whose display width is
already known to be WIDTH."
  (let ((side (%bubble-side-character mode)))
    (%write-bubble-rule-character #\_ width stream)
    (terpri stream)
    (%write-bubble-line line width width side "" stream)
    (terpri stream)
    (%write-bubble-rule-character #\- width stream)))

(defun %write-bubble (lines mode stream)
  "Write the multi-line bubble for LINES (already wrapped, one entry per
row) directly to STREAM -- the streaming counterpart to BUBBLE-LINES below,
for callers that only need the rendered text written out rather than
returned as a string."
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

(defun %max-line-width (lines)
  "Return the widest terminal-column width among LINES, or 0 for an empty
list -- MAKE-STRING below then produces a two-column-wide empty box rather
than signaling on a message that wrapped to nothing."
  (reduce #'max lines :key #'cl-tty-kit:string-width :initial-value 0))

(defun bubble-lines (lines mode)
  "Return a list of strings: LINES (already wrapped, one entry per row)
framed in a box whose side character depends on MODE (:SPEECH or :THOUGHT).
An empty LINES list still produces a two-row-tall box around one empty
content line, so the bubble is never fewer than three lines."
  (let* ((content (or lines (list "")))
         (width (%max-line-width content))
         (side (%bubble-side-character mode))
         (top (concatenate 'string " " (make-string (+ width 2) :initial-element #\_)))
         (bottom (concatenate 'string " " (make-string (+ width 2) :initial-element #\-))))
    (cons top
          (append
           (mapcar (lambda (line)
                     (format nil "~C ~A ~C" side (cl-tty-kit:pad-string line width) side))
                   content)
           (list bottom)))))
