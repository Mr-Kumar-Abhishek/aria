(in-package :cl-user)

(defpackage aria.control.rx.subscription
  (:use :cl)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock-once)
  (:import-from :aria.control.rx.common
                :noop
                :safe-funcall
                :once)
  (:export :subscription
           :subscriptionp
           :unsubscribe
           :isunsubscribed))

(in-package :aria.control.rx.subscription)

(defclass subscription ()
  ((onunsubscribe :initarg :onunsubscribe
                  :accessor onunsubscribe
                  :type function)
   (isunsubscribed :initform nil
                   :accessor isunsubscribed
                   :type boolean)
   (lock :initform (caslock)
         :accessor lock
         :type caslock)))

(defmethod subscriptionp ((self subscription))
  (declare (ignorable self))
  t)

(defmethod subscriptionp (self)
  (declare (ignorable self))
  nil)

(defmethod subscription-pass (self)
  (declare (ignorable self))
  (make-instance 'subscription :onunsubscribe #'noop))

(defmethod subscription-pass ((self function))
  (make-instance 'subscription :onunsubscribe (once self)))

(defmethod unsubscribe ((self subscription))
  (with-caslock-once (lock self)
    (setf (isunsubscribed self) t)
    (safe-funcall (onunsubscribe self)))
  (values))
