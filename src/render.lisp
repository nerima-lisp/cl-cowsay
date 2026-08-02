;;;; src/render.lisp
;;;;
;;;; SAY ties the pieces together: wrap the message (cl-tty-kit:wrap-string),
;;;; frame it in a bubble (bubble-lines), fill in the selected character's
;;;; template (fill-template-line), and join everything into one string.

(in-package #:cl-cowsay)

(defun %split-on-newlines (message)
  "Split MESSAGE into a list of lines on #\\Newline, with no width-based
wrapping applied. Used by SAY when NO-WRAP is true, so embedded newlines
still break the bubble into multiple lines while nothing else does."
  (loop for start = 0 then (1+ newline)
        for newline = (position #\Newline message :start start)
        collect (subseq message start (or newline (length message)))
        while newline))

(defun say (message &key (character "cow") (mode :speech) eyes tongue (width 40) no-wrap)
  "Return a string rendering MESSAGE inside a speech bubble (MODE :SPEECH,
the default) or thought bubble (MODE :THOUGHT) above the built-in CHARACTER,
a case-insensitive string naming one of LIST-CHARACTERS (default \"cow\").

EYES and TONGUE override the character's ${eyes} and ${tongue} template
slots when non-NIL; NIL (the default for both) falls back to \"oo\" and \"\"
respectively. WIDTH bounds the message's wrap column count and must be a
positive integer; it defaults to 40, matching the classic cowsay default.
NO-WRAP, when true, disables width-based wrapping entirely -- MESSAGE is
split only on its own embedded newlines, and WIDTH is ignored for wrapping
purposes (though still validated).

Signals UNKNOWN-CHARACTER when CHARACTER names no built-in, and
INVALID-MESSAGE when WIDTH is not a positive integer."
  (check-type message string)
  (unless (and (integerp width) (plusp width))
    (error 'invalid-message :width width))
  (let* ((template (find-character-template character))
         (eyes (or eyes "oo"))
         (tongue (or tongue ""))
         (thoughts (string (%bubble-thoughts-character mode)))
         (wrapped (if no-wrap
                      (%split-on-newlines message)
                      (cl-tty-kit:wrap-string message width)))
         (bubble (bubble-lines wrapped mode))
         (creature (mapcar (lambda (line)
                              (fill-template-line line :eyes eyes :tongue tongue
                                                        :thoughts thoughts))
                            (character-template-lines template))))
    (format nil "~{~A~^~%~}" (append bubble creature))))
