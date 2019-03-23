(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.reducer
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :reducer))

(in-package :aria.control.rx.operators.transformation.reducer)

(defmethod reducer ((self observable) (function function) initial-value)
  (operator self
            (lambda (subscriber)
              (let ((acc initial-value)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (with-caslock caslock
                              (setf acc (funcall function acc value))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (notifynext subscriber (with-caslock caslock acc))
                            (notifyover subscriber)))))))
