(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retrywhen
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.operators.error-handling.retry
                ::retrycustom)
  (:export :retrywhen))

(in-package :aria.control.rx.operators.error-handling.retrywhen)

(defmethod retrywhen ((self observable) (notifier observable)))

