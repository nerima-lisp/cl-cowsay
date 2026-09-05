
(in-package #:cl-cowsay)

(define-condition cl-cowsay-error (error)
  ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (write-string "An error occurred in cl-cowsay." stream)))
  (:documentation "Base condition for every error CL-COWSAY signals."))

(define-cowsay-condition unknown-character (name)
  (:report-format "Unknown character ~S. Known characters: ~{~A~^, ~}" name (list-characters))
  (:documentation "Signaled when WRITE-SAY is given an unknown character."))

(define-cowsay-condition invalid-message (width)
  (:report-format "WIDTH must be a positive integer, got ~S" width)
  (:documentation "Signaled when WRITE-SAY is given a wrap WIDTH that is
not a positive integer."))

(define-cowsay-condition unknown-eyes-preset (name)
  (:report-format "Unknown eyes preset ~S. Known presets: ~{~A~^, ~}" name (list-eye-presets))
  (:documentation "Signaled when EYES-PRESET-STRING is given an unknown preset."))

(define-cowsay-condition stdin-too-large (limit)
  (:report-format "Standard input exceeded ~D characters without reaching EOF" limit)
  (:documentation "Signaled when standard input exceeds its configured limit."))

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
