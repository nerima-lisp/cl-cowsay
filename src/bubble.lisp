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
