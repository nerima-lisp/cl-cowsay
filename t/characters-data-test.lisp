;;;; t/characters-data-test.lisp
;;;;
;;;; src/characters-data.lisp is DATA only (see its own header comment), so
;;;; unlike every other src/ file it has no LOGIC of its own to exercise;
;;;; this file instead pins down that every character it defines actually
;;;; made it into the registry under its own name, so a typo in a
;;;; DEFCHARACTER name silently shrinking LIST-CHARACTERS by one would fail
;;;; a test instead of going unnoticed.

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
    (expect (every (lambda (name) (stringp (say "hi" :character name)))
                   *non-original-four-characters*)
            :to-be-truthy)))
