;;;; src/render.lisp
;;;;
;;;; SAY wraps the message, then writes the bubble and filled character
;;;; template directly to its result stream via %WRITE-SAY -- SAY itself is
;;;; just %WRITE-SAY collected into a string with WITH-OUTPUT-TO-STRING.

(in-package #:cl-cowsay)

(defun %split-on-newlines (message)
  "Split MESSAGE into a list of lines on #\\Newline, with no width-based
wrapping applied. Used by SAY when NO-WRAP is true, so embedded newlines
still break the bubble into multiple lines while nothing else does.

Written in continuation-passing style, mirroring %REPLACE-ALL
(src/template.lisp): %SCAN-CPS walks MESSAGE left to right, and at each
newline builds a continuation for \"how to finish the list once the lines
after this one are known\" instead of collecting into a shared accumulator.
The base case (no further newline) hands the final segment to that whole
chain of closures, which then conses the result together outward from the
last line to the first."
  (labels ((%scan-cps (start k)
             (let ((newline (position #\Newline message :start start)))
               (if newline
                   (%scan-cps (1+ newline)
                              (lambda (rest-lines)
                                (funcall k (cons (subseq message start newline) rest-lines))))
                   (funcall k (list (subseq message start (length message))))))))
    (%scan-cps 0 #'identity)))

(defun %write-template-line (line output eyes tongue thoughts staged-substitution-p)
  "Write LINE to OUTPUT with ${eyes}/${tongue}/${thoughts} substituted.
STAGED-SUBSTITUTION-P selects between two equivalent strategies: true calls
FILL-TEMPLATE-LINE (a correctness-preserving multi-pass replace, needed when
EYES, TONGUE, or THOUGHTS might itself contain another placeholder's
literal text); false rescans LINE once, writing each literal run and
substituted value straight to OUTPUT without building an intermediate
string."
  (if staged-substitution-p
      (write-string (fill-template-line line :eyes eyes :tongue tongue :thoughts thoughts) output)
      (loop with length = (length line)
            with start = 0
            with index = 0
            while (< index length)
            do (cond
                 ((and (<= (+ index 11) length)
                       (string= line "${thoughts}" :start1 index :end1 (+ index 11)))
                  (write-string line output :start start :end index)
                  (write-string thoughts output)
                  (setf index (+ index 11) start index))
                 ((and (<= (+ index 7) length)
                       (string= line "${eyes}" :start1 index :end1 (+ index 7)))
                  (write-string line output :start start :end index)
                  (write-string eyes output)
                  (setf index (+ index 7) start index))
                 ((and (<= (+ index 9) length)
                       (string= line "${tongue}" :start1 index :end1 (+ index 9)))
                  (write-string line output :start start :end index)
                  (write-string tongue output)
                  (setf index (+ index 9) start index))
                 (t (incf index)))
            finally (write-string line output :start start))))

(defun %ascii-wrapped-maximum-width (message width)
  "Return (VALUES MAXIMUM-WIDTH T) when MESSAGE is plain ASCII with no
embedded newline: MAXIMUM-WIDTH is the widest line CL-TTY-KIT:WRAP-STRING
would produce for MESSAGE at WIDTH, computed without allocating the wrapped
lines themselves -- ASCII display width always equals character count, so
this needs none of CL-TTY-KIT's Unicode-aware accounting. Returns
(VALUES NIL NIL) for any non-ASCII character or embedded newline, so the
caller can fall back to the Unicode-aware path."
  (let ((maximum-width 0)
        (current-width 0)
        (length (length message)))
    (labels ((finish-line ()
               (setf maximum-width (max maximum-width current-width)
                     current-width 0))
             (add-chunk (chunk-width)
               (cond
                 ((zerop current-width) (setf current-width chunk-width))
                 ((<= (+ current-width 1 chunk-width) width)
                  (incf current-width (1+ chunk-width)))
                 (t (finish-line) (setf current-width chunk-width)))))
      (loop with cursor = 0
            while (< cursor length)
            do (let ((character (char message cursor)))
                 (unless (<= (char-code character) 127)
                   (return-from %ascii-wrapped-maximum-width (values nil nil)))
                 (cond
                   ((char= character #\Newline)
                    (return-from %ascii-wrapped-maximum-width (values nil nil)))
                   ((char= character #\Space) (incf cursor))
                   (t (let ((word-start cursor))
                        (loop while (and (< cursor length)
                                         (not (member (char message cursor) '(#\Space #\Newline))))
                              do (incf cursor))
                        (loop with chunk-start = word-start
                              while (< chunk-start cursor)
                              for chunk-end = (min cursor (+ chunk-start width))
                              do (add-chunk (- chunk-end chunk-start))
                                 (setf chunk-start chunk-end)))))))
      (values (max maximum-width current-width) t))))

(defun %write-ascii-wrapped-bubble (message width bubble-width mode stream)
  "Write MESSAGE's (already-validated ASCII, no-newline) word-wrapping at
WIDTH directly to STREAM as a bubble of display width BUBBLE-WIDTH -- the
ASCII counterpart to %WRITE-WRAPPED-BUBBLE below, walking MESSAGE a second
time (after %ASCII-WRAPPED-MAXIMUM-WIDTH's first pass established
BUBBLE-WIDTH) without CL-TTY-KIT's Unicode-aware character-width lookups."
  (let ((current-width 0)
        (line-started-p nil)
        (message-length (length message))
        (side (%bubble-side-character mode)))
    (labels ((start-line ()
               (write-char side stream)
               (write-char #\Space stream)
               (setf line-started-p t))
             (finish-line ()
               (unless line-started-p (start-line))
               (%write-repeated-bubble-character #\Space (- bubble-width current-width) stream)
               (write-char #\Space stream)
               (write-char side stream)
               (setf current-width 0 line-started-p nil))
             (add-chunk (chunk-start chunk-end)
               (let ((chunk-width (- chunk-end chunk-start)))
                 (cond
                   ((not line-started-p)
                    (start-line)
                    (write-string message stream :start chunk-start :end chunk-end)
                    (setf current-width chunk-width))
                   ((<= (+ current-width 1 chunk-width) width)
                    (write-char #\Space stream)
                    (write-string message stream :start chunk-start :end chunk-end)
                    (incf current-width (1+ chunk-width)))
                   (t
                    (finish-line)
                    (terpri stream)
                    (start-line)
                    (write-string message stream :start chunk-start :end chunk-end)
                    (setf current-width chunk-width))))))
      (%write-bubble-rule-character #\_ bubble-width stream)
      (terpri stream)
      (loop with cursor = 0
            while (< cursor message-length)
            for word-end = (or (position #\Space message :start cursor) message-length)
            do (when (< cursor word-end)
                 (loop with chunk-start = cursor
                       while (< chunk-start word-end)
                       for chunk-end = (min word-end (+ chunk-start width))
                       do (add-chunk chunk-start chunk-end)
                          (setf chunk-start chunk-end)))
               (setf cursor (1+ word-end)))
      (unless line-started-p (start-line))
      (finish-line)
      (terpri stream)
      (%write-bubble-rule-character #\- bubble-width stream))))

(defun %character-width-cache (message)
  "Return a (UNSIGNED-BYTE 2) array of MESSAGE's per-character
CL-TTY-KIT:CHAR-WIDTH, computed once so the two passes below (measure, then
write) over the same MESSAGE never call it on the same character twice."
  (let* ((message-length (length message))
         (character-widths (make-array message-length :element-type '(unsigned-byte 2))))
    (loop for index below message-length
          do (setf (aref character-widths index) (cl-tty-kit:char-width (char message index))))
    character-widths))

(defun %range-width-prefix-end (character-widths budget start end)
  "Return the largest index in [START, END] such that the display widths of
CHARACTER-WIDTHS[START, index) sum to at most BUDGET."
  (loop with consumed-width = 0
        with result = start
        for index from start below end
        for character-width = (aref character-widths index)
        while (<= (+ consumed-width character-width) budget)
        do (incf consumed-width character-width)
           (setf result (1+ index))
        finally (return result)))

(defun %range-cell-width (character-widths start end)
  "Return the sum of CHARACTER-WIDTHS[START, end), each floored to at least
1 -- unlike %RANGE-DISPLAY-WIDTH below, a run of zero-width combining
characters alone still counts as occupying at least one cell, so a forced
mid-word split never treats such a run as free to pack onto a full line."
  (loop for index from start below end
        sum (max 1 (aref character-widths index))))

(defun %range-display-width (character-widths start end)
  "Return the true display width of CHARACTER-WIDTHS[START, end), the sum
CL-TTY-KIT:STRING-WIDTH would report for that substring."
  (loop for index from start below end
        sum (aref character-widths index)))

(defun %call-with-wrapped-chunks (message width chunk-continuation line-continuation
                                   character-widths)
  "Walk MESSAGE's CL-TTY-KIT:WRAP-STRING-equivalent word-wrapping at WIDTH,
calling CHUNK-CONTINUATION with (START END DISPLAY-WIDTH SEPARATOR-P) for
each chunk placed on the current line (SEPARATOR-P true when a space
precedes it), and LINE-CONTINUATION with no arguments at the end of each
line. Both %WRAPPED-MAXIMUM-WIDTH and %WRITE-WRAPPED-BUBBLE below drive this
same walk, one to measure and one to write, so the wrapping decision itself
is written once."
  (let ((message-length (length message))
        (current-layout-width 0)
        (line-has-chunks-p nil))
    (labels ((finish-line ()
               (funcall line-continuation)
               (setf current-layout-width 0 line-has-chunks-p nil))
             (add-chunk (start end layout-width display-width)
               (cond
                 ((not line-has-chunks-p)
                  (funcall chunk-continuation start end display-width nil)
                  (setf current-layout-width layout-width line-has-chunks-p t))
                 ((<= (+ current-layout-width 1 layout-width) width)
                  (funcall chunk-continuation start end display-width t)
                  (incf current-layout-width (1+ layout-width)))
                 (t
                  (finish-line)
                  (funcall chunk-continuation start end display-width nil)
                  (setf current-layout-width layout-width line-has-chunks-p t))))
             (add-word (start end)
               (let ((word-width (%range-display-width character-widths start end)))
                 (if (<= word-width width)
                     (add-chunk start end word-width word-width)
                     (loop with chunk-start = start
                           while (< chunk-start end)
                           for chunk-end = (%range-width-prefix-end character-widths width
                                                                     chunk-start end)
                           do (when (= chunk-start chunk-end) (setf chunk-end (1+ chunk-start)))
                              (add-chunk chunk-start chunk-end
                                         (%range-cell-width character-widths chunk-start chunk-end)
                                         (%range-display-width character-widths chunk-start chunk-end))
                              (setf chunk-start chunk-end))))))
      (loop with paragraph-start = 0
            for newline = (position #\Newline message :start paragraph-start)
            for paragraph-end = (or newline message-length)
            do (loop with cursor = paragraph-start
                     while (< cursor paragraph-end)
                     do (let ((word-end (or (position #\Space message :start cursor :end paragraph-end)
                                             paragraph-end)))
                          (when (< cursor word-end) (add-word cursor word-end))
                          (setf cursor (1+ word-end))))
               (finish-line)
               (if newline
                   (setf paragraph-start (1+ newline))
                   (return t))))))

(defun %wrapped-maximum-width (message width)
  "Return (VALUES MAXIMUM-WIDTH CHARACTER-WIDTHS): the widest wrapped line's
display width for MESSAGE at WIDTH, and the per-character width cache built
along the way so %WRITE-WRAPPED-BUBBLE's own walk does not rebuild it."
  (let ((character-widths (%character-width-cache message))
        (maximum-width 0)
        (current-width 0))
    (%call-with-wrapped-chunks
     message width
     (lambda (start end display-width separatorp)
       (declare (ignore start end))
       (incf current-width display-width)
       (when separatorp (incf current-width)))
     (lambda ()
       (setf maximum-width (max maximum-width current-width) current-width 0))
     character-widths)
    (values maximum-width character-widths)))

(defun %write-wrapped-bubble (message width bubble-width mode stream &optional character-widths)
  "Write MESSAGE's Unicode-aware word-wrapping at WIDTH directly to STREAM
as a bubble of display width BUBBLE-WIDTH. CHARACTER-WIDTHS, when given, is
the cache %WRAPPED-MAXIMUM-WIDTH already built while measuring BUBBLE-WIDTH."
  (let ((current-width 0)
        (line-started-p nil)
        (side (%bubble-side-character mode))
        (character-widths (or character-widths (%character-width-cache message))))
    (labels ((start-line ()
               (write-char side stream)
               (write-char #\Space stream)
               (setf line-started-p t))
             (finish-line ()
               (unless line-started-p (start-line))
               (%write-repeated-bubble-character #\Space (- bubble-width current-width) stream)
               (write-char #\Space stream)
               (write-char side stream)
               (terpri stream)
               (setf current-width 0 line-started-p nil)))
      (%write-bubble-rule-character #\_ bubble-width stream)
      (terpri stream)
      (%call-with-wrapped-chunks
       message width
       (lambda (start end display-width separatorp)
         (unless line-started-p (start-line))
         (when separatorp
           (write-char #\Space stream)
           (incf current-width))
         (write-string message stream :start start :end end)
         (incf current-width display-width))
       (lambda () (finish-line))
       character-widths)
      (%write-bubble-rule-character #\- bubble-width stream))))

(defun %write-say (message stream &key (character "cow") (mode :speech) eyes tongue (width 40)
                                     no-wrap)
  "Write MESSAGE's rendering (see SAY) directly to STREAM instead of
returning it as a string."
  (check-type message string)
  (unless (and (integerp width) (plusp width))
    (error 'invalid-message :width width))
  (let* ((template (find-character-template character))
         (eyes (or eyes "oo"))
         (tongue (or tongue ""))
         (thoughts (string (%bubble-thoughts-character mode)))
         ;; A staged (multi-pass FILL-TEMPLATE-LINE) substitution is only
         ;; needed when EYES/TONGUE/THOUGHTS themselves contain another
         ;; placeholder's literal text -- the ordinary case writes each
         ;; character template line's precompiled CHUNKS straight through.
         (staged-substitution-p (or (search "${eyes}" eyes)
                                     (search "${tongue}" tongue)
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
                 (%write-template-line line stream eyes tongue thoughts t)
                 (%write-compiled-template-line chunks stream eyes tongue thoughts)))))

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
  (with-output-to-string (stream)
    (%write-say message stream :character character :mode mode :eyes eyes :tongue tongue
                                :width width :no-wrap no-wrap)))
