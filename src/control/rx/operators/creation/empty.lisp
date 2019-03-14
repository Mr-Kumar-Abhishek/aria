(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.empty
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :empty))

(in-package :aria.control.rx.operators.creation.empty)

(defmethod empty ()
  (observable (lambda (observer) (over observer))))
