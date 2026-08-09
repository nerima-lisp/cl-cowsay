;;;; src/bubble-data.lisp
;;;;
;;;; Preallocated character runs used by the streaming bubble renderer in
;;;; src/bubble.lisp.
;;;;
;;;; The +...+ names are deliberate against the DEFPARAMETER, not an
;;;; oversight in either direction, and the reason is the same for all three
;;;; chunks below. Each is a constant by contract -- allocated once at load,
;;;; only ever read from and sliced, never written into or rebound -- and the
;;;; plus signs state that contract. None is a DEFCONSTANT, because SBCL
;;;; refuses to redefine a DEFCONSTANT whose new value is not EQL to the old
;;;; one, and MAKE-STRING hands back a new object on every repeated ASDF load
;;;; of this file. So the operator is chosen to keep reloading possible and
;;;; the names are chosen to state the immutability the operator no longer
;;;; implies. Renaming these to *BUBBLE-...* would advertise a mutability
;;;; that no code in this system has.

(in-package #:cl-cowsay)

(defparameter +bubble-space-chunk+ (make-string 256 :initial-element #\Space)
  "A preallocated run of spaces %WRITE-REPEATED-BUBBLE-CHARACTER slices from,
so writing N padding spaces need not MAKE-STRING a fresh one per call.")
(defparameter +bubble-underscore-chunk+ (make-string 256 :initial-element #\_)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's top-rule \"_\" run.")
(defparameter +bubble-dash-chunk+ (make-string 256 :initial-element #\-)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's bottom-rule \"-\" run.")
