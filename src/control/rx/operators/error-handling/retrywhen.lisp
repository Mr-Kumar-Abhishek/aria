(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retrywhen
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retry
                ::retrycustom)
  (:export :retrywhen))

(in-package :aria.control.rx.operators.error-handling.retrywhen)

(defmethod retrywhen ((self observable) (observablefn function))
  "observablefn receive a observable and need return a observable"
  (retrycustom self (lambda (subscriber retry)
                      (lambda (reason)
                        (within-inner-subscriber
                         (funcall observablefn (observable
                                                (lambda (observer)
                                                  (next observer reason))))
                         subscriber
                         (lambda (inner)
                           (declare (ignorable inner))
                           (observer :onnext
                                     (lambda (value)
                                       (declare (ignorable value))
                                       (funcall retry))
                                     :onfail (on-notifyfail subscriber)
                                     :onover (on-notifyover subscriber))))))))

