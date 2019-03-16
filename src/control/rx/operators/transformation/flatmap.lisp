(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.flatmap
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.mimo-queue
                :queue
                :make-queue
                :en
                :de
                :queue-empty-p)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock)
  (:export :flatmap))

(in-package :aria.control.rx.operators.transformation.flatmap)

(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1))
  "observablefn needs receive a value from next and return a observable
   flatmap will hold all subscriptions from observablefn
   concurrent could limit max size of hold subscriptions"
  (operator self
   (lambda (subscriber)
     (let ((isstop)
           (buffers (make-queue))
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
                                 (observer :onnext
                                           (lambda (value)
                                             (notifynext subscriber value))
                                           :onfail (onfail subscriber)
                                           :onover
                                           (lambda ()
                                             (with-caslock caslock
                                               (if (and isstop (queue-empty-p buffers) (<= active 1))
                                                   (notifyover subscriber))
                                               (notifyover inner))
                                             (if (queue-empty-p buffers)
                                                 (with-caslock caslock (decf active))
                                                 (funcall (de buffers) :lazy)))))))))
                     (if (or (< active concurrent)
                             (< concurrent 0))
                         (funcall (lazysub value) :immediately)
                         (en buffers (lazysub value)))))
                 :onfail (on-notifyfail subscriber)
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t)
                             (if (and (queue-empty-p buffers) (eq active 0))
                                 (notifyover subscriber)))))))))
