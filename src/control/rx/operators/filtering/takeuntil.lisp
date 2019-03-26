(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.takeuntil
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :takeuntil))

(in-package :aria.control.rx.operators.filtering.takeuntil)

(defmethod takeuntil ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (if (funcall predicate value)
                              (notifyover subscriber)
                              (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod takeuntil ((self observable) (notifier observable))
  (operator self
            (lambda (subscriber)
              (let ((notified))
                (before subscriber
                        (lambda ()
                          (within-inner-subscriber
                           notifier
                           subscriber
                           (lambda (inner)
                             (observer :onnext
                                       (lambda (value)
                                         (declare (ignorable value))
                                         (setf notified t)
                                         (unsubscribe inner)))))))
                (observer :onnext
                          (lambda (value)
                            (if notified
                                (notifyover subscriber)
                                (notifynext subscriber value)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
