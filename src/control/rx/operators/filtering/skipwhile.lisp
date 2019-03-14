(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.skipwhile
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :skipwhile))

(in-package :aria.control.rx.operators.filtering.skipwhile)

(defmethod skipwhile ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (if (funcall predicate value)
                              (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
