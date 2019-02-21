(in-package :cl-user)

(defpackage aria.structure.queue
  (:use :cl)
  (:export :queue
           :make-queue
           :en
           :de
           :queue-empty-p))

(in-package :aria.structure.queue)

(defstruct node
  (prev nil :type (or null node))
  (value nil))

(defstruct (queue (:constructor %make-queue))
  (head nil :type node)
  (tail nil :type node))

(defmethod make-queue ()
  (let ((dummy (make-node :value nil)))
    (%make-queue :head dummy :tail dummy)))

(defmethod en ((queue queue) e)
  (declare (optimize speed))
  (let ((node (make-node :value e))
        (head))
    (setf head (queue-head queue))
    (setf (queue-head queue) node)
    (setf (node-prev head) node)
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
