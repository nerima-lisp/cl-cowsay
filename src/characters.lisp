;;;; src/characters.lisp
;;;;
;;;; Registry LOGIC only: CHARACTER-TEMPLATE, the *CHARACTERS* table, and the
;;;; REGISTER-CHARACTER/LIST-CHARACTERS/CHARACTER-KNOWN-P/
;;;; FIND-CHARACTER-TEMPLATE operations over it. Each registered character is
;;;; CHARACTER-LINES: a list of plain strings, top to bottom, that may
;;;; reference the ${eyes}/${tongue}/${thoughts} placeholders
;;;; FILL-TEMPLATE-LINE expands. The DATA -- every built-in character, as a
;;;; DEFCHARACTER form -- lives in src/characters-data.lisp, which depends on
;;;; REGISTER-CHARACTER defined here.

(in-package #:cl-cowsay)

(defstruct (character-template (:conc-name character-template-))
  "NAME is the lowercase string a caller selects with. LINES is the raw,
unsubstituted art, one string per row. CHUNKS is LINES' compiled
substitution plan (%COMPILE-TEMPLATE-LINE, src/template.lisp) -- the plan
SAY replays against its output stream for a render that never rescans a
template line for ${...} placeholders."
  (name "" :type string :read-only t)
  (lines nil :type list :read-only t)
  (chunks nil :type list :read-only t))

(defparameter *characters* (make-hash-table :test 'equal)
  "Maps a lowercase character name to its CHARACTER-TEMPLATE. Populated below
by REGISTER-CHARACTER at load time; never mutated afterward.")

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
