;;;; src/macros.lisp
;;;;
;;;; Every DEFMACRO this library defines for its own use, collected in one
;;;; place and loaded first so later files can treat them as ordinary syntax.
;;;; Two macros, two DATA/LOGIC seams:
;;;;
;;;;   DEFINE-COWSAY-CONDITION lets src/conditions.lisp be nothing but
;;;;   name/slot/message DATA, with the DEFINE-CONDITION boilerplate that
;;;;   shape shares written once, here, as LOGIC.
;;;;
;;;;   DEFCHARACTER lets src/characters-data.lisp be nothing but literal
;;;;   ASCII-art DATA, with the registry call that puts each character
;;;;   somewhere CL-COWSAY:SAY can find it written once, here, as LOGIC.
;;;;
;;;; Neither macro controls evaluation order or introduces new syntax for its
;;;; own sake -- both exist because CL-COWSAY has more than one form of the
;;;; exact same shape, and a macro is how Lisp says that once.

(in-package #:cl-cowsay)

(defmacro define-cowsay-condition (name (slot) &body clauses)
  "Define NAME as a CL-COWSAY-ERROR carrying one SLOT, from a :REPORT-FORMAT
clause and a :DOCUMENTATION clause -- the shape every condition in
src/conditions.lisp shares. Expands to a DEFINE-CONDITION with:

  - one slot, SLOT, with initarg :SLOT and reader NAME-SLOT
  - a :REPORT lambda built from (:report-format CONTROL-STRING ARG*), where
    each ARG is either the bare symbol SLOT (read off the signaled condition
    via the generated reader) or any other form, evaluated as-is -- so a
    report can also mention data the condition itself does not carry, such
    as LIST-CHARACTERS
  - the :DOCUMENTATION string from (:documentation STRING), passed through
    verbatim

CLAUSES may appear in either order; both are required."
  (let* ((reader (intern (format nil "~A-~A" name slot)))
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
  "Register NAME -- an unevaluated symbol, downcased to its registry name --
under LINES, literal template strings top to bottom, via REGISTER-CHARACTER.
Every built-in character in src/characters-data.lisp is one DEFCHARACTER
form; LIST-CHARACTERS and SAY see it the moment that file loads."
  `(register-character ,(string-downcase (symbol-name name)) (list ,@lines)))
