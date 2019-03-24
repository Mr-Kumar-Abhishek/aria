(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.catcher
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :catcher))

(in-package :aria.control.rx.operators.error-handling.catcher)

(defmethod catcher ((self observable) (observablefn function))
  (operator self
            (lambda (subscriber)
              (let ((prev))
                (observer :onnext (on-notifynext subscriber)
                          :onfail
                          (lambda (reason)
                            (if prev
                                (unsubscribe prev))
                            (setf prev (within-inner-subscriber
                                        (funcall observablefn reason)
                                        subscriber
                                        (lambda (inner)
                                          (declare (ignorable inner))
                                          (observer :onnext (on-notifynext subscriber)
                                                    :onfail (on-notifyfail subscriber)
                                                    :onover (on-notifyover subscriber))))))
                          :onover (on-notifyover subscriber))))))
