(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.mapto
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :mapto))

(in-package :aria.control.rx.operators.transformation.mapto)

(defmethod mapto ((self observable) value)
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (x) (declare (ignorable x)) (notifynext subscriber value))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
