(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.of
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :of))

(in-package :aria.control.rx.operators.creation.of)

(defmethod of (&rest rest)
  (observable (lambda (observer)
                (loop for x in rest do (next observer x))
                (over observer))))
