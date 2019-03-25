(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.skipwhen
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :skipwhen))

(in-package :aria.control.rx.operators.filtering.skipwhen)

(defmethod skipwhen ((self observable) (notifier observable))
  (operator self
            (lambda (subscriber)
              (let ((notify))
                (before subscriber
                        (lambda ()
                          (within-inner-subscriber
                           notifier
                           subscriber
                           (lambda (inner)
                             (observer :onnext
                                       (lambda (value)
                                         (declare (ignorable value))
                                         (unless notify
                                           (setf notify t)
                                           (unsubscribe inner)))
                                       :onfail (onfail subscriber)
                                       :onover (on-notifyover inner))))))
                (observer :onnext
                          (lambda (value)
                            (if notify
                                (notifynext subscriber value)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
