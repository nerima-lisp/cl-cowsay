;;;; t/conditions-test.lisp
;;;;
;;;; CHECK-COWSAY-CONDITION factors out the one shape every condition below
;;;; shares -- it derives from CL-COWSAY-ERROR, its reader reads back the
;;;; value it was constructed with, and its :REPORT text mentions every
;;;; expected substring -- the same way DEFINE-COWSAY-CONDITION
;;;; (src/macros.lisp) factors out the shape those conditions' own
;;;; definitions share. CL-COWSAY-ERROR itself has no slot and no reader, so
;;;; it gets its own one-off DESCRIBE below instead.

(in-package #:cl-cowsay/test)

(defmacro check-cowsay-condition (name (initarg value) reader &rest report-substrings)
  "Register a DESCRIBE block named after NAME with the three checks every
CL-COWSAY condition shares: it derives from CL-COWSAY-ERROR, READER reads
back the VALUE a (MAKE-CONDITION NAME INITARG VALUE) was constructed with,
and its :REPORT text mentions every string in REPORT-SUBSTRINGS. NAME,
INITARG, and READER are unevaluated symbols; VALUE and REPORT-SUBSTRINGS are
evaluated."
  `(describe ,(string-downcase (symbol-name name))
     (it "is a cl-cowsay-error"
       (expect (typep (make-condition ',name ,initarg ,value) 'cl-cowsay-error)
               :to-be-truthy))

     (it ,(format nil "exposes the value via ~(~A~)" reader)
       (expect (equal (,reader (make-condition ',name ,initarg ,value)) ,value)
               :to-be-truthy))

     (it "reports every expected substring"
       (let ((text (princ-to-string (make-condition ',name ,initarg ,value))))
         (with-soft-assertions
           ,@(mapcar (lambda (substring) `(expect (search ,substring text) :to-be-truthy))
                     report-substrings))))))

(describe "cl-cowsay-error"
  (it "reports a generic message when signaled directly"
    (expect (search "cl-cowsay" (princ-to-string (make-condition 'cl-cowsay-error)))
            :to-be-truthy)))

(check-cowsay-condition unknown-character (:name "nope") unknown-character-name
  "nope" "cow")

(check-cowsay-condition unknown-eyes-preset (:name "nope") unknown-eyes-preset-name
  "nope" "borg")

(check-cowsay-condition invalid-message (:width 0) invalid-message-width
  "0")

(check-cowsay-condition stdin-too-large (:limit 65536) stdin-too-large-limit
  "65536")
