(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.exhaustmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock)
  (:export :exhaustmap))

(in-package :aria.control.rx.operators.transformation.exhaustmap)

(defmethod exhaustmap ((self observable) (observablefn function))
  (operator self
            (lambda (subscriber)
              (let ((active)
                    (isstop)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (unless active
                              (setf active t)
                              (within-inner-subscriber
                               (funcall observablefn value)
                               subscriber
                               (lambda (inner)
                                 (observer :onnext (on-notifynext subscriber)
                                           :onfail (onfail subscriber)
                                           :onover
                                           (lambda ()
                                             (with-caslock caslock
                                               (if isstop
                                                   (notifyover subscriber))
                                               (notifyover inner)
                                               (setf active nil))))))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (with-caslock caslock
                              (setf isstop t)
                              (unless active
                                (notifyover subscriber)))))))))
