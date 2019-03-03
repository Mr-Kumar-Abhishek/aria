(in-package :cl-user)

(defpackage aria-test.asynchronous.timer
  (:use :cl :test-interface)
  (:import-from :aria-test
                :top)
  (:import-from :aria.asynchronous.timer
                :gen-timer
                :settimeout
                :end))

(in-package :aria-test.asynchronous.timer)

(def-suite asynchronous.timer :in top)

(in-suite asynchronous.timer)
