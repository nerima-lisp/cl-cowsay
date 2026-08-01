;;;; src/template.lisp
;;;;
;;;; A deliberately tiny string-substitution scheme -- three fixed
;;;; placeholders, no nesting, no control flow -- rather than a general
;;;; templating engine. Every built-in character (src/characters.lisp) is a
;;;; list of plain strings that may contain ${eyes}, ${tongue}, and/or
;;;; ${thoughts}; FILL-TEMPLATE-LINE replaces each with caller-supplied text.

(in-package #:cl-cowsay)

(defparameter *template-placeholders* '("${thoughts}" "${eyes}" "${tongue}")
  "Every substitution point FILL-TEMPLATE-LINE recognizes, most specific
first. Order does not matter for correctness here (the three placeholders
cannot appear inside one another), but keeping it fixed makes the expansion
order deterministic to read.")

(defun %replace-all (string old new)
  "Return STRING with every non-overlapping occurrence of OLD replaced by NEW.
OLD must be non-empty; an empty OLD would match at every position and never
advance, looping forever, so this returns STRING unchanged instead."
  (if (zerop (length old))
      string
      (with-output-to-string (out)
        (loop with start = 0
              for position = (search old string :start2 start)
              while position
              do (write-string string out :start start :end position)
                 (write-string new out)
                 (setf start (+ position (length old)))
              finally (write-string string out :start start)))))

(defun fill-template-line (line &key (eyes "") (tongue "") (thoughts ""))
  "Return LINE with ${eyes}, ${tongue}, and ${thoughts} replaced by EYES,
TONGUE, and THOUGHTS respectively. A placeholder LINE does not contain is
simply absent from the result; this never signals on a missing placeholder."
  (%replace-all
   (%replace-all
    (%replace-all line "${thoughts}" thoughts)
    "${eyes}" eyes)
   "${tongue}" tongue))
