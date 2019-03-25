(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retrywhen
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retry
                ::retrycustom)
  (:export :retrywhen))

(in-package :aria.control.rx.operators.error-handling.retrywhen)

(defmethod retrywhen ((self observable) (notifier observable))
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

