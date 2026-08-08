;;;; src/template.lisp
;;;;
;;;; A deliberately tiny string-substitution scheme -- three fixed
;;;; placeholders, no nesting, no control flow -- rather than a general
;;;; templating engine. Every built-in character (src/characters-data.lisp)
;;;; is a list of plain strings that may contain ${eyes}, ${tongue}, and/or
;;;; ${thoughts}; FILL-TEMPLATE-LINE replaces each with caller-supplied text.

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

(defun fill-template-line (line &key eyes tongue thoughts)
  "Return LINE with ${eyes}, ${tongue}, and ${thoughts} replaced by EYES,
TONGUE, and THOUGHTS respectively. A placeholder LINE does not contain is
simply absent from the result; this never signals on a missing placeholder."
  (let ((eyes (or eyes ""))
        (tongue (or tongue ""))
        (thoughts (or thoughts "")))
    (%replace-all
     (%replace-all
      (%replace-all line "${thoughts}" thoughts)
      "${eyes}" eyes)
     "${tongue}" tongue)))

(defun %compile-template-line (line)
  "Compile LINE into a list of literal strings and placeholder keywords
(:THOUGHTS, :EYES, :TONGUE), in order. %WRITE-COMPILED-TEMPLATE-LINE replays
this plan against a stream without rescanning LINE for ${...} tokens on
every WRITE-SAY call -- REGISTER-CHARACTER (src/characters.lisp) compiles each
built-in character's lines once, at registration time."
  (loop with chunks = nil
        with start = 0
        with index = 0
        with length = (length line)
        while (< index length)
        do (cond
             ((and (<= (+ index 11) length)
                   (string= line "${thoughts}" :start1 index :end1 (+ index 11)))
              (when (< start index) (push (subseq line start index) chunks))
              (push :thoughts chunks)
              (setf index (+ index 11) start index))
             ((and (<= (+ index 7) length)
                   (string= line "${eyes}" :start1 index :end1 (+ index 7)))
              (when (< start index) (push (subseq line start index) chunks))
              (push :eyes chunks)
              (setf index (+ index 7) start index))
             ((and (<= (+ index 9) length)
                   (string= line "${tongue}" :start1 index :end1 (+ index 9)))
              (when (< start index) (push (subseq line start index) chunks))
              (push :tongue chunks)
              (setf index (+ index 9) start index))
             (t (incf index)))
        finally (when (< start length) (push (subseq line start) chunks))
                (return (nreverse chunks))))

(defun %write-compiled-template-line (chunks output eyes tongue thoughts)
  "Write CHUNKS (as produced by %COMPILE-TEMPLATE-LINE) to OUTPUT, writing
EYES, TONGUE, or THOUGHTS in place of their respective placeholder keyword."
  (dolist (chunk chunks)
    (etypecase chunk
      (string (write-string chunk output))
      (keyword (write-string (ecase chunk
                                (:eyes eyes)
                                (:tongue tongue)
                                (:thoughts thoughts))
                              output)))))
