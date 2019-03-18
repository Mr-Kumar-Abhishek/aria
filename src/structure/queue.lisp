(in-package :cl-user)

(defpackage aria.structure.queue
  (:use :cl)
  (:import-from :aria.structure.interface
                :en
                :de
                :emptyp)
  (:export :queue
           :make-queue
           :en
           :de
           :emptyp))

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

(defmethod en ((self queue) e)
  (declare (optimize speed))
  (let ((node (make-node :value e))
        (head))
    (setf head (queue-head self))
    (setf (queue-head self) node)
    (setf (node-prev head) node)
    self))

(defmethod de ((self queue))
  (declare (optimize speed))
  (let ((e)
        (tail (queue-tail self)))
    (if (not (node-prev tail))
        (setf e nil)
        (let ((prev (node-prev tail)))
          (setf e (node-value prev))
          (setf (queue-tail self) prev)))
    e))

(defmethod emptyp ((self queue))
  (declare (optimize speed))
  (not (node-prev (queue-tail self))))
