(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.tail
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.control.rx.common
                :tautology)
  (:export :tail))

(in-package :aria.control.rx.operators.filtering.tail)

(defmethod tail ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take last value which compliance with predicate from next
   will use a default value if there is no match"
  (operator self
            (lambda (subscriber)
              (let ((last)
                    (haslast))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (progn (setf last value)
                                       (unless haslast
                                         (setf haslast t)))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (if haslast
                                        (notifynext subscriber last)
                                        (if default-supplied
                                            (notifynext subscriber default)
                                            (notifyfail subscriber "tail value not exist")))
                                    (notifyover subscriber)))))))
