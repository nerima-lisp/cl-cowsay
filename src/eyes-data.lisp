;;;; src/eyes-data.lisp
;;;;
;;;; DATA only: *EYE-PRESETS*, the classic cowsay eyes-shortcut presets
;;;; (borg, dead, greedy, paranoid, stoned, tired, wired, youthful) as an
;;;; alist of name/string pairs. LOGIC over it -- LIST-EYE-PRESETS and
;;;; EYES-PRESET-STRING -- lives in src/eyes.lisp and loads second, after
;;;; this file, so the compiler sees this DEFPARAMETER before it sees either
;;;; function's reference to *EYE-PRESETS*. The command line's
;;;; --eyes-preset/-E option (src/cli.lisp) resolves a preset name through
;;;; EYES-PRESET-STRING before passing it on as SAY's :EYES argument, and an
;;;; explicit --eyes always takes precedence over a preset, so this data
;;;; never touches SAY's own "oo" default.

(in-package #:cl-cowsay)

(defparameter *eye-presets*
  '(("borg" . "==")
    ("dead" . "XX")
    ("greedy" . "$$")
    ("paranoid" . "@@")
    ("stoned" . "**")
    ("tired" . "--")
    ("wired" . "OO")
    ("youthful" . ".."))
  "Maps a lowercase eyes-preset name to the ${eyes} string it expands to.
Order here is the order LIST-EYE-PRESETS returns them in.")
