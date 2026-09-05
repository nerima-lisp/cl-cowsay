
(in-package #:cl-cowsay)

(defparameter +bubble-space-chunk+ (make-string 256 :initial-element #\Space)
  "A preallocated run of spaces %WRITE-REPEATED-BUBBLE-CHARACTER slices from,
so writing N padding spaces need not MAKE-STRING a fresh one per call.")
(defparameter +bubble-underscore-chunk+ (make-string 256 :initial-element #\_)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's top-rule \"_\" run.")
(defparameter +bubble-dash-chunk+ (make-string 256 :initial-element #\-)
  "As +BUBBLE-SPACE-CHUNK+, for a bubble's bottom-rule \"-\" run.")
