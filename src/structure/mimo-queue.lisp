(in-package :cl-user)

(defpackage aria.structure.mimo-queue
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:import-from :aria.structure.queue
                ::node
                :queue
                ::node-prev
                ::node-value
                ::queue-head
                ::queue-tail
                ::make-node
                :make-queue)
  (:import-from :aria.structure.miso-queue
                :en
                :de)
  (:export :queue
           :make-queue
           :en
           :de
           :queue-empty-p))

(in-package :aria.structure.mimo-queue)

(defmethod de ((self queue))
  (declare (optimize speed))
  (if (queue-empty-p self)
      nil
      (let* ((tail (queue-tail self))
             (prev (node-prev tail)))
        (loop while
             (and prev
                  (or (not (eq (queue-tail self) tail))
                      (not (cas (queue-tail self) tail prev))))
           do
             (progn (setf tail (queue-tail self))
                    (setf prev (node-prev tail))))
        (node-value prev))))

(defmethod queue-empty-p ((self queue))
  (declare (optimize speed))
  (let ((tail (queue-tail self)))
    (loop while
         (not (cas (queue-tail self) tail tail))
       do
         (setf tail (queue-tail self)))
    (not (node-prev tail))))
