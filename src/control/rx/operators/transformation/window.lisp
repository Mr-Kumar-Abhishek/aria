(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.window
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :window))

(in-package :aria.control.rx.operators.transformation.window)

(defmethod window ((self observable) (notifier observable))
  (operator self
            (lambda (subscriber)
              (let* ((prevob)
                     (prevnext)
                     (prevover)
                     (prev (lambda ()
                             (setf prevnext nil)
                             (if prevover (funcall prevover))
                             (setf prevover nil)
                             (setf prevob (observable
                                           (lambda (observer)
                                             (setf prevnext (lambda (value) (next observer value)))
                                             (setf prevover (lambda () (over observer)))
                                             (values)))))))
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
                                         (funcall prev)
                                         (notifynext subscriber prevob))
                                       :onfail (onfail subscriber)
                                       :onover (onover subscriber))))))
                (observer :onnext
                          (lambda (value)
                            (unless prevob
                              (funcall prev)
                              (notifynext subscriber prevob))
                            (if prevnext
                                (funcall prevnext value)))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (if prevover (funcall prevover))
                            (notifyover subscriber)))))))
