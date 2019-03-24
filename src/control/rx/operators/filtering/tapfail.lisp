(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.tapfail
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :tapfail))

(in-package :aria.control.rx.operators.filtering.tapfail)

(defmethod tapfail ((self observable) (consumer function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (on-notifynext subscriber)
                        :onfail
                        (lambda (reason)
                          (funcall consumer reason)
                          (notifyfail subscriber reason))
                        :onover (on-notifyover subscriber)))))
