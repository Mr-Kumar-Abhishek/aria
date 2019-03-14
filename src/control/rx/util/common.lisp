(in-package :cl-user)

(defmethod empty-function (&rest rest)
  (declare (ignorable rest)))

(defmethod safe-funcall ((function function) &rest rest)
  (unless (eq function #'empty-function)
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
