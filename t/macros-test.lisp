;;;; t/macros-test.lisp

(in-package #:cl-cowsay/test)

(describe "define-cowsay-condition"
  (it "signals at macroexpansion time when the :report-format clause is missing"
    (signals error
        (macroexpand-1 '(cl-cowsay::define-cowsay-condition %macros-test-condition (x)
                          (:documentation "test-only condition")))))

  (it "signals at macroexpansion time when the :documentation clause is missing"
    (signals error
        (macroexpand-1 '(cl-cowsay::define-cowsay-condition %macros-test-condition (x)
                          (:report-format "~S" x)))))

  (it "accepts :report-format and :documentation in either order"
    (with-soft-assertions
      (expect (macroexpand-1 '(cl-cowsay::define-cowsay-condition %macros-test-condition (x)
                               (:report-format "~S" x)
                               (:documentation "test-only condition")))
              :to-be-truthy)
      (expect (macroexpand-1 '(cl-cowsay::define-cowsay-condition %macros-test-condition (x)
                               (:documentation "test-only condition")
                               (:report-format "~S" x)))
              :to-be-truthy))))

(describe "defcharacter"
  ;; Registers a throwaway character under a name no built-in uses. The
  ;; ${eyes} placeholder is included on purpose: LIST-CHARACTERS is a single
  ;; shared registry across the whole test run, so t/characters-test.lisp's
  ;; "every character references ${eyes}" case would otherwise fail against
  ;; this one too.
  (it "registers the character under the downcased symbol name"
    (cl-cowsay::defcharacter %macros-test-char "(${eyes})" "second line")
    (with-soft-assertions
      (expect (character-known-p "%macros-test-char") :to-be-truthy)
      (expect (equal (cl-cowsay::character-template-lines
                      (cl-cowsay::find-character-template "%macros-test-char"))
                     '("(${eyes})" "second line"))
              :to-be-truthy)))

  (it "rejects a non-symbol name during macroexpansion"
    (signals type-error
      (macroexpand-1 '(cl-cowsay::defcharacter "not-a-symbol" "line"))))
  (it "compiles a literal prefix before a thoughts placeholder"
    (cl-cowsay::defcharacter %macros-test-thoughts-prefix
      "prefix${thoughts}" "(${eyes})")
    (expect (search "prefix\\"
                    (render-to-string "hi"
                                     :character "%macros-test-thoughts-prefix"))
            :to-be-truthy))

  (it "rejects a non-string template line during macroexpansion"
    (signals type-error
      (macroexpand-1 '(cl-cowsay::defcharacter %macros-test-invalid 42)))))
