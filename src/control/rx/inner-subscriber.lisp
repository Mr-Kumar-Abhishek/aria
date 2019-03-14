(in-package :cl-user)

(defpackage aria.control.rx.inner-subscriber
  (:use :cl)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock)
  (:import-from :aria.control.rx.observable
                :observable)
  (:import-from :aria.control.rx.subscriber
                :subscriber
                ::spinlock
                ::isstop
                ::inners
                :notifynext
                :notifyfail
                :notifyover
                :subscribe-subscriber
                :unsubscribe)
  (:export :inner-subscriber
           :notifynext
           :notifyfail
           :notifyover
           :register
           :unregister
           :subscribe-subscriber
           :unsubscribe))

(in-package :aria.control.rx.inner-subscriber)

(defclass inner-subscriber (subscriber)
  ((parent :initarg :parent
           :accessor parent
           :type subscriber)))

(defmethod notifynext ((self inner-subscriber) value)
  (declare (ignorable self value)))

(defmethod notifyfail ((self inner-subscriber) reason)
  (declare (ignorable self reason)))

(defmethod notifyover ((self inner-subscriber))
  (declare (ignorable self)))

(defmethod inner-subscriber ((parent subscriber))
  (make-instance 'inner-subscriber :parent parent))

(defmethod register ((self subscriber) (inner subscriber))
  (with-caslock (spinlock self)
    (if (isstop self)
        (unsubscribe inner)
        (push inner (inners self))))
  inner)

(defmethod unregister ((self subscriber) (inner subscriber))
  (with-caslock (spinlock self)
    (unless (isstop self)
      (setf (inners self) (remove inner (inners self)))))
  inner)

(defmethod unregister ((self subscriber) (subscription null))
  (declare (ignorable self subscription)))

(defmethod subscribe-subscriber ((self observable) (subscriber inner-subscriber))
  (register (parent subscriber) subscriber)
  (call-next-method))

(defmethod unsubscribe ((self inner-subscriber))
  (unregister (parent self) self)
  (call-next-method))
