;;;; src/characters.lisp
;;;;
;;;; Runtime operations for the character registry. The data structures and
;;;; registry storage are defined in src/characters-definitions.lisp.
;;;;
;;;; These definitions land in CL-COWSAY because cl-cowsay.asd's
;;;; :AROUND-COMPILE thunk binds *PACKAGE* around every compile, not because
;;;; of an IN-PACKAGE form here -- every file the 100% coverage gate measures
;;;; omits that form, and src/macros.lisp records the other half of the
;;;; convention.

(defun register-character (name lines)
  "Register LINES (a list of template strings) under NAME (case-insensitive).
Re-registering an existing NAME replaces it, which is what lets this file
simply be re-loaded during development."
  (let ((canonical-name (string-downcase name)))
    (setf (gethash canonical-name *characters*)
          (make-character-template :name canonical-name :lines lines
                                    :chunks (mapcar #'%compile-template-line lines))))
  name)

(defun list-characters ()
  "Return every registered character name, sorted alphabetically."
  (sort (loop for name being the hash-keys of *characters* collect name)
        #'string<))

(defun character-known-p (name)
  "True when NAME (case-insensitive) names a registered character."
  (and (nth-value 1 (gethash (string-downcase name) *characters*)) t))

(defun find-character-template (name)
  "Return the CHARACTER-TEMPLATE registered under NAME (case-insensitive), or
signal UNKNOWN-CHARACTER when there is none."
  (or (gethash (string-downcase name) *characters*)
      (error 'unknown-character :name name)))
