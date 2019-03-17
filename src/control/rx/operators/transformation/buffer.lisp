(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.buffer
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :buffer))

(in-package :aria.control.rx.operators.transformation.buffer)

(defmethod buffer ((self observable) (notifier observable))
  (operator self
            (lambda (subscriber)
              (let ((buffer)
                    (caslock (caslock)))
                (before subscriber
                        (lambda ()
                          (within-inner-subscriber
                           notifier
                           subscriber
                           (lambda (inner)
                             (declare (ignorable inner))
                             (observer :onnext
                                       (lambda (value)
                                         (declare (ignorable value))
                                         (let ((copy))
                                           (with-caslock caslock
                                             (setf copy (reverse buffer))
                                             (setf buffer nil))
                                           (notifynext subscriber copy)))
                                       :onfail (onfail subscriber)
                                       :onover (onover subscriber))))))
                (observer :onnext
                          (lambda (value)
                            (with-caslock caslock
                              (push value buffer)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
