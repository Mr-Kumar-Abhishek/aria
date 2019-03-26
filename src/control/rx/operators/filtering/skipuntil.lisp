(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.skipuntil
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :skipuntil))

(in-package :aria.control.rx.operators.filtering.skipuntil)

(defmethod skipuntil ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (unless (funcall predicate value)
                            (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod skipuntil ((self observable) (notifier observable))
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
                                         (unless notified
                                           (setf notified t)
                                           (unsubscribe inner)))
                                       :onfail (onfail subscriber)
                                       :onover (on-notifyover inner))))))
                (observer :onnext
                          (lambda (value)
                            (if notified
                                (notifynext subscriber value)))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
