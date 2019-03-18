(in-package :cl-user)

(defpackage aria.structure.miso-queue
  (:use :cl)
  (:import-from :atomics
                :atomic-update)
  (:import-from :aria.structure.interface
                :en
                :de
                :emptyp)
  (:import-from :aria.structure.queue
                ::node
                :queue
                ::node-prev
                ::node-value
                ::queue-head
                ::queue-tail
                ::make-node
                :de
                :emptyp)
  (:export :queue
           :miso-queue
           :en
           :de
           :emptyp))

(in-package :aria.structure.miso-queue)

#|
  this miso queue is designed for Multi-In-Single-Out situation, the operation `de`(means dequeue) is not thread safe due to it should only be excuted in a single thread
|#

(defstruct (miso-queue (:include queue)))

(defmethod miso-queue ()
  (let ((dummy (make-node :value nil)))
    (make-miso-queue :head dummy :tail dummy)))

(defmacro update (place value &key (callback nil))
  (let ((p (gensym "place")))
    `(atomic-update
      ,place
      (lambda (,p)
        (declare (ignorable ,p))
        (if ,callback
            (funcall ,callback))
        ,value))))

(defmethod en ((self miso-queue) e)
  (declare (optimize speed))
  (let ((node (make-node :value e))
        (head))
    (update (queue-head self) node :callback (lambda () (setf head (queue-head self))))
    (update (node-prev head) node)
    self))
