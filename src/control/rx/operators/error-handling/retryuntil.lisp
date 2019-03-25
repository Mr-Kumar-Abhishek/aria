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
