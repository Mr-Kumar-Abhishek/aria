(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.throttle
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :throttle))

(in-package :aria.control.rx.operators.filtering.throttle)

(defmethod throttle ((self observable) (observablefn function))
  "observablefn needs receive a value and return a observable"
  (operator self
   (lambda (subscriber)
     (let ((disable))
       (observer :onnext
                 (lambda (value)
                   (unless disable
                     (setf disable t)
                     (notifynext subscriber value)
                     (within-inner-subscriber
                      (funcall observablefn value)
                      subscriber
                      (lambda (inner)
                        (observer :onnext
                                  (lambda (x)
                                    (declare (ignorable x))
                                    (setf disable nil)
                                    (unsubscribe inner))
                                  :onfail (onfail subscriber)
                                  :onover (on-notifyover inner))))))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))
