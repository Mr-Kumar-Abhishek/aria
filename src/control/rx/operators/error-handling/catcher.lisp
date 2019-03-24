(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.catcher
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :catcher))

(in-package :aria.control.rx.operators.error-handling.catcher)

(defmethod catcher ((self observable) (observablefn function))
  (operator self
            (lambda (subscriber)
              (let ((prev)
                    (caslock (caslock)))
                (observer :onnext (on-notifynext subscriber)
                          :onfail
                          (lambda (reason)
                            (within-inner-subscriber
                             (funcall observablefn reason)
                             subscriber
                             (lambda (inner)
                               (with-caslock caslock
                                 (unsubscribe prev)
                                 (setf prev inner))
                               (observer :onnext (on-notifynext subscriber)
                                         :onfail (on-notifyfail subscriber)
                                         :onover (on-notifyover subscriber)))))
                          :onover (on-notifyover subscriber))))))
