(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.skip
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock)
  (:export :skip))

(in-package :aria.control.rx.operators.filtering.skip)

(defmethod skip ((self observable) (integer integer))
  (operator self
            (lambda (subscriber)
              (let ((count 0)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (with-caslock caslock
                              (if (< count integer)
                                  (incf count)
                                  (notifynext subscriber value))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
