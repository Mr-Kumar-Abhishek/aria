(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.thrown
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :thrown))

(in-package :aria.control.rx.operators.creation.thrown)

(defmethod thrown (reason)
  (observable (lambda (observer) (fail observer reason))))
