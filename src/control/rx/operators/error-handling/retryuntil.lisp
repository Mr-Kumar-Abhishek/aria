(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retryuntil
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retry
                ::retrycustom)
  (:export :retryuntil))

(in-package :aria.control.rx.operators.error-handling.retryuntil)

(defmethod retryuntil ((self observable) (predicate function))
  (retrycustom self (lambda (subscriber retry)
                      (lambda (reason)
                        (if (funcall predicate reason)
                            (notifyfail subscriber reason)
                            (funcall retry))))))

(defmethod retryuntil ((self observable) (notifier observable))
  (retrycustom self (lambda (subscriber retry)
                      (let ((notified))
                        (before subscriber
                                (lambda ()
                                  (within-inner-subscriber
                                   notifier
                                   subscriber
                                   (lambda (inner)
                                     (observer :onnext
                                               (lambda (value)
                                                 (setf notified t)
                                                 (notifynext inner value))
                                               :onfail (on-notifyfail subscriber)
                                               :onover (on-notifyover inner))))))
                        (lambda (reason)
                          (if notified
                              (notifyfail subscriber reason)
                              (funcall retry)))))))
