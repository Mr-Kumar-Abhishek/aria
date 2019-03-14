(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.range
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :range))

(in-package :aria.control.rx.operators.creation.range)

(defmethod range ((start integer) (count integer))
  (observable (lambda (observer)
                (loop for x from start to (+ start count -1) do (next observer x))
                (over observer))))
