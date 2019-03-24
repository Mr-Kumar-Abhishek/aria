(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.tapnext
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :tapnext))

(in-package :aria.control.rx.operators.filtering.tapnext)

(defmethod tapnext ((self observable) (consumer function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value)
                                  (funcall consumer value)
                                  (notifynext subscriber value))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
