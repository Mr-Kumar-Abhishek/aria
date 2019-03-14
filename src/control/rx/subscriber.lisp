(in-package :cl-user)

(defpackage aria.control.rx.subscriber
  (:use :cl)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock
                :with-caslock-once)
  (:import-from :aria.control.rx.common
                :safe-funcall)
  (:import-from :aria.control.rx.observer
                :observer
                :onnext
                :onfail
                :onover)
  (:import-from :aria.control.rx.subscription
                :subscription
                :isunsubscribed)
  (:export :subscriber
           :subscriberp
           :next
           :fail
           :over
           :onnext
           :onfail
           :onover
           :notifynext
           :notifyfail
           :notifyover
           :on-notifynext
           :on-notifyfail
           :on-notifyover
           :connect
           :subscribe-subscriber
           :unsubscribe
           :isunsubscribed))

(in-package :aria.control.rx.subscriber)

(defclass subscriber ()
  (;; isstop, flag for subscription
   (isstop :initform nil
           :accessor isstop
           :type boolean)
   ;; isclose, flag for next, fail, over
   (isclose :initform nil
            :accessor isclose
            :type boolean)
   ;; spinlock, for inner subscriptions automatically manage
   (spinlock :initform (caslock)
             :accessor spinlock
             :type caslock)
   (notifylock :initform (caslock)
               :accessor notifylock
               :type caslock)
   (source :initform nil
           :accessor source
           :type (or null subscription))
   (inners :initform nil
           :accessor inners
           :type list)
   (connector :initform nil
              :accessor connector
              :type (or null observer))))

(defmethod subscriberp ((self subscriber))
  (declare (ignorable self))
  t)

(defmethod subscriberp (self)
  (declare (ignorable self))
  nil)

(defmethod next ((self subscriber) value)
  (unless (isstop self)
    (handler-case (next-in (connector self) value)
      (error (reason) (fail self reason))))
  nil)

(defmethod next-in ((self observer) value)
  (safe-funcall (onnext self) value))

(defmethod next-in ((self null) value)
  (declare (ignorable self value))
  (error "subscriber is not connect"))

(defmethod fail ((self subscriber) reason)
  (unless (isstop self)
    (fail-in (connector self) reason)
  nil))

(defmethod fail-in ((self observer) reason)
  (safe-funcall (onfail self) reason))

(defmethod fail-in ((self null) reason)
  (declare (ignorable self reason))
  (error "subscriber is not connect"))

(defmethod over ((self subscriber))
  (unless (isstop self)
    (over-in (connector self)))
  nil)

(defmethod over-in ((self observer))
  (safe-funcall (onover self)))

(defmethod over-in ((self null))
  (declare (ignorable self))
  (error "subscriber is not connect"))

(defmethod onnext ((self subscriber))
  (lambda (value)
    (next self value)))

(defmethod onfail ((self subscriber))
  (lambda (reason)
    (fail self reason)))

(defmethod onover ((self subscriber))
  (lambda ()
    (over self)))

(defmethod notifynext :around ((self subscriber) value)
  (unless (or (isclose self) (isstop self))
    (call-next-method))
  nil)

(defmethod notifyfail :around ((self subscriber) reason)
  (unless (or (isclose self) (isstop self))
    (with-caslock-once (notifylock self)
      (setf (isclose self) t)
      (call-next-method)
      (unsubscribe self)))
  nil)

(defmethod notifyover :around ((self subscriber))
  (unless (or (isclose self) (isstop self))
    (with-caslock-once (notifylock self)
      (setf (isclose self) t)
      (call-next-method)
      (unsubscribe self)))
  nil)

(defmethod on-notifynext ((self subscriber))
  (lambda (value)
    (notifynext self value)))

(defmethod on-notifyfail ((self subscriber))
  (lambda (reason)
    (notifyfail self reason)))

(defmethod on-notifyover ((self subscriber))
  (lambda ()
    (notifyover self)))

(defmethod connect ((self subscriber) (observer observer))
  (setf (connector self) observer)
  self)

(defmethod subscribe-subscriber :around ((self observable) (subscriber subscriber))
  (call-next-method)
  (if (isstop subscriber)
      (unsubscribe subscriber))
  subscriber)

(defmethod subscribe-subscriber ((self observable) (subscriber subscriber))
  (setf (source subscriber) (subscription-pass (funcall (revolver self) subscriber))))

(defmethod unsubscribe :around ((self subscriber))
  (with-caslock (spinlock self)
    (setf (isstop self) t))
  (map nil (lambda (sub) (unsubscribe sub)) (reverse (inners self)))
  (call-next-method)
  self)

(defmethod unsubscribe ((self subscriber))
  (unsubscribe (source self)))

(defmethod isunsubscribed ((self subscriber))
  (isunsubscribed (source self)))
