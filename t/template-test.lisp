
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
  (it "substitutes adjacent placeholders without separators"
    (expect (string= (cl-cowsay::fill-template-line "${thoughts}${eyes}${tongue}"
                                                     :eyes "oo" :tongue "U" :thoughts "\\")
                     "\\ooU")
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
  (it-property "substitutes all three placeholders for arbitrary non-overlapping values"
      ((eyes (gen-string :min-length 0 :max-length 6 :alphabet "abc"))
       (tongue (gen-string :min-length 0 :max-length 6 :alphabet "abc"))
       (thoughts (gen-string :min-length 0 :max-length 6 :alphabet "abc")))
    (expect (string= (cl-cowsay::fill-template-line "${thoughts}(${eyes})${tongue}"
                                                     :eyes eyes :tongue tongue
                                                     :thoughts thoughts)
                     (concatenate 'string thoughts "(" eyes ")" tongue))
            :to-be-truthy)))

(describe "%write-compiled-template-line"
  (it "matches fill-template-line for repeated placeholders"
    (let ((line "${thoughts} (${eyes}) ${eyes} ${tongue}"))
      (expect (string= (cl-cowsay::fill-template-line line :eyes "oo" :tongue "U" :thoughts "\\")
                        (with-output-to-string (stream)
                          (cl-cowsay::%write-compiled-template-line
                           (cl-cowsay::%compile-template-line line) stream "oo" "U" "\\")))
              :to-be-truthy)))

  (it "writes adjacent placeholders without literal chunks"
    (expect (string= (with-output-to-string (stream)
                       (cl-cowsay::%write-compiled-template-line
                        (cl-cowsay::%compile-template-line "${thoughts}${eyes}${tongue}")
                        stream "oo" "U" "\\"))
                     "\\ooU")
            :to-be-truthy))
  (it "writes a literal prefix before a placeholder"
    (expect (string= (with-output-to-string (stream)
                       (cl-cowsay::%write-compiled-template-line
                        (cl-cowsay::%compile-template-line "prefix${eyes}")
                        stream "oo" "U" "x"))
                     "prefixoo")
            :to-be-truthy))

  (it "rejects malformed compiled chunks"
    (signals type-error
      (with-output-to-string (stream)
        (cl-cowsay::%write-compiled-template-line '(42) stream "oo" "U" "\\")))
    (signals error
      (with-output-to-string (stream)
        (cl-cowsay::%write-compiled-template-line '(:unknown) stream "oo" "U" "\\")))))

(describe "%replace-all"
  (it-each (("aXbXc" "X" "-" "a-b-c")
            ("abc" "" "-" "abc")
            ("abc" "z" "-" "abc"))
      "replaces ~S with ~S in ~S -> ~S"
      (string old new expected)
    (expect (string= (cl-cowsay::%replace-all string old new) expected) :to-be-truthy))

  (it-property "replacing OLD with itself is always a no-op"
      ((string (gen-string :min-length 0 :max-length 40 :alphabet "abcXY"))
       (old (gen-string :min-length 1 :max-length 5 :alphabet "abcXY")))
    (expect (string= (cl-cowsay::%replace-all string old old) string) :to-be-truthy))

  (it-property "leaves STRING unchanged when OLD cannot occur in it"
      ((string (gen-string :min-length 0 :max-length 30 :alphabet "abc"))
       (old (gen-string :min-length 1 :max-length 3 :alphabet "XYZ"))
       (new (gen-string :min-length 0 :max-length 5 :alphabet "abc")))
    (expect (string= (cl-cowsay::%replace-all string old new) string) :to-be-truthy)))
