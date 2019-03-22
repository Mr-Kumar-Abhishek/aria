(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.single
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :single))

(in-package :aria.control.rx.operators.filtering.single)

(defmethod single ((self observable) (predicate function))
  "get the only one value which match the predicate
   fail on duplicate
   observable must be over"
  (operator self
            (lambda (subscriber)
              (let ((caslock (caslock))
                    (count 0)
                    (result))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (let ((needfail))
                                  (with-caslock caslock
                                    (if (> count 0)
                                        (setf needfail t)
                                        (progn (incf count)
                                               (setf result value))))
                                  (if needfail (fail subscriber "observable emits duplicated matched value")))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (let ((neednext))
                              (with-caslock caslock
                                (if (eq count 1)
                                    (setf neednext t)))
                              (if neednext (notifynext subscriber result)))
                            (notifyover subscriber)))))))
