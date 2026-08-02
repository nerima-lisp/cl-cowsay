;;;; src/template.lisp
;;;;
;;;; A deliberately tiny string-substitution scheme -- three fixed
;;;; placeholders, no nesting, no control flow -- rather than a general
;;;; templating engine. Every built-in character (src/characters-data.lisp)
;;;; is a list of plain strings that may contain ${eyes}, ${tongue}, and/or
;;;; ${thoughts}; FILL-TEMPLATE-LINE replaces each with caller-supplied text.

(in-package #:cl-cowsay)

(defun %replace-all (string old new)
  "Return STRING with every non-overlapping occurrence of OLD replaced by NEW.
OLD must be non-empty; an empty OLD would match at every position and never
advance, looping forever, so this returns STRING unchanged instead.

Written in continuation-passing style: %SCAN-CPS walks STRING left to right,
and at each match builds a continuation for \"how to finish the result once
the tail after this match is known\" instead of writing into a shared
accumulator. The base case (no further match) hands the remaining tail to
that whole chain of closures, which then composes the final string outward
from the last match to the first."
  (if (zerop (length old))
      string
      (labels ((%scan-cps (start k)
                 (let ((position (search old string :start2 start)))
                   (if position
                       (%scan-cps (+ position (length old))
                                  (lambda (tail)
                                    (funcall k (concatenate 'string
                                                             (subseq string start position)
                                                             new
                                                             tail))))
                       (funcall k (subseq string start))))))
        (%scan-cps 0 #'identity))))

(defun fill-template-line (line &key (eyes "") (tongue "") (thoughts ""))
  "Return LINE with ${eyes}, ${tongue}, and ${thoughts} replaced by EYES,
TONGUE, and THOUGHTS respectively. A placeholder LINE does not contain is
simply absent from the result; this never signals on a missing placeholder."
  (%replace-all
   (%replace-all
    (%replace-all line "${thoughts}" thoughts)
    "${eyes}" eyes)
   "${tongue}" tongue))
