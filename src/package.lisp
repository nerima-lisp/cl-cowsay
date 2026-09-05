(defpackage #:cl-cowsay
  (:documentation "Word-wrap a message into a speech or thought bubble above
a built-in ASCII-art character. LIST-CHARACTERS and LIST-EYE-PRESETS name
every built-in this library ships; WRITE-SAY is the streaming renderer.")
  (:use #:cl)
  (:export
   #:write-say
   #:+default-timeout-seconds+
   #:with-operation-timeout
   #:list-characters
   #:character-known-p
   #:list-eye-presets
   #:eyes-preset-string
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
