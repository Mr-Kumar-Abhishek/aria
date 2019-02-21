(in-package :cl-user)

(defpackage aria.structure.miso-queue
  (:use :cl)
  (:import-from :atomics
                :atomic-update)
  (:export :queue
           :make-queue
           :en
           :de
           :queue-empty-p))

(in-package :aria.structure.miso-queue)

(defstruct node
  (prev nil :type (or null node))
  (value nil))

(defstruct (queue (:constructor %make-queue))
  "this miso queue is designed for Multi-In-Single-Out situation, the operation de (means dequeue) is not thread safe due to it should only be excuted in a single thread"
  (head nil :type node)
  (tail nil :type node))

(defmacro update (place value &key (callback nil))
  (let ((p (gensym "place")))
    `(atomic-update
      ,place
      (lambda (,p)
        (if ,callback
            (funcall ,callback))
        ,value))))

(defun make-queue()
  (let ((dummy (make-node :value nil)))
    (%make-queue :head dummy :tail dummy)))

(defmethod en ((queue queue) e)
  (declare (optimize speed))
  (let ((node (make-node :value e))
        (head))
    (update (queue-head queue) node :callback (lambda () (setf head (queue-head queue))))
    (update (node-prev head) node)
    queue))

(defmethod de ((queue queue))
  (declare (optimize speed))
  (let ((e)
        (tail (queue-tail queue)))
    (if (not (node-prev tail))
        (setf e nil)
        (let ((prev (node-prev tail)))
          (setf e (node-value prev))
          (setf (queue-tail queue) prev)))
    e))

(defmethod queue-empty-p ((queue queue))
  (declare (optimize speed))
  (not (node-prev (queue-tail queue))))
