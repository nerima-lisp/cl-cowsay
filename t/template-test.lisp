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
            :to-be-truthy))

  ;; Values drawn only from "abc" can never contain "${", so none of them
  ;; can accidentally complete a placeholder token FILL-TEMPLATE-LINE has
  ;; not substituted yet; the result is exactly the template with each slot
  ;; replaced, for any generated combination.
  (it-property "substitutes all three placeholders for arbitrary non-overlapping values"
      ((eyes (gen-string :min-length 0 :max-length 6 :alphabet "abc"))
       (tongue (gen-string :min-length 0 :max-length 6 :alphabet "abc"))
       (thoughts (gen-string :min-length 0 :max-length 6 :alphabet "abc")))
    (expect (string= (cl-cowsay::fill-template-line "${thoughts}(${eyes})${tongue}"
                                                     :eyes eyes :tongue tongue
                                                     :thoughts thoughts)
                     (concatenate 'string thoughts "(" eyes ")" tongue))
            :to-be-truthy)))

(describe "%replace-all"
  ;; The empty-OLD row is the one worth calling out on its own: an empty
  ;; search string would match at every position and never advance,
  ;; looping forever, so %REPLACE-ALL treats it as a no-op instead of
  ;; scanning. The "does not occur" row is the ordinary early-exit case.
  (it-each (("aXbXc" "X" "-" "a-b-c")
            ("abc" "" "-" "abc")
            ("abc" "z" "-" "abc"))
      "replaces ~S with ~S in ~S -> ~S"
      (string old new expected)
    (expect (string= (cl-cowsay::%replace-all string old new) expected) :to-be-truthy))

  ;; Two generated-input properties, each avoiding the one subtlety a
  ;; single left-to-right non-overlapping scan has: replacing "ab" with ""
  ;; in "aabb" leaves "a"+"b", which happens to spell "ab" again. Disjoint
  ;; alphabets between STRING and OLD/NEW below sidestep that case entirely
  ;; rather than asserting something only sometimes true.
  (it-property "replacing OLD with itself is always a no-op"
      ((string (gen-string :min-length 0 :max-length 40 :alphabet "abcXY"))
       (old (gen-string :min-length 1 :max-length 5 :alphabet "abcXY")))
    (expect (string= (cl-cowsay::%replace-all string old old) string) :to-be-truthy))

  (it-property "leaves STRING unchanged when OLD cannot occur in it"
      ((string (gen-string :min-length 0 :max-length 30 :alphabet "abc"))
       (old (gen-string :min-length 1 :max-length 3 :alphabet "XYZ"))
       (new (gen-string :min-length 0 :max-length 5 :alphabet "abc")))
    (expect (string= (cl-cowsay::%replace-all string old new) string) :to-be-truthy)))
