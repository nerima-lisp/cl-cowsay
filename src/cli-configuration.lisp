(in-package #:cl-cowsay/cli)

(defparameter *max-stdin-message-length* (* 64 1024)
  "Maximum number of characters %READ-STDIN-MESSAGE reads before signaling
STDIN-TOO-LARGE.")

(defconstant +exit-data-error+ 65
  "EX_DATAERR exit code for input exceeding
*MAX-STDIN-MESSAGE-LENGTH*.")

(defconstant +exit-temporary-failure+ 75
  "EX_TEMPFAIL exit code for an operation that exceeds its timeout.")
