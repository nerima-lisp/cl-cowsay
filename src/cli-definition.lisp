;;;; src/cli-definition.lisp
;;;;
;;;; Declarative cl-cli application definition. Runtime handlers are in
;;;; src/cli.lisp and resource limits are in src/cli-configuration.lisp.
(in-package #:cl-cowsay/cli)
(defun %cowsay-version () "Return the CL-COWSAY ASDF version." (let ((system (asdf:find-system "cl-cowsay" nil))) (if system (asdf:component-version system) "0.0.0")))

(define-app
 *cowsay-app*
 (:name
  "cl-cowsay"
  :version
  (%cowsay-version)
  :summary
  "Render an ASCII-art character saying or thinking a message."
  :description
  "Word-wraps MESSAGE -- given as positional words, or read from standard
input when none are given -- into a speech or thought bubble drawn above a
built-in ASCII-art character."
  :handler
  (function %cowsay-handler))
 (:option
  "character"
  :short
  #\c
  :kind
  :value
  :choices
  (list-characters)
  :default
  "cow"
  :description
  "Built-in character to draw.")
 (:option
  "think"
  :short
  #\T
  :kind
  :flag
  :description
  "Use a thought bubble instead of a speech bubble.")
 (:option
  "eyes"
  :short
  #\e
  :kind
  :value
  :description
  "Override the character eyes (default \"oo\").")
 (:option
  "eyes-preset"
  :short
  #\E
  :kind
  :value
  :choices
  (list-eye-presets)
  :description
  "Preset eyes; --eyes overrides this.")
 (:option
  "tongue"
  :short
  #\t
  :kind
  :value
  :description
  "Override the character tongue (default empty).")
 (:option
  "width"
  :short
  #\w
  :kind
  :value
  :type
  :integer
  :min
  1
  :default
  40
  :description
  "Column width to wrap MESSAGE to.")
 (:option
  "timeout"
  :short
  #\o
  :kind
  :value
  :type
  :number
  :min
  0.001
  :default
  +default-timeout-seconds+
  :description
  "Wall-clock seconds allowed for one operation.")
 (:option
  "no-wrap"
  :short
  #\n
  :kind
  :flag
  :description
  "Do not word-wrap MESSAGE; only its own embedded newlines break lines.")
 (:option
  "list"
  :short
  #\l
  :kind
  :flag
  :description
  "List every built-in character name and exit.")
 (:option
  "random"
  :short
  #\r
  :kind
  :flag
  :description
  "Pick a random built-in character, ignoring --character.")
 (:option
  "completion"
  :kind
  :value
  :choices
  (list "bash" "zsh" "fish" "powershell" "nushell" "elvish")
  :description
  "Print a shell completion script for the named shell and exit.")
 (:positional
  :message
  :rest-p
  t
  :description
  "Words of the message. Reads standard input when omitted."))
