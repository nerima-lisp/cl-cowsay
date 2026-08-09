;;;; src/macros.lisp
;;;;
;;;; Every DEFMACRO this library defines for its own use, collected in one
;;;; place and loaded first so later files can treat them as ordinary syntax.
;;;; Two macros, two DATA/LOGIC seams:
;;;;
;;;;   DEFINE-COWSAY-CONDITION lets src/conditions.lisp be nothing but
;;;;   name/slot/message DATA, with the DEFINE-CONDITION boilerplate that
;;;;   shape shares written once, here, as LOGIC.
;;;;
;;;;   DEFCHARACTER lets src/characters-data.lisp be nothing but literal
;;;;   ASCII-art DATA, with the registry call that puts each character
;;;;   somewhere CL-COWSAY:WRITE-SAY can find it written once, here, as LOGIC.
;;;;
;;;; Neither macro controls evaluation order or introduces new syntax for its
;;;; own sake -- both exist because CL-COWSAY has more than one form of the
;;;; exact same shape, and a macro is how Lisp says that once.
;;;;
;;;; WITH-OPERATION-TIMEOUT is the exception to that last paragraph and the
;;;; reason this file is not purely DEFMACRO forms. It does control evaluation
;;;; -- it establishes a wall-clock deadline around its body -- so it has to be
;;;; a macro rather than a function taking a thunk only insofar as callers read
;;;; better for it, but what it genuinely needs is state: nested deadlines
;;;; cannot be told apart from the SB-EXT:TIMEOUT condition alone. The DEFVAR
;;;; carrying that state, *ENCLOSING-OPERATION-DEADLINES*, sits immediately
;;;; above the macro because those two forms are each other's only reader and
;;;; writer.
;;;;
;;;; This file keeps an IN-PACKAGE form even though cl-cowsay.asd's
;;;; :AROUND-COMPILE thunk already binds *PACKAGE* for every file in the
;;;; system: it is one of the coverage-EXCLUDED files (t/package.lisp). The
;;;; containment holds in one direction only -- every source file that
;;;; carries the form is on that exclude list, while every file the 100%
;;;; coverage gate measures (template, characters, eyes, bubble, wrap,
;;;; render, cli) omits it. The converse is false: src/package.lisp and
;;;; src/cli-package.lisp are excluded as well and carry no IN-PACKAGE form,
;;;; being the DEFPACKAGE files themselves. Each measured file notes the
;;;; measured half where it applies; this comment is the only place the
;;;; excluded half is recorded, so read it as the convention rather than as
;;;; an oversight worth "fixing".

(in-package #:cl-cowsay)

(defmacro define-cowsay-condition (name (slot) &body clauses)
  "Define NAME as a CL-COWSAY-ERROR carrying one SLOT, from a :REPORT-FORMAT
clause and a :DOCUMENTATION clause -- the shape every condition in
src/conditions.lisp shares. Expands to a DEFINE-CONDITION with:

  - one slot, SLOT, with initarg :SLOT and reader NAME-SLOT
  - a :REPORT lambda built from (:report-format CONTROL-STRING ARG*), where
    each ARG is either the bare symbol SLOT (read off the signaled condition
    via the generated reader) or any other form, evaluated as-is -- so a
    report can also mention data the condition itself does not carry, such
    as LIST-CHARACTERS
  - the :DOCUMENTATION string from (:documentation STRING), passed through
    verbatim

NAME-SLOT is interned into NAME's own package rather than whatever package
happens to be current at macroexpansion time, so the reader always lands
beside the condition it reads regardless of which package this macro is
called from.

CLAUSES may appear in either order; both are required."
  (check-type name symbol)
  (check-type slot symbol)
  (let* ((reader (intern (format nil "~A-~A" name slot) (symbol-package name)))
         (report-clause (assoc :report-format clauses))
         (documentation-clause (assoc :documentation clauses)))
    (assert report-clause ()
            "DEFINE-COWSAY-CONDITION ~A: missing a (:report-format ...) clause." name)
    (assert documentation-clause ()
            "DEFINE-COWSAY-CONDITION ~A: missing a (:documentation ...) clause." name)
    (destructuring-bind (control-string &rest args) (rest report-clause)
      `(define-condition ,name (cl-cowsay-error)
           ((,slot :initarg ,(intern (symbol-name slot) :keyword) :reader ,reader))
         (:report (lambda (condition stream)
                    (format stream ,control-string
                            ,@(mapcar (lambda (arg)
                                        (if (eq arg slot) `(,reader condition) arg))
                                      args))))
         (:documentation ,(second documentation-clause))))))

