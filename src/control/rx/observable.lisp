(in-package :cl-user)

(defpackage aria.control.rx.observable
  (:use :cl)
  (:export :observable
           :observablep))

(in-package :aria.control.rx.observable)

(defclass observable ()
  ((revolver :initarg :revolver
             :accessor revolver
             :type function)))

(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

(defmethod observablep ((self observable))
  (declare (ignorable self))
  t)

(defmethod observablep (self)
  (declare (ignorable self))
  nil)
