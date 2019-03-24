(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.take
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :take))

(in-package :aria.control.rx.operators.filtering.take)

(defmethod take ((self observable) (count integer))
  (operator self
            (lambda (subscriber)
              (let ((takes 0)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (let ((neednext)
                                  (needover))
                              (with-caslock caslock
                                (if (< takes count)
                                    (progn (setf neednext t)
                                           (incf takes)
                                           (unless (< takes count)
                                             (setf needover t)))
                                    (setf needover t)))
                              (if neednext (notifynext subscriber value))
                              (if needover (notifyover subscriber))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
