(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.takewhile
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :takewhile))

(in-package :aria.control.rx.operators.filtering.takewhile)

(defmethod takewhile ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (if (funcall predicate value)
                              (notifynext subscriber value)
                              (notifyover subscriber)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
