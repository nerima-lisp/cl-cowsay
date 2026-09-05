(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(defun configure-local-source-registry (root)
  (asdf:initialize-source-registry
   `(:source-registry
     (:tree ,root)
     :inherit-configuration)))

(defun quit-with (code)
  "Flush standard streams, then exit through HOST-KIT:QUIT with CODE."
  (finish-output *standard-output*)
  (finish-output *error-output*)
  (let* ((package (or (find-package "HOST-KIT")
                      (error "HOST-KIT is unavailable: cl-host-kit did not load.")))
         (quit (or (find-symbol "QUIT" package)
                   (error "HOST-KIT does not provide QUIT."))))
    (funcall quit code)))

(let ((root (script-directory)))
  (configure-local-source-registry root)
  (handler-case (asdf:test-system "cl-cowsay")
    (error (condition)
      (format *error-output* "~&cl-cowsay tests failed: ~A~%" condition)
      (quit-with 1)))
  (quit-with 0))
