(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.flatmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.mimo-queue
                :mimo-queue
                :en
                :de
                :emptyp)
  (:export :flatmap))

(in-package :aria.control.rx.operators.transformation.flatmap)

(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1))
  "observablefn needs receive a value from next and return a observable
   flatmap will hold all subscriptions from observablefn
   concurrent could limit max size of hold subscriptions"
  (operator self
   (lambda (subscriber)
     (let ((isstop)
           (buffers (mimo-queue))
           (caslock (caslock))
           (active 0))
       (observer :onnext
                 (lambda (value)
                   (flet ((lazysub (value)
                            (lambda (type)
                              (if (eq type :immediately)
                                  (with-caslock caslock
                                    (incf active)))
                              (within-inner-subscriber
                               (funcall observablefn value)
                               subscriber
                               (lambda (inner)
                                 (observer :onnext (on-notifynext subscriber)
                                           :onfail (onfail subscriber)
                                           :onover
                                           (lambda ()
                                             (let ((buffer))
                                               (with-caslock caslock
                                                 (notifyover inner)
                                                 (if (and isstop (emptyp buffers) (<= active 1))
                                                     (notifyover subscriber))
                                                 (if (emptyp buffers)
                                                     (decf active)
                                                     (setf buffer (de buffers))))
                                               (if buffer (funcall buffer :lazy))))))))))
                     (if (or (< active concurrent)
                             (< concurrent 0))
                         (funcall (lazysub value) :immediately)
                         (en buffers (lazysub value)))))
                 :onfail (on-notifyfail subscriber)
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t)
                             (if (and (emptyp buffers) (eq active 0))
                                 (notifyover subscriber)))))))))
