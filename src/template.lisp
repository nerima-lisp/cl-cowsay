(defun %replace-all (string old new)
  "Replace every non-overlapping occurrence of OLD in STRING with NEW."
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
TONGUE, and THOUGHTS respectively. Missing placeholders become empty strings."
  (let ((eyes (or eyes ""))
        (tongue (or tongue ""))
        (thoughts (or thoughts "")))
    (%replace-all
     (%replace-all
      (%replace-all line "${thoughts}" thoughts)
      "${eyes}" eyes)
     "${tongue}" tongue)))

(defun %compile-template-line (line)
  "Compile LINE into literal strings and placeholder keywords."
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
