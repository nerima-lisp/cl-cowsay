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

(defconstant +exit-data-error+ 65
  "Process exit code for input this command could not accept -- today, standard
input longer than *MAX-STDIN-MESSAGE-LENGTH*, which signals STDIN-TOO-LARGE.
65 is EX_DATAERR from sysexits.h. CL-CLI's RUN-APP exits 70 (EX_SOFTWARE) for
every error that escapes a handler, which is the right code for a bug in this
program and the wrong one here: nothing malfunctioned, the input was simply
larger than the documented limit. Spending a distinct code on it lets a script
around cl-cowsay tell the two apart -- 65 means fix the input, 70 means file a
bug -- and that distinction is the only reason this constant exists.

DEFCONSTANT rather than DEFPARAMETER because the value is an integer: EQL
holds when this form is re-evaluated, so reloading the system under ASDF
cannot trip the constant-redefinition error a non-EQL literal would.")

(defconstant +exit-temporary-failure+ 75
  "Process exit code for a run that hit its wall-clock limit, which
WITH-OPERATION-TIMEOUT signals as OPERATION-TIMEOUT. 75 is EX_TEMPFAIL from
sysexits.h. Like +EXIT-DATA-ERROR+ this displaces CL-CLI's blanket 70
(EX_SOFTWARE), and for a sharper reason: an expiry is not a verdict about the
input at all. The same command may succeed on the next attempt, or on this one
with a larger --timeout, so the honest signal is `temporary failure, retrying
is meaningful' rather than `this program is broken'. A supervisor or retry
loop reading exit codes needs exactly that distinction, and 70 denies it one.

DEFCONSTANT rather than DEFPARAMETER for the same reason as above: an integer
is EQL to itself across an ASDF reload, so re-evaluating this form is safe.")
