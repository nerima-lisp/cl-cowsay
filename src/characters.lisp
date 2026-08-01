;;;; src/characters.lisp
;;;;
;;;; The built-in character registry. Each character is CHARACTER-LINES: a
;;;; list of plain strings, top to bottom, that may reference the
;;;; ${eyes}/${tongue}/${thoughts} placeholders FILL-TEMPLATE-LINE expands.
;;;; Every character below is original ASCII art written for this project --
;;;; none of it is copied from, or a rendering of, upstream cowsay's .cow
;;;; files.

(in-package #:cl-cowsay)

(defstruct (character-template (:conc-name character-template-))
  "NAME is the lowercase string a caller selects with. LINES is the raw,
unsubstituted art, one string per row."
  (name "" :type string :read-only t)
  (lines nil :type list :read-only t))

(defparameter *characters* (make-hash-table :test 'equal)
  "Maps a lowercase character name to its CHARACTER-TEMPLATE. Populated below
by REGISTER-CHARACTER at load time; never mutated afterward.")

(defun register-character (name lines)
  "Register LINES (a list of template strings) under NAME (case-insensitive).
Re-registering an existing NAME replaces it, which is what lets this file
simply be re-loaded during development."
  (setf (gethash (string-downcase name) *characters*)
        (make-character-template :name (string-downcase name) :lines lines))
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

;;; --------------------------------------------------------------------------
;;; Built-in characters
;;; --------------------------------------------------------------------------

;; The default. Ears, a two-character ${eyes} slot, a body that carries
;; ${tongue} (empty by default), and two hoof legs.
(register-character
 "cow"
 (list "        ${thoughts}   ^__^"
       "         ${thoughts}  (${eyes})"
       "            (__${tongue})"
       "             u  u"))

;; Whiskers, a ${eyes} slot between them, and a ${tongue} slot at the mouth.
(register-character
 "cat"
 (list "       ${thoughts}   /\\_/\\"
       "        ${thoughts}  (${eyes} )"
       "              >${tongue}<"
       "             /     \\"))

;; A boxy head with an ${eyes}/${tongue} display panel and an antenna.
(register-character
 "robot"
 (list "          ${thoughts}    (_)"
       "         ${thoughts}  .-----."
       "          ${thoughts} |${eyes} ${tongue}|"
       "            '--|-|--'"
       "               |_|"))

;; A wavy-bottomed sheet with a face; ${tongue} shows as a small mouth mark.
(register-character
 "ghost"
 (list "        ${thoughts}   .-\"\"-."
       "         ${thoughts}  (${eyes}${tongue})"
       "             )      ("
       "            ^  ^  ^  ^"))
