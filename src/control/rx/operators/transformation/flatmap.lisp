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
  (:import-from :aria.control.rx.util.buffer
                :nextbuffer
                :process-buffer)
  (:export :flatmap))

(in-package :aria.control.rx.operators.transformation.flatmap)

(defmethod isrestrict ((self subscriber) (concurrent integer))
  (let ((restrict))
    (unless (< concurrent 0)
      (with-caslock (spinlock self)
        (unless (< (list-length (inners self)) concurrent)
          (setf restrict t))))
    restrict))

(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1))
  "observablefn needs receive a value from next and return a observable
   flatmap will hold all subscriptions from observablefn
   concurrent could limit max size of hold subscriptions"
  (operator self
   (lambda (subscriber)
     (let ((isstop)
           (buffers (make-queue))
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (if (isrestrict subscriber concurrent)
                       (en buffers (nextbuffer value))
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
                                        (if (and isstop (queue-empty-p buffers))
                                            (notifyover subscriber))
                                        (notifyover inner))
                                      (unless (queue-empty-p buffers)
                                        (process-buffer subscriber (de buffers)))))))))
                 :onfail (on-notifyfail subscriber)
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t)
                             (let ((ishold))
                               (with-caslock (spinlock subscriber)
                                 (unless (eq (list-length (inners subscriber)) 0)
                                   (setf ishold t)))
                               (unless ishold
                                 (notifyover subscriber))))))))))
