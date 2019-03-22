(in-package :cl-user)

(defpackage aria.control.rx.util.subscribe
  (:use :cl)
  (:import-from :aria.control.rx.outer-subscriber
                :subscribe
                :unsubscribe)
  (:import-from :aria.control.rx.subject
                :subscribe)
  (:import-from :aria.control.rx.subscriber
                :isunsubscribed)
  (:export :subscribe
           :unsubscribe
           :isunsubscribed))

(in-package :aria.control.rx.util.subscribe)
