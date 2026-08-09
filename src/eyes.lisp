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
;;;;
;;;; The absence of an IN-PACKAGE form here is deliberate: cl-cowsay.asd
;;;; binds *PACKAGE* to CL-COWSAY around every compile through
;;;; :AROUND-COMPILE, so these definitions land in CL-COWSAY without one.
;;;; Note also that every source file that does carry an IN-PACKAGE form is
;;;; on the coverage gate's exclusion list in t/package.lisp, while every
;;;; file the gate measures -- this one included -- omits it.

(defun list-eye-presets ()
  "Return every eyes-preset name, in the fixed order +EYE-PRESETS+ lists
  them."
  (mapcar #'car +eye-presets+))

(defun eyes-preset-string (name)
  "Return the ${eyes} string for NAME (case-insensitive), one of
LIST-EYE-PRESETS. Signals UNKNOWN-EYES-PRESET when NAME is not registered."
  (or (cdr (assoc (string-downcase name) +eye-presets+ :test #'string=))
      (error 'unknown-eyes-preset :name name)))
