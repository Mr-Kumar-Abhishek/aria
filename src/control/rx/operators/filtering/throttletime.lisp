(in-package :cl-user)

(defpackage aria.control.rx.operators.filtering.throttletime
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :throttletime))

(in-package :aria.control.rx.operators.filtering.throttletime)

(defmethod throttletime ((self observable) (milliseconds integer))
  (operator self
            (lambda (subscriber)
              (let ((last))
                (observer :onnext
                          (lambda (value)
                            (let ((now (get-internal-real-time)))
                              (if last
                                  (if (>= now (+ last milliseconds))
                                      (progn (notifynext subscriber value)
                                             (setf last now)))
                                  (progn (setf last now)
                                         (notifynext subscriber value)))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))
