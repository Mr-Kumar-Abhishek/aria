(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.sample
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :sample))

(in-package :aria.control.rx.operators.filtering.sample)

(defmethod sample ((self observable) (sampler observable))
  (operator self
            (lambda (subscriber)
              (let ((last)
                    (hasvalue))
                (after subscriber
                       (lambda ()
                         (within-inner-subscriber
                          sampler
                          subscriber
                          (lambda (inner)
                            (declare (ignorable inner))
                            (observer :onnext (lambda (x)
                                                (declare (ignorable x))
                                                (if hasvalue
                                                    (notifynext subscriber last)))
                                      :onfail (on-notifyfail subscriber)
                                      :onover (on-notifyover subscriber))))))
                (observer :onnext
                          (lambda (value)
                            (setf last value)
                            (unless hasvalue
                              (setf hasvalue t)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
