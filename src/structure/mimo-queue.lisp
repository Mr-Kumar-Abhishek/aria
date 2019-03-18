(in-package :cl-user)

(defpackage aria.structure.mimo-queue
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:import-from :aria.structure.interface
                :en
                :de
                :emptyp)
  (:import-from :aria.structure.queue
                :queue
                ::node
                ::node-prev
                ::node-value
                ::queue-head
                ::queue-tail
                ::make-node)
  (:import-from :aria.structure.miso-queue
                :miso-queue
                :en)
  (:export :queue
           :mimo-queue
           :en
           :de
           :emptyp))

(in-package :aria.structure.mimo-queue)

(defstruct (mimo-queue (:include miso-queue)))

(defmethod mimo-queue ()
  (let ((dummy (make-node :value nil)))
    (make-mimo-queue :head dummy :tail dummy)))

(defmethod de ((self mimo-queue))
  (declare (optimize speed))
  (if (emptyp self)
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

(defmethod emptyp ((self mimo-queue))
  (declare (optimize speed))
  (let ((tail (queue-tail self)))
    (loop while
         (not (cas (queue-tail self) tail tail))
       do
         (setf tail (queue-tail self)))
    (not (node-prev tail))))
