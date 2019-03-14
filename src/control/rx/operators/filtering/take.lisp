(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.take
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock)
  (:export :take))

(in-package :aria.control.rx.operators.filtering.take)

(defmethod take ((self observable) (count integer))
  (operator self
   (lambda (subscriber)
     (let ((takes 0)
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (with-caslock caslock
                     (if (< takes count)
                         (progn (notifynext subscriber value)
                                (incf takes)
                                (unless (< takes count)
                                  (notifyover subscriber)))
                         (notifyover subscriber))))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))
