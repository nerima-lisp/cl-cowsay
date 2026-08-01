;;;; src/conditions.lisp
;;;;
;;;; A single package-specific base condition, with every condition CL-COWSAY
;;;; signals deriving from it, so a caller can catch every failure this
;;;; library raises with one HANDLER-CASE clause on CL-COWSAY-ERROR.

(in-package #:cl-cowsay)

(define-condition cl-cowsay-error (error)
  ()
  (:documentation "Base condition for every error CL-COWSAY signals."))

(define-condition unknown-character (cl-cowsay-error)
  ((name :initarg :name :reader unknown-character-name))
  (:report (lambda (condition stream)
             (format stream "Unknown character ~S. Known characters: ~{~A~^, ~}"
                     (unknown-character-name condition) (list-characters))))
  (:documentation "Signaled when SAY is asked for a character name that is not
registered. LIST-CHARACTERS names every built-in this library ships."))

(define-condition invalid-message (cl-cowsay-error)
  ((width :initarg :width :reader invalid-message-width))
  (:report (lambda (condition stream)
             (format stream "WIDTH must be a positive integer, got ~S"
                     (invalid-message-width condition))))
  (:documentation "Signaled when SAY is given a wrap WIDTH that is not a
positive integer."))

(define-condition stdin-too-large (cl-cowsay-error)
  ((limit :initarg :limit :reader stdin-too-large-limit))
  (:report (lambda (condition stream)
             (format stream "Standard input exceeded ~D characters without reaching EOF; refusing to read further"
                     (stdin-too-large-limit condition))))
  (:documentation "Signaled when reading a message from standard input (no
positional MESSAGE words given on the command line) sees more than
STDIN-TOO-LARGE-LIMIT characters without reaching EOF, so an unbounded or
accidental huge input source cannot grow memory without bound before any
rendering happens."))
