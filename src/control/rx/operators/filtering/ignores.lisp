(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.ignores
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :ignores))

(in-package :aria.control.rx.operators.filtering.ignores)

(defmethod ignores ((self observable))
  "ignore all values from next, only receive fail and over"
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (declare (ignorable value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
