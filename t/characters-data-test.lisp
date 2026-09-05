
(in-package #:cl-cowsay/test)

(defparameter *non-original-four-characters*
  '("dragon" "penguin" "fox" "owl" "bear" "rabbit" "mouse" "snake" "alien"
    "koala" "tiger" "lion" "panda" "dog" "wolf" "turtle" "frog" "hedgehog"
    "squirrel" "bat" "unicorn" "octopus" "crab" "bee" "skull")
  "Every character src/characters-data.lisp defines beyond the original
four (cow, cat, robot, ghost), by name.")

(describe "every character defined in src/characters-data.lisp"
  (it "is registered under its own name"
    (expect (every #'character-known-p *non-original-four-characters*)
            :to-be-truthy))

  (it "renders without error for every one of them"
    (expect (every (lambda (name) (stringp (render-to-string "hi" :character name)))
                   *non-original-four-characters*)
            :to-be-truthy))
    (it "applies public face and message overrides to every one of them"
    (with-soft-assertions
      (dolist (name *non-original-four-characters*)
        (let ((output (render-to-string "hello" :character name
                           :eyes "^^" :tongue "U")))
          (expect (search "hello" output) :to-be-truthy)
          (expect (search "^^" output) :to-be-truthy)
          (expect (search "U" output) :to-be-truthy))))))
