(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retrywhile
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retry
                ::retrycustom)
  (:export :retrywhile))

(in-package :aria.control.rx.operators.error-handling.retrywhile)

(defmethod retrywhile ((self observable) (predicate function))
  (retrycustom self (lambda (subscriber retry)
                      (lambda (reason)
                        (if (funcall predicate reason)
                            (funcall retry)
                            (notifyfail subscriber reason))))))
