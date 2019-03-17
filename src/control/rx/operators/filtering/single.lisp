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
                                (with-caslock caslock
                                  (if (> count 0)
                                      (fail subscriber "observable emits duplicated matched value")
                                      (progn (incf count)
                                             (setf result value))))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (with-caslock caslock
                              (if (eq count 1)
                                  (notifynext subscriber result)))
                            (notifyover subscriber)))))))
