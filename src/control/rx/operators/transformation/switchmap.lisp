(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.switchmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :switchmap))

(in-package :aria.control.rx.operators.transformation.switchmap)

(defmethod switchmap ((self observable) (observablefn function))
  "switchmap will hold the last subscription from last call of observablefn"
  (operator self
   (lambda (subscriber)
     (let ((prev)
           (isstop)
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (unless isstop
                     (if prev
                         (unsubscribe prev))
                     (setf prev (within-inner-subscriber
                                 (funcall observablefn value)
                                 subscriber
                                 (lambda (inner)
                                   (observer :onnext
                                             (lambda (value)
                                               (notifynext subscriber value))
                                             :onfail (onfail subscriber)
                                             :onover
                                             (lambda ()
                                               (notifyover inner)
                                               (let ((needover))
                                                 (with-caslock caslock
                                                   (if isstop (setf needover t)))
                                                 (if needover (notifyover subscriber))))))))))
                 :onfail (lambda (reason)
                           (notifyfail subscriber reason))
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t))
                           (if (isstop prev)
                               (notifyover subscriber))))))))
