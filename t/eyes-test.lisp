
(in-package #:cl-cowsay/test)

(describe "list-eye-presets"
  (it "includes every classic cowsay eyes preset"
    (expect (every (lambda (name) (member name (list-eye-presets) :test #'string=))
                   '("borg" "dead" "greedy" "paranoid" "stoned" "tired" "wired" "youthful"))
            :to-be-truthy)))

(describe "eyes-preset-string"
  (it "resolves every name from list-eye-presets to a non-empty string"
    (expect (every (lambda (name) (plusp (length (eyes-preset-string name))))
                   (list-eye-presets))
            :to-be-truthy))

  (it "is case-insensitive"
    (expect (string= (eyes-preset-string "BORG") (eyes-preset-string "borg"))
            :to-be-truthy))

  (it "resolves \"borg\" to \"==\""
    (expect (string= (eyes-preset-string "borg") "==") :to-be-truthy))

  (it "signals unknown-eyes-preset for an unregistered name"
    (signals unknown-eyes-preset (eyes-preset-string "not-a-real-preset"))))
