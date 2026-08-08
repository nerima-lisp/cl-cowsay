;;;; src/characters-definitions.lisp
;;;;
;;;; Character representation and registry state. The runtime registry
;;;; operations live in src/characters.lisp; built-in character data lives in
;;;; src/characters-data.lisp.

(in-package #:cl-cowsay)

(defstruct (character-template (:conc-name character-template-))
  "NAME is the lowercase string a caller selects with. LINES is the raw,
unsubstituted art, one string per row. CHUNKS is LINES' compiled
substitution plan (%COMPILE-TEMPLATE-LINE, src/template.lisp) -- the plan
WRITE-SAY replays against its output stream for a render that never rescans a
template line for ${...} placeholders."
  (name "" :type string :read-only t)
  (lines nil :type list :read-only t)
  (chunks nil :type list :read-only t))

(defparameter *characters* (make-hash-table :test 'equal)
  "Maps a lowercase character name to its CHARACTER-TEMPLATE. Populated by
REGISTER-CHARACTER at load time; never mutated afterward.")
