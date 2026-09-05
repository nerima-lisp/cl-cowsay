(in-package #:cl-cowsay)

(defmacro define-cowsay-condition (name (slot) &body clauses)
  "Define a condition with one slot, report format, and documentation."
  (check-type name symbol)
  (check-type slot symbol)
  (let* ((reader (intern (format nil "~A-~A" name slot) (symbol-package name)))
         (report-clause (assoc :report-format clauses))
         (documentation-clause (assoc :documentation clauses)))
    (assert report-clause ()
            "DEFINE-COWSAY-CONDITION ~A: missing a (:report-format ...) clause." name)
    (assert documentation-clause ()
            "DEFINE-COWSAY-CONDITION ~A: missing a (:documentation ...) clause." name)
    (destructuring-bind (control-string &rest args) (rest report-clause)
      `(define-condition ,name (cl-cowsay-error)
           ((,slot :initarg ,(intern (symbol-name slot) :keyword) :reader ,reader))
         (:report (lambda (condition stream)
                    (format stream ,control-string
                            ,@(mapcar (lambda (arg)
                                        (if (eq arg slot) `(,reader condition) arg))
                                      args))))
         (:documentation ,(second documentation-clause))))))

(defmacro defcharacter (name &body lines)
  "Register NAME with its literal template lines."
  (check-type name symbol)
  (dolist (line lines)
    (check-type line string))
  `(register-character ,(string-downcase (symbol-name name)) ',(copy-list lines)))

(defvar *enclosing-operation-deadlines* '()
  "Active timeout deadlines, ordered from innermost to outermost.")

(defmacro with-operation-timeout ((operation timeout-seconds) &body body)
  "Run BODY with a positive wall-clock limit and signal OPERATION-TIMEOUT."
  (let ((seconds-variable (gensym "SECONDS"))
        (deadline-variable (gensym "DEADLINE"))
        (enclosing-variable (gensym "ENCLOSING"))
        (now-variable (gensym "NOW"))
        (condition-variable (gensym "CONDITION")))
    `(let ((,seconds-variable ,timeout-seconds))
       (unless (and (realp ,seconds-variable) (plusp ,seconds-variable))
         (error 'invalid-timeout :seconds ,seconds-variable))
       (let ((,deadline-variable
               (+ (get-internal-real-time)
                  (* ,seconds-variable internal-time-units-per-second)))
             (,enclosing-variable *enclosing-operation-deadlines*))
         (handler-case
             (let ((*enclosing-operation-deadlines*
                     (cons ,deadline-variable ,enclosing-variable)))
               (sb-ext:with-timeout ,seconds-variable
                 (progn ,@body)))
           (sb-ext:timeout (,condition-variable)
             (let ((,now-variable (get-internal-real-time)))
               (if (and (>= ,now-variable ,deadline-variable)
                        (notany (lambda (enclosing-deadline)
                                  (>= ,now-variable enclosing-deadline))
                                ,enclosing-variable))
                   (error 'operation-timeout :operation ,operation)
                   (error ,condition-variable)))))))))
