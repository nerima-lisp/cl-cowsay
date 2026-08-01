;;;; t/cli-test.lisp

(in-package #:cl-cowsay/test)

(describe "the cl-cowsay app spec: flag parsing round-trips"
  (it "collects positional words under :message"
    (let ((invocation (parse-argv (make-cowsay-app) '("cl-cowsay" "hello" "world"))))
      (expect (equal (positional-value invocation :message) '("hello" "world"))
              :to-be-truthy)))

  (it "defaults :character to \"cow\" when --character is not given"
    (let ((invocation (parse-argv (make-cowsay-app) '("cl-cowsay" "hi"))))
      (expect (string= (option-value invocation :character) "cow") :to-be-truthy)))

  (it "parses --character/-c"
    (let ((invocation (parse-argv (make-cowsay-app) '("cl-cowsay" "-c" "cat" "hi"))))
      (expect (string= (option-value invocation :character) "cat") :to-be-truthy)))

  (it "defaults :width to 40 and parses --width/-w as an integer"
    (with-soft-assertions
      (expect (= (option-value (parse-argv (make-cowsay-app) '("cl-cowsay" "hi")) :width) 40)
              :to-be-truthy)
      (expect (= (option-value (parse-argv (make-cowsay-app) '("cl-cowsay" "-w" "10" "hi"))
                               :width)
                 10)
              :to-be-truthy)))

  (it "parses --think/-T as a flag, defaulting to false"
    (with-soft-assertions
      (expect (not (option-value (parse-argv (make-cowsay-app) '("cl-cowsay" "hi")) :think))
              :to-be-truthy)
      (expect (option-value (parse-argv (make-cowsay-app) '("cl-cowsay" "-T" "hi")) :think)
              :to-be-truthy)))

  (it "parses --eyes and --tongue overrides"
    (let ((invocation (parse-argv (make-cowsay-app)
                                  '("cl-cowsay" "--eyes" "^^" "--tongue" "U" "hi"))))
      (with-soft-assertions
        (expect (string= (option-value invocation :eyes) "^^") :to-be-truthy)
        (expect (string= (option-value invocation :tongue) "U") :to-be-truthy))))

  (it "rejects an unknown --character value"
    (expect (signals (parse-argv (make-cowsay-app) '("cl-cowsay" "-c" "not-a-character" "hi"))
                     'cli-invalid-option-value)
            :to-be-truthy)))

(describe "the cl-cowsay app spec: end-to-end run-app"
  (it "prints a rendered bubble for a positional message and exits 0"
    (let* ((output (with-output-to-string (out)
                     (expect (= (run-app (make-cowsay-app)
                                        :argv '("cl-cowsay" "hello" "world")
                                        :stdout out)
                               0)
                             :to-be-truthy))))
      (with-soft-assertions
        (expect (search "hello world" output) :to-be-truthy)
        (expect (find #\| output) :to-be-truthy))))

  (it "reads the message from standard input when no positional words are given"
    (let ((output (with-output-to-string (out)
                    (with-input-from-string (*standard-input* "piped in")
                      (run-app (make-cowsay-app) :argv '("cl-cowsay") :stdout out)))))
      (expect (search "piped in" output) :to-be-truthy)))

  (it "draws a \":\"-sided bubble when --think is given"
    (let ((output (with-output-to-string (out)
                    (run-app (make-cowsay-app) :argv '("cl-cowsay" "-T" "hi") :stdout out))))
      (expect (find #\: output) :to-be-truthy)))

  (it "exits 0 on --help without invoking the message handler"
    (let ((output (with-output-to-string (out)
                    (expect (= (run-app (make-cowsay-app) :argv '("cl-cowsay" "--help")
                                       :stdout out)
                              0)
                            :to-be-truthy))))
      (expect (search "cl-cowsay" output) :to-be-truthy)))

  (it "exits 0 on --version and prints the app's version"
    (let ((output (with-output-to-string (out)
                    (expect (= (run-app (make-cowsay-app) :argv '("cl-cowsay" "--version")
                                       :stdout out)
                              0)
                            :to-be-truthy))))
      (expect (search "cl-cowsay" output) :to-be-truthy))))
