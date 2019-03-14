(in-package :cl-user)

(defpackage aria.control.rx.util.subscribe
  (:use :cl)
  (:import-from :aria.control.rx.inner-subscriber
                :unsubscribe)
  (:import-from :aria.control.rx.outer-subscriber
                :subscribe)
  (:import-from :aria.control.rx.subject
                :subscribe)
  (:import-from :aria.control.rx.subscriber
                :unsubscribe
                :isunsubscribed)
  (:export :subscribe
           :unsubscribe
           :isunsubscribed))

(in-package :aria.control.rx.util.subscribe)

(defmethod unsubscribe (self)
  (declare (ignorable self)))
