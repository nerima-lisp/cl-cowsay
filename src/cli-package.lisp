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
                #:operation-timeout
                #:stdin-too-large)
  (:import-from #:cl-cli
                #:define-app
                #:run-app
                #:option-value
                #:positional-value
                #:invocation-stdout
                #:invocation-stderr
                #:current-process-argv
                #:render-completion)
  (:import-from #:host-kit
                #:quit
                #:getcwd)
  (:export
   #:*cowsay-app*
   #:main
   #:image-entry-point))
