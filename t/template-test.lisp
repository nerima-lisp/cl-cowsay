;;;; t/template-test.lisp
;;;;
;;;; FILL-TEMPLATE-LINE and %REPLACE-ALL are internal (src/template.lisp),
;;;; accessed here via CL-COWSAY:: -- they are not part of the public API,
;;;; but the substitution scheme is exactly what every built-in character
;;;; relies on, so it gets its own direct coverage.

(in-package #:cl-cowsay/test)

(describe "fill-template-line"
  (it "substitutes ${eyes}, ${tongue}, and ${thoughts} independently"
    (with-soft-assertions
      (expect (string= (cl-cowsay::fill-template-line "(${eyes})" :eyes "^^")
                       "(^^)")
              :to-be-truthy)
      (expect (string= (cl-cowsay::fill-template-line "(__${tongue})" :tongue "U")
                       "(__U)")
              :to-be-truthy)
      (expect (string= (cl-cowsay::fill-template-line "${thoughts} hi" :thoughts "o")
                       "o hi")
              :to-be-truthy)))

  (it "substitutes every placeholder at once when a line contains all three"
    (expect (string= (cl-cowsay::fill-template-line "${thoughts}(${eyes})${tongue}"
                                                     :eyes "oo" :tongue "U" :thoughts "\\")
                     "\\(oo)U")
            :to-be-truthy))

  (it "defaults every placeholder to the empty string when unsupplied"
    (expect (string= (cl-cowsay::fill-template-line "[${eyes}|${tongue}|${thoughts}]")
                     "[||]")
            :to-be-truthy))

  (it "leaves a line with no placeholders unchanged"
    (expect (string= (cl-cowsay::fill-template-line "plain text, no slots")
                     "plain text, no slots")
            :to-be-truthy))

  (it "substitutes a repeated placeholder at every occurrence"
    (expect (string= (cl-cowsay::fill-template-line "${eyes}-${eyes}" :eyes "x")
                     "x-x")
            :to-be-truthy)))

(describe "%replace-all"
  (it "replaces every non-overlapping occurrence of a non-empty OLD"
    (expect (string= (cl-cowsay::%replace-all "aXbXc" "X" "-") "a-b-c")
            :to-be-truthy))

  (it "returns STRING unchanged when OLD is empty, rather than looping forever"
    (expect (string= (cl-cowsay::%replace-all "abc" "" "-") "abc")
            :to-be-truthy))

  (it "returns STRING unchanged when OLD does not occur"
    (expect (string= (cl-cowsay::%replace-all "abc" "z" "-") "abc")
            :to-be-truthy)))
