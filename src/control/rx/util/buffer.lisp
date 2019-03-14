(in-package :cl-user)

(defpackage aria.control.rx.util.buffer
  (:use :cl)
  (:import-from :aria.control.rx.subscriber
                :subscriber
                :next
                :fail
                :over)
  (:export :buffer
           :nextbuffer
           :failbuffer
           :overbuffer
           :process-buffer))

(in-package :aria.control.rx.util.buffer)

(defclass buffer ()
  ())

(defclass nextbuffer (buffer)
  ((value :initarg :value
          :accessor value)))

(defclass failbuffer (buffer)
  ((reason :initarg :reason
           :accessor reason)))

(defclass overbuffer (buffer)
  ())

(defmethod process-buffer ((self subscriber) (buffer nextbuffer))
  (next self (value buffer)))

(defmethod process-buffer ((self subscriber) (buffer failbuffer))
  (fail self (reason buffer)))

(defmethod process-buffer ((self subscriber) (buffer overbuffer))
  (over self))

(defmethod nextbuffer (value)
  (make-instance 'nextbuffer :value value))

(defmethod failbuffer (reason)
  (make-instance 'failbuffer :reason reason))

(defmethod overbuffer ()
  (make-instance 'overbuffer))
