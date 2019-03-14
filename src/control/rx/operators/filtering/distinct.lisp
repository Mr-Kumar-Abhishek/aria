(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.distinct
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :distinct))

(in-package :aria.control.rx.operators.filtering.distinct)

(defmethod distinct ((self observable) &optional (compare #'eq))
  "distinct won't send value to next until it change
   compare receive two value and return boolean, use eq as default compare method"
  (operator self
            (lambda (subscriber)
              (let ((last)
                    (init t))
                (observer :onnext
                          (lambda (value)
                            (if init
                                (progn (setf init nil)
                                       (setf last value)
                                       (notifynext subscriber value))
                                (unless (funcall compare last value)
                                  (setf last value)
                                  (notifynext subscriber value))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
