(in-package :cl-user)

(defpackage aria.control.rx.observer
  (:use :cl)
  (:import-from :aria.control.rx.common
                :noop
                :safe-funcall)
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
  (make-instance 'observer :onnext (or onnext #'noop) :onfail (or onfail #'noop) :onover (or onover #'noop)))

(defmethod observerp ((self observer))
  (declare (ignorable self))
  t)

(defmethod observerp (self)
  (declare (ignorable self))
  nil)

(defmethod next ((self observer) value)
  (safe-funcall (onnext self) value)
  nil)

(defmethod fail ((self observer) reason)
  (safe-funcall (onfail self) reason)
  nil)

(defmethod over ((self observer))
  (safe-funcall (onover self))
  nil)
