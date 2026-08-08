;;;; src/package.lisp
;;;;
;;;; CL-COWSAY is the rendering library (word-wrap a message into a bubble
;;;; above a built-in ASCII-art character). The command-line package lives in
;;;; CLI-PACKAGE.LISP so loading this library does not load CLI dependencies.

(defpackage #:cl-cowsay
  (:documentation "Word-wrap a message into a speech or thought bubble above
a built-in ASCII-art character. LIST-CHARACTERS and LIST-EYE-PRESETS name
every built-in this library ships; WRITE-SAY is the streaming renderer.")
  (:use #:cl)
  (:export
   ;; Rendering
   #:write-say
   #:+default-timeout-seconds+
   #:with-operation-timeout
   ;; Built-in characters
   #:list-characters
   #:character-known-p
   ;; Eyes presets
   #:list-eye-presets
   #:eyes-preset-string
   ;; Conditions
   #:cl-cowsay-error
   #:unknown-character
   #:unknown-character-name
   #:unknown-eyes-preset
   #:unknown-eyes-preset-name
   #:invalid-message
   #:invalid-message-width
   #:stdin-too-large
   #:stdin-too-large-limit
   #:invalid-timeout
   #:invalid-timeout-seconds
   #:operation-timeout
   #:operation-timeout-operation))
