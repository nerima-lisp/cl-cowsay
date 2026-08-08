;;;; src/cli-package.lisp
;;;;
;;;; The command-line package is loaded only by CL-COWSAY/CLI. Keeping this
;;;; DEFPACKAGE in the executable system means the rendering library does not
;;;; load CL-CLI or CL-HOST-KIT just to provide WRITE-SAY.

(defpackage #:cl-cowsay/cli
  (:documentation "The `cl-cowsay` command-line front end over CL-COWSAY.")
  (:use #:cl)
  (:import-from #:cl-cowsay
                #:write-say
                #:list-characters
                #:list-eye-presets
                #:eyes-preset-string
                #:+default-timeout-seconds+
                #:with-operation-timeout
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
