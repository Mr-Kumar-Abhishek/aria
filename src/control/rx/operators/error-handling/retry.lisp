(in-package :cl-user)

(defpackage aria.control.rx.operators.error-handling.retry
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :retry))

(in-package :aria.control.rx.operators.error-handling.retry)

(defmethod retry ((self observable) (number integer))
  (retrycustom self (lambda (subscriber retry)
                      (let ((count 0))
                        (lambda (reason)
                          (if (< count number)
                              (progn (incf count)
                                     (funcall retry))
                              (notifyfail subscriber reason)))))))

(defmethod retrycustom ((self observable) (customsupplier function))
  (operator self
            (lambda (subscriber)
              (let* ((retry (lambda ()
                              (within-inner-subscriber
                               self
                               subscriber
                               (lambda (inner)
                                 (declare (ignorable inner))
                                 (observer :onnext (on-notifynext subscriber)
                                           :onfail (onfail subscriber)
                                           :onover (on-notifyover subscriber)))))))
                (observer :onnext (on-notifynext subscriber)
                          :onfail (funcall customsupplier subscriber retry)
                          :onover (on-notifyover subscriber))))))
