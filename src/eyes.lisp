
(defun list-eye-presets ()
  "Return every eyes-preset name, in the fixed order +EYE-PRESETS+ lists
  them."
  (mapcar #'car +eye-presets+))

(defun eyes-preset-string (name)
  "Return the ${eyes} string for NAME (case-insensitive), one of
LIST-EYE-PRESETS. Signals UNKNOWN-EYES-PRESET when NAME is not registered."
  (or (cdr (assoc (string-downcase name) +eye-presets+ :test #'string=))
      (error 'unknown-eyes-preset :name name)))
