(in-package :cl-user)

(defpackage aria.control.rx.observer
  (:use :cl)
  (:import-from :aria.control.rx.common
                :empty-function)
  (:export :observer
           :observerp
           :nexr
           :fail
           :over
           :onnext
           :onfail
           :onover))

(in-package :aria.control.rx.observer)

(defclass observer ()
  ((onnext :initarg :onnext
           :accessor onnext
           :type function)
   (onfail :initarg :onfail
           :accessor onfail
           :type function)
   (onover :initarg :onover
           :accessor onover
           :type function)))

(defmethod observer (&key onnext onfail onover)
  (make-instance 'observer :onnext (or onnext #'empty-function) :onfail (or onfail #'empty-function) :onover (or onover #'empty-function)))

(defmethod observerp ((self observer))
  (declare (ignorable self))
  t)

(defmethod observerp (self)
  (declare (ignorable self))
  nil)

(defmethod next ((self observer) value)
  (funcall (onnext self) value)
  nil)

(defmethod fail ((self observer) reason)
  (funcall (onfail self) reason)
  nil)

(defmethod over ((self observer))
  (funcall (onover self))
  nil)