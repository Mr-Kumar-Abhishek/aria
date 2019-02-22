(in-package :cl-user)

(defpackage aria-test
  (:use :cl :fiveam)
  (:shadow :run-all-tests)
  (:export :run-all-tests
           :top))

(in-package :aria-test)

(def-suite top
    :description "all tests for Aria")

(in-suite top)

(defun run-all-tests ()
  (run! 'top))
