(in-package :cl-user)

(defpackage aria.control.rx.subject
  (:use :cl)
  (:import-from :aria.control.rx.observer
                :observer)
  (:export :subject
           :subjectp
           :subscribe))

(in-package :aria.control.rx.subject)

(defclass subject (observer)
  ((observers :initform nil
              :accessor observers
              :type list)))

(defmethod subjectp ((self subject))
  (declare (ignorable self))
  t)

(defmethod subjectp (self)
  (declare (ignorable self))
  nil)

(defmethod broadcast ((self subject) (method function))
  (lambda (&rest args)
    (map nil (lambda (observer) (apply (funcall method observer) args)) (observers self))))

(defmethod subject ()
  (let ((self (make-instance 'subject)))
    (setf (onnext self) (broadcast self #'onnext))
    (setf (onfail self) (broadcast self #'onfail))
    (setf (onover self) (broadcast self #'onover))
    self))

(defmethod subscribe ((self subject) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod subscribe ((self subject) (ob observer))
  (push ob (observers self))
  self)
