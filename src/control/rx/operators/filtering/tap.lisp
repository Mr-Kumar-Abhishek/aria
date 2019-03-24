(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.tap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.observer
                :next
                :fail
                :over)
  (:import-from :aria.control.rx.operators.filtering.tapnext
                :tapnext)
  (:export :tap))

(in-package :aria.control.rx.operators.filtering.tap)

(defmethod tap ((self observable) (consumer function))
  (tapnext self consumer))

(defmethod tap ((self observable) (observer observer))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value)
                                  (next observer value)
                                  (notifynext subscriber value))
                        :onfail (lambda (reason)
                                  (fail observer reason)
                                  (notifyfail subscriber reason))
                        :onover (lambda ()
                                  (over observer)
                                  (notifyover subscriber))))))
