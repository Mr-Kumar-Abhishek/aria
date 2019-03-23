(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.scan
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :scan))

(in-package :aria.control.rx.operators.transformation.scan)

(defmethod scan ((self observable) (function function) initial-value)
  (operator self
            (lambda (subscriber)
              (let ((acc initial-value)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (let ((val))
                              (with-caslock caslock
                                (setf acc (funcall function acc value))
                                (setf val acc))
                              (notifynext subscriber val)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
