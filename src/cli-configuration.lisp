;;;; src/cli-configuration.lisp
;;;;
;;;; Resource limits and other CLI configuration. The command declaration is
;;;; in src/cli-definition.lisp; runtime handlers are in src/cli.lisp.
(in-package #:cl-cowsay/cli)

(defparameter *max-stdin-message-length* (* 64 1024)
  "Upper bound, in characters, on how much %READ-STDIN-MESSAGE will read from
*STANDARD-INPUT* before signaling STDIN-TOO-LARGE. cl-cowsay is a cosmetic
terminal toy, not a document processor, so this is generous rather than
tight -- large enough that no legitimate piped message could hit it, small
enough that an unbounded or accidental huge input source (`cat /dev/zero |
cl-cowsay`) cannot grow memory without bound or hang before any rendering
happens.")
