(in-package :cl-user)

(defpackage aria.structure.miso-queue
  (:use :cl)
  (:import-from :atomics
                :atomic-update)
  (:import-from :aria.structure.interface
                :en
                :de)
  (:import-from :aria.structure.queue
                ::node
                :queue
                ::node-prev
                ::node-value
                ::queue-head
                ::queue-tail
                ::make-node
                :make-queue
                :de
                :queue-empty-p)
  (:export :queue
           :make-queue
           :en
           :de
           :queue-empty-p))

(in-package :aria.structure.miso-queue)

#|
  this miso queue is designed for Multi-In-Single-Out situation, the operation `de`(means dequeue) is not thread safe due to it should only be excuted in a single thread
|#

(defmacro update (place value &key (callback nil))
  (let ((p (gensym "place")))
    `(atomic-update
      ,place
      (lambda (,p)
        (declare (ignorable ,p))
        (if ,callback
            (funcall ,callback))
        ,value))))

(defmethod en ((self queue) e)
  (declare (optimize speed))
  (let ((node (make-node :value e))
        (head))
    (update (queue-head self) node :callback (lambda () (setf head (queue-head self))))
    (update (node-prev head) node)
    self))
