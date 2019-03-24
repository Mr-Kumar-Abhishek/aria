(in-package :cl-user)

(defpackage aria.control.rx.common
  (:use :cl)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock-once)
  (:export :noop
           :safe-funcall
           :id
           :tautology
           :once))

(in-package :aria.control.rx.common)

(defmethod noop (&rest rest)
  (declare (ignorable rest)))

(defmethod safe-funcall ((function function) &rest rest)
  (unless (eq function #'noop)
    (apply function rest)))

(defmethod id (&optional x) x)

(defmethod tautology (value)
  (declare (ignorable value))
  t)

(defmethod once ((self function))
  (let ((lock (caslock))
        (done))
    (lambda ()
      (unless done
        (with-caslock-once lock
          (funcall self))))))
