;;;; src/package.lisp
;;;;
;;;; Two packages, both defined here per PACKAGE_STANDARD.md: CL-COWSAY is the
;;;; rendering library (word-wrap a message into a bubble above a built-in
;;;; ASCII-art character) and CL-COWSAY/CLI is the thin command-line front
;;;; end over it. Splitting them keeps `(asdf:load-system "cl-cowsay")`
;;;; usable as a library with no CL-CLI-flavoured argv parsing along for the
;;;; ride.

(defpackage #:cl-cowsay
  (:documentation "Word-wrap a message into a speech or thought bubble above
a built-in ASCII-art character. LIST-CHARACTERS and LIST-EYE-PRESETS name
every built-in this library ships; SAY is the one function that renders
one.")
  (:use #:cl)
  (:export
   ;; Rendering
   #:say
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
   #:stdin-too-large-limit))

(defpackage #:cl-cowsay/cli
  (:documentation "The `cl-cowsay` command-line front end over CL-COWSAY.")
  (:use #:cl)
  (:import-from #:cl-cowsay
                #:list-characters
                #:list-eye-presets
                #:eyes-preset-string
                #:cl-cowsay-error
                #:stdin-too-large
                #:stdin-too-large-limit)
  (:import-from #:cl-cli
                #:define-app
                #:run-app
                #:option-value
                #:positional-value
                #:invocation-stdout
                #:current-process-argv
                #:render-completion)
  (:import-from #:host-kit
                #:quit
                #:getcwd)
  (:export
   #:*cowsay-app*
   #:main
   #:image-entry-point))
