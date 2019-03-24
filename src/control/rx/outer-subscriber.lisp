(in-package :cl-user)

(defpackage aria.control.rx.outer-subscriber
  (:use :cl)
  (:import-from :aria.control.rx.common
                :noop
                :safe-funcall)
  (:import-from :aria.control.rx.interface
                :subscribe)
  (:import-from :aria.control.rx.observable
                :observable)
  (:import-from :aria.control.rx.observer
                :observer)
  (:import-from :aria.control.rx.subscriber
                :subscriber
                :next
                :fail
                :over
                :notifynext
                :notifyfail
                :notifyover
                :on-notifynext
                :on-notifyfail
                :on-notifyover
                :connect
                :subscribe-subscriber
                :unsubscribe)
  (:export :outer-subscriber
           :notifynext
           :notifyfail
           :notifyover
           :before
           :after
           :subscribe-subscriber
           :subscribe))

(in-package :aria.control.rx.outer-subscriber)

(defclass outer-subscriber (subscriber)
  ((destination :initarg :destination
                :accessor destination
                :type (or subscriber observer))
   (onbefore :initform #'noop
             :accessor onbefore
             :type function)
   (onafter :initform #'noop
            :accessor onafter
            :type function)
   (parent :initform nil
           :accessor parent
           :type (or null outer-subscriber))))

(defmethod notifynext ((self outer-subscriber) value)
  (next (destination self) value))

(defmethod notifyfail ((self outer-subscriber) reason)
  (fail (destination self) reason))

(defmethod notifyover ((self outer-subscriber))
  (over (destination self)))

(defmethod before ((self outer-subscriber) (supplier function))
  (setf (onbefore self) supplier))

(defmethod after ((self outer-subscriber) (supplier function))
  (setf (onafter self) supplier))

(defmethod outer-subscriber ((self observer))
  (make-instance 'outer-subscriber :destination self))

(defmethod outer-subscriber ((self subscriber))
  (make-instance 'outer-subscriber :destination self))

(defmethod outer-subscriber ((self outer-subscriber))
  (let ((subscriber (make-instance 'outer-subscriber :destination self)))
    (setf (parent self) subscriber)
    subscriber))

(defmethod subscribe-subscriber ((self observable) (subscriber outer-subscriber))
  (safe-funcall (onbefore subscriber))
  (call-next-method)
  (safe-funcall (onafter subscriber)))

(defmethod subscribe ((self observable) (observer observer))
  (let ((subscriber (outer-subscriber observer)))
    (connect subscriber (observer :onnext (on-notifynext subscriber)
                                  :onfail (on-notifyfail subscriber)
                                  :onover (on-notifyover subscriber)))
    (subscribe-subscriber self subscriber)
    subscriber))

(defmethod subscribe ((self observable) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod unsubscribe ((self outer-subscriber))
  (let ((parent (parent self)))
    (setf (parent self) nil)
    (unsubscribe parent))
  (call-next-method))
