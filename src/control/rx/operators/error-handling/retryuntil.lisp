(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retryuntil
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :retryuntil))

(in-package :aria.control.rx.operators.error-handling.retryuntil)

(defmethod retryuntil ((self observable) (predicate function))
  (retrycustom self (lambda (subscriber retry)
                      (lambda (reason)
                        (if (funcall predicate reason)
                            (notifyfail subscriber reason)
                            (funcall retry))))))

(defmethod retrycustom ((self observable) (customsupplier function))
  (operator self
            (lambda (subscriber)
              (let* ((retry (lambda ()
                              (within-inner-subscriber
                               self
                               subscriber
                               (lambda (inner)
                                 (declare (ignorable inner))
                                 (observer :onnext (on-notifynext subscriber)
                                           :onfail (onfail subscriber)
                                           :onover (on-notifyover subscriber)))))))
                (observer :onnext (on-notifynext subscriber)
                          :onfail (funcall customsupplier subscriber retry)
                          :onover (on-notifyover subscriber))))))
