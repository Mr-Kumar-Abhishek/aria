(in-package :cl-user)

(defpackage aria.concurrency.caslock
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:export :caslock
           :with-caslock
           :with-caslock-once))

(in-package :aria.concurrency.caslock)

(defclass caslock ()
  ((lock :initform :free
         :accessor lock
         :type keyword)))

(defmethod caslock ()
  (make-instance 'caslock))

(defmacro with-caslock (caslock &rest expr)
  (let ((lock (gensym)))
    `(let ((,lock ,caslock))
       (loop while (not (cas (slot-value ,lock 'lock) :free :used)))
       ,@expr
       (setf (slot-value ,lock 'lock) :free))))

(defmacro with-caslock-once (caslock &rest expr)
  (let ((lock (gensym)))
    `(let ((,lock ,caslock))
       (if (cas (slot-value ,lock 'lock) :free :used)
           (progn ,@expr)))))

