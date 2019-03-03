(in-package :cl-user)

(defpackage test-interface
  (:use :fiveam)
  (:export :def-suite
           :in-suite
           :test
           :is))

(in-package :test-interface)
