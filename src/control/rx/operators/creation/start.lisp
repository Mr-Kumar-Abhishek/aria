(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.start
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :start))

(in-package :aria.control.rx.operators.creation.start)

(defmethod start ((supplier function))
  (observable (lambda (observer)
                (next observer (funcall supplier))
                (over observer))))
