(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.window
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :window))

(in-package :aria.control.rx.operators.transformation.window)

(defmethod window ((self observable) (notifier observable))
  (operator self
            (lambda (subscriber)
              (let* ((prev)
                     (open-window (lambda ()
                                    (if prev (over prev))
                                    (setf prev (create-window)))))
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
                                         (funcall open-window)
                                         (notifynext subscriber (source prev)))
                                       :onfail (onfail subscriber)
                                       :onover (onover subscriber))))))
                (observer :onnext
                          (lambda (value)
                            (unless prev
                              (funcall open-window)
                              (notifynext subscriber (source prev)))
                            (next prev value))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (if prev (over prev))
                            (notifyover subscriber)))))))

(defclass window ()
  ((source :initform nil
           :accessor source
           :type observable)
   (destination :initform nil
                :accessor destination
                :type (or null subscriber observer))))

(defmethod create-window ()
  (let ((window (make-instance 'window)))
    (setf (source window) (observable (lambda (observer) (setf (destination window) observer))))
    window))

(defmethod next ((self window) value)
  (let ((destination (destination self)))
    (if destination
        (next destination value))
    (values)))

(defmethod fail ((self window) reason)
  (let ((destination (destination self)))
    (if destination
        (fail destination reason))
    (values)))

(defmethod over ((self window))
  (let ((destination (destination self)))
    (if destination
        (over destination))
    (values)))
