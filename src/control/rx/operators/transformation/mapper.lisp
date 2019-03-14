(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.mapper
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :mapper))

(in-package :aria.control.rx.operators.transformation.mapper)

(defmethod mapper ((self observable) (function function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (notifynext subscriber (funcall function value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
