;;;; src/package.lisp
;;;;
;;;; Two packages, both defined here per PACKAGE_STANDARD.md: CL-COWSAY is the
;;;; rendering library (word-wrap a message into a bubble above a built-in
;;;; ASCII-art character) and CL-COWSAY/CLI is the thin command-line front
;;;; end over it. Splitting them keeps `(asdf:load-system "cl-cowsay")`
;;;; usable as a library with no CL-CLI-flavoured argv parsing along for the
;;;; ride.

(defpackage #:cl-cowsay
  (:use #:cl)
  (:export
   ;; Rendering
   #:say
   ;; Built-in characters
   #:list-characters
   #:character-known-p
   ;; Conditions
   #:cl-cowsay-error
   #:unknown-character
   #:unknown-character-name
   #:invalid-message
   #:invalid-message-width))

(defpackage #:cl-cowsay/cli
  (:documentation "The `cl-cowsay` command-line front end over CL-COWSAY.")
  (:use #:cl)
  (:import-from #:cl-cowsay
                #:say
                #:list-characters
                #:cl-cowsay-error)
  (:import-from #:cl-cli
                #:make-app
                #:make-option
                #:make-positional
                #:run-app
                #:option-value
                #:positional-value
                #:invocation-stdout
                #:current-process-argv)
  (:export
   #:make-cowsay-app
   #:main
   #:image-entry-point))
