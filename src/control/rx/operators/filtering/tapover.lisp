(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.tapover
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :tapover))

(in-package :aria.control.rx.operators.filtering.tapover)

(defmethod tapover ((self observable) (consumer function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (on-notifynext subscriber)
                        :onfail (on-notifyfail subscriber)
                        :onover
                        (lambda ()
                          (funcall consumer)
                          (notifyover subscriber))))))
