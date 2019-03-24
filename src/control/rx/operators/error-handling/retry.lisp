(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retry
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retryuntil
                ::retrycustom)
  (:export :retry))

(in-package :aria.control.rx.operators.error-handling.retry)

(defmethod retry ((self observable) (number integer))
  (retrycustom self (lambda (subscriber retry)
                      (let ((count 0))
                        (lambda (reason)
                          (if (< count number)
                              (progn (incf count)
                                     (funcall retry))
                              (notifyfail subscriber reason)))))))
