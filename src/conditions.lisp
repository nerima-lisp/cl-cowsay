;;;; src/conditions.lisp
;;;;
;;;; CL-COWSAY-ERROR is the one package-specific base condition, written out
;;;; by hand since it carries no slot and no report -- there is no shape here
;;;; for a macro to factor out. Every other condition is DATA only: a
;;;; DEFINE-COWSAY-CONDITION form (src/macros.lisp) naming its slot, its
;;;; :REPORT-FORMAT control string and args, and its :DOCUMENTATION string.
;;;; Deriving all of them from CL-COWSAY-ERROR lets a caller catch every
;;;; failure this library raises with one HANDLER-CASE clause.

(in-package #:cl-cowsay)

(define-condition cl-cowsay-error (error)
  ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (write-string "An error occurred in cl-cowsay." stream)))
  (:documentation "Base condition for every error CL-COWSAY signals. Every
condition below has its own, more specific :REPORT; this one only prints
when CL-COWSAY-ERROR itself is signaled directly, which no code in this
library does."))

(define-cowsay-condition unknown-character (name)
  (:report-format "Unknown character ~S. Known characters: ~{~A~^, ~}" name (list-characters))
  (:documentation "Signaled when WRITE-SAY is asked for a character name
that is not registered. LIST-CHARACTERS names every built-in this library
ships."))

(define-cowsay-condition invalid-message (width)
  (:report-format "WIDTH must be a positive integer, got ~S" width)
  (:documentation "Signaled when WRITE-SAY is given a wrap WIDTH that is
not a positive integer."))

(define-cowsay-condition unknown-eyes-preset (name)
  (:report-format "Unknown eyes preset ~S. Known presets: ~{~A~^, ~}" name (list-eye-presets))
  (:documentation "Signaled when EYES-PRESET-STRING is asked for a preset
name that is not registered. LIST-EYE-PRESETS names every built-in preset
this library ships."))

(define-cowsay-condition stdin-too-large (limit)
  (:report-format "Standard input exceeded ~D characters without reaching EOF" limit)
  (:documentation "Signaled when reading a message from standard input (no
positional MESSAGE words given on the command line) sees more than
STDIN-TOO-LARGE-LIMIT characters without reaching EOF, so an unbounded or
accidental huge input source cannot grow memory without bound before any
rendering happens."))

(defconstant +default-timeout-seconds+ 10
  "Default wall-clock limit for one rendering or command-line operation.")

(define-cowsay-condition invalid-timeout (seconds)
  (:report-format "TIMEOUT-SECONDS must be a positive real, got ~S" seconds)
  (:documentation "Signaled when a rendering or command-line timeout is not a
positive real number."))

(define-cowsay-condition operation-timeout (operation)
  (:report-format "Operation ~S exceeded its timeout" operation)
  (:documentation "Signaled when a bounded cl-cowsay operation exceeds its
wall-clock timeout."))
