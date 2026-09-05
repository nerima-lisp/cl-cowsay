
(in-package #:cl-cowsay)

(defvar +eye-presets+
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