(defmacro defcharacter (name &body lines)
  "Register NAME -- an unevaluated symbol, downcased to its registry name --
under LINES, literal template strings top to bottom, via REGISTER-CHARACTER.
Every built-in character in src/characters-data.lisp is one DEFCHARACTER
form; LIST-CHARACTERS and WRITE-SAY see it the moment that file loads."
  (check-type name symbol)
  (dolist (line lines)
    (check-type line string))
  `(register-character ,(string-downcase (symbol-name name)) ',(copy-list lines)))

(defvar *enclosing-operation-deadlines* '()
  "Deadlines, as GET-INTERNAL-REAL-TIME values, of the WITH-OPERATION-TIMEOUT
forms currently active in this thread, innermost first.

Bound only by WITH-OPERATION-TIMEOUT's expansion, and read only by that same
expansion's handler, to answer one question a caught SB-EXT:TIMEOUT cannot
answer for itself: is an ENCLOSING deadline also expired? See that macro's
docstring for why type-based dispatch cannot answer it and why a bare
comparison against the form's own deadline cannot either.

It lives in this file, beside its only reader and writer, rather than in
src/conditions.lisp with the condition definitions. That also keeps it on
t/package.lisp's coverage-exclude list, where the macro it supports already
sits -- a DEFVAR's top-level form runs at load time, before instrumentation,
so a measured file could never account for it.")

(defmacro with-operation-timeout ((operation timeout-seconds) &body body)
  "Run BODY with a positive TIMEOUT-SECONDS wall-clock limit.

The macro translates SBCL's implementation condition into the library's
stable OPERATION-TIMEOUT condition, naming OPERATION, while INVALID-TIMEOUT
rejects zero, negative, and non-real limits before any work starts.

NESTING CONTRACT: a form reports only an expiry it OWNS, and where several
are live at once the OUTERMOST expired one owns it. These forms do nest --
%COWSAY-HANDLER opens (:CLI seconds) and then hands the same number to
WRITE-SAY as :TIMEOUT-SECONDS, which opens (:WRITE-SAY seconds) around its
own body (src/render.lisp) -- and HANDLER-CASE selects a condition by TYPE,
not by which timer signalled it. A naive inner clause therefore catches the
OUTER timer's expiry and relabels it, which is what made a --timeout that
expired during rendering report `Operation :WRITE-SAY exceeded its timeout'.
Deleting one of the deadlines is not the fix: WRITE-SAY's :TIMEOUT-SECONDS
is public library API (docs/src/reference/api.md) and must keep bounding
embedded callers who have no outer deadline at all.

Ownership is NOT decided by comparing the current time against this form's
own deadline alone. That test was measured and it fails on exactly the case
it was meant to fix. Nested deadlines built from the same number differ only
by the time it takes to get from the outer form to the inner one -- on the
CLI path about a tenth of a millisecond -- while SBCL delivers the timer
interrupt several milliseconds after the deadline it was scheduled for. By
the time the inner handler runs, its own later deadline has therefore also
passed, so it claims the expiry anyway. (Insert a 10 ms SLEEP between the
two forms and the same test starts passing, which is how the shape survives
a hand-built probe.)

So the handler asks BOTH questions: has my own deadline passed, and is there
an enclosing form whose deadline has ALSO passed? Only a form answering yes
and no signals OPERATION-TIMEOUT; every other form re-signals the SB-EXT:
TIMEOUT condition UNCHANGED and lets it travel outward. With deadlines a
fraction of a millisecond apart the inner form declines and the outer one
claims, giving :CLI. With an inner deadline genuinely shorter than a distant
outer one, the outer has not expired and the inner claims, giving
:WRITE-SAY. With no outer form at all the list is empty and the inner claims
unconditionally, which is what bounds an embedded caller.

The two questions together reduce to an invariant, which is why the result
does not depend on how long delivery took: the claimant is the form with the
EARLIEST deadline that has passed. An enclosing form always entered first, so
with equal limits its deadline is always the earlier one, and an inner form
can never claim -- (>= now inner) and (< now outer) cannot both hold when
outer < inner, at any latency. That is the difference between this and the
own-deadline-only test it replaced, which held only while the entry gap
happened to exceed the interrupt latency.

Order of evaluation inside the expansion is load-bearing and differs from
the obvious arrangement: TIMEOUT-SECONDS is validated BEFORE the deadline
arithmetic, not after. Computing (* seconds INTERNAL-TIME-UNITS-PER-SECOND)
first would make a non-real limit signal a TYPE-ERROR out of the
multiplication instead of this library's INVALID-TIMEOUT -- which
t/conditions-test.lisp asserts for the string \"1\" alongside 0 and -1.
*ENCLOSING-OPERATION-DEADLINES* is likewise captured lexically BEFORE the
HANDLER-CASE rather than read inside the handler: HANDLER-CASE unwinds to
its own frame before running a clause, so the dynamic binding established
around BODY is already gone by the time the clause needs it.

Every variable the expansion introduces is a GENSYM, including the handler's
condition variable, because OPERATION is caller-supplied and evaluated
inside that handler's scope."
  (let ((seconds-variable (gensym "SECONDS"))
        (deadline-variable (gensym "DEADLINE"))
        (enclosing-variable (gensym "ENCLOSING"))
        (now-variable (gensym "NOW"))
        (condition-variable (gensym "CONDITION")))
    `(let ((,seconds-variable ,timeout-seconds))
       (unless (and (realp ,seconds-variable) (plusp ,seconds-variable))
         (error 'invalid-timeout :seconds ,seconds-variable))
       (let ((,deadline-variable
               (+ (get-internal-real-time)
                  (* ,seconds-variable internal-time-units-per-second)))
             (,enclosing-variable *enclosing-operation-deadlines*))
         (handler-case
             (let ((*enclosing-operation-deadlines*
                     (cons ,deadline-variable ,enclosing-variable)))
               (sb-ext:with-timeout ,seconds-variable
                 (progn ,@body)))
           (sb-ext:timeout (,condition-variable)
             (let ((,now-variable (get-internal-real-time)))
               (if (and (>= ,now-variable ,deadline-variable)
                        (notany (lambda (enclosing-deadline)
                                  (>= ,now-variable enclosing-deadline))
                                ,enclosing-variable))
                   (error 'operation-timeout :operation ,operation)
                   (error ,condition-variable)))))))))
