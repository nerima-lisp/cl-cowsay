;;;; src/eyes.lisp
;;;;
;;;; LOGIC only: LIST-EYE-PRESETS and EYES-PRESET-STRING over the
;;;; +EYE-PRESETS+ alist. DATA -- the classic cowsay eyes-shortcut presets
;;;; themselves -- lives in src/eyes-data.lisp and loads first: unlike
;;;; src/characters.lisp/src/characters-data.lisp (where the DATA file calls
;;;; the LOGIC file's REGISTER-CHARACTER, so LOGIC must load first), the two
;;;; functions here reference +EYE-PRESETS+ directly, so DATA loads first
;;;; here instead, to give the compiler a DEFVAR for it to see before
;;;; it sees a reference.

(defun list-eye-presets ()
  "Return every eyes-preset name, in the fixed order +EYE-PRESETS+ lists
  them."
  (mapcar #'car +eye-presets+))

(defun eyes-preset-string (name)
  "Return the ${eyes} string for NAME (case-insensitive), one of
LIST-EYE-PRESETS. Signals UNKNOWN-EYES-PRESET when NAME is not registered."
  (or (cdr (assoc (string-downcase name) +eye-presets+ :test #'string=))
      (error 'unknown-eyes-preset :name name)))
