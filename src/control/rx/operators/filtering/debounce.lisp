(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.debounce
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :debounce))

(in-package :aria.control.rx.operators.filtering.debounce)

(defmethod debounce ((self observable) (observablefn function))
  "observablefn needs receive a value and return a observable"
  (operator self
            (lambda (subscriber)
              (let ((prev)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (within-inner-subscriber
                             (funcall observablefn value)
                             subscriber
                             (lambda (inner)
                               (with-caslock caslock
                                 (unsubscribe prev)
                                 (setf prev inner))
                               (observer :onnext
                                         (lambda (x)
                                           (declare (ignorable x))
                                           (notifynext subscriber value)
                                           (unsubscribe inner))
                                         :onfail (onfail subscriber)
                                         :onfail (on-notifyover inner)))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
