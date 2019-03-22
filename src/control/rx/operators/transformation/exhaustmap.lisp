(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.exhaustmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
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
                                             (let ((needover))
                                               (with-caslock caslock
                                                 (if isstop
                                                     (setf needover t))
                                                 (setf active nil))
                                               (if needover (notifyover subscriber))
                                               (notifyover inner))))))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (let ((needover))
                              (with-caslock caslock
                                (setf isstop t)
                                (unless active
                                  (setf needover t)))
                              (if needover (notifyover subscriber)))))))))
