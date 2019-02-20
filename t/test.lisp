(in-package :cl-user)

(defpackage aria-test
  (:use :cl)
  (:export :run-all-tests))

(in-package :aria-test)

(defun run-all-tests ()
  (print "no test runs"))
