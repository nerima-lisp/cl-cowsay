
(in-package #:cl-cowsay/test)

(describe "list-characters"
  (it "includes the default \"cow\" character"
    (expect (member "cow" (list-characters) :test #'string=) :to-be-truthy))

  (it "lists at least twenty built-in characters"
    (expect (>= (length (list-characters)) 20) :to-be-truthy))

  (it "returns names sorted alphabetically"
    (expect (equal (list-characters) (sort (copy-list (list-characters)) #'string<))
            :to-be-truthy)))

(describe "character-known-p"
  (it "is true for every name LIST-CHARACTERS returns"
    (expect (every #'character-known-p (list-characters)) :to-be-truthy))

  (it "is case-insensitive"
    (expect (character-known-p "CoW") :to-be-truthy))

  (it "is false for an unregistered name"
    (expect (not (character-known-p "definitely-not-a-character")) :to-be-truthy)))

(describe "find-character-template"
  (it "resolves a known name case-insensitively"
    (expect (string= (cl-cowsay::character-template-name
                      (cl-cowsay::find-character-template "COW"))
                     "cow")
            :to-be-truthy))

  (it "signals unknown-character for an unregistered name"
    (signals unknown-character
        (cl-cowsay::find-character-template "not-a-real-character"))))

(describe "every built-in character's art"
  (it "has at least one non-empty line for every registered character"
    (expect (every (lambda (name)
                     (some (lambda (line) (plusp (length line)))
                           (cl-cowsay::character-template-lines
                            (cl-cowsay::find-character-template name))))
                   (list-characters))
            :to-be-truthy))
  (it "can render a message with every registered character"
    (expect (every (lambda (name)
                     (let ((output (render-to-string "hello" :character name)))
                       (and (stringp output)
                            (plusp (length output)))))
                   (list-characters))
            :to-be-truthy))

  (it "references the ${eyes} placeholder somewhere in every character"
    (expect (every (lambda (name)
                     (some (lambda (line) (search "${eyes}" line))
                           (cl-cowsay::character-template-lines
                            (cl-cowsay::find-character-template name))))
                   (list-characters))
            :to-be-truthy)))
