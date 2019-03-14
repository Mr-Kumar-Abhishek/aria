(in-package :cl-user)

(defpackage aria.control.rx.operators.creation.from
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :from))

(in-package :aria.control.rx.operators.creation.from)

(defmethod from ((seq sequence))
  (observable (lambda (observer)
                (map nil (lambda (x) (next observer x)) seq)
                (over observer))))
