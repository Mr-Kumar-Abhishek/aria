(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.skipuntil
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :skipuntil))

(in-package :aria.control.rx.operators.filtering.skipuntil)

(defmethod skipuntil ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (unless (funcall predicate value)
                            (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))
