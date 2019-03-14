(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.each
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :each))

(in-package :aria.control.rx.operators.filtering.each)

(defmethod each ((self observable) (consumer function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value)
                                  (funcall consumer value)
                                  (notifynext subscriber value))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
