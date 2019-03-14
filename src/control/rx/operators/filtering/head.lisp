(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.head
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock-once)
  (:import-from :aria.control.rx.common
                :tautology)
  (:export :head))

(in-package :aria.control.rx.operators.filtering.head)

(defmethod head ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take first value which compliance with predicate from next, then call observer.over
   will use a default value if there is no match"
  (operator self
            (lambda (subscriber)
              (let ((firstlock (caslock))
                    (hasfirst))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (with-caslock-once firstlock
                                  (setf hasfirst t)
                                  (notifynext subscriber value)
                                  (over subscriber))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (unless hasfirst
                                        (if default-supplied
                                            (notifynext subscriber default)
                                            (notifyfail subscriber "first value not exist")))
                                    (notifyover subscriber)))))))
