(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.flatmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.queue
                :queue
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
           (buffers (queue))
           (caslock (caslock))
           (active 0))
       (observer :onnext
                 (lambda (value)
                   (flet ((lazysub ()
                            (lambda ()
                              (within-inner-subscriber
                               (funcall observablefn value)
                               subscriber
                               (lambda (inner)
                                 (observer :onnext (on-notifynext subscriber)
                                           :onfail (onfail subscriber)
                                           :onover
                                           (lambda ()
                                             (notifyover inner)
                                             (let ((needover)
                                                   (buffer))
                                               (with-caslock caslock
                                                 (if (and isstop (emptyp buffers) (<= active 1))
                                                     (setf needover t))
                                                 (if (emptyp buffers)
                                                     (decf active)
                                                     (setf buffer (de buffers))))
                                               (if needover (notifyover subscriber))
                                               (if buffer (funcall buffer))))))))))
                     (let ((immediate))
                       (with-caslock caslock
                         (if (or (< active concurrent)
                                 (< concurrent 0))
                             (progn (setf immediate t)
                                    (incf active))
                             (en buffers (lazysub))))
                       (if immediate
                         (funcall (lazysub))))))
                 :onfail (on-notifyfail subscriber)
                 :onover (lambda ()
                           (let ((needover))
                             (with-caslock caslock
                               (setf isstop t)
                               (if (and (emptyp buffers) (eq active 0))
                                   (setf needover t)))
                             (if needover (notifyover subscriber)))))))))
