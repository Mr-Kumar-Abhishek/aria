(in-package :cl-user)

(defpackage aria.structure.pair-heap
  (:use :cl)
  (:shadow :merge)
  (:shadow :copy-tree)
  (:import-from :atomics
                :atomic-update)
  (:import-from :aria.structure.queue
                :queue
                :make-queue
                :en
                :de
                :queue-empty-p)
  (:export :heap
           :make-heap
           :en
           :de
           :heap-empty-p
           :find-top))

(in-package :aria.structure.pair-heap)

(defstruct node
  (priority 0 :type number)
  (value nil))

(defstruct (heap (:constructor %make-heap))
  (sub (make-queue) :type queue)
  (element nil))

(defstruct tree
  (heap (%make-heap) :type heap)
  (compare nil :type function)
  (accessor nil :type function))

(defmethod compare (x y)
  (< x y))

(defmethod accessor (self)
  self)

(defmethod make-heap (&key (element nil) (compare #'compare) (accessor #'accessor))
  (let ((tree (make-tree :compare compare :accessor accessor)))
    (setf (heap-element (tree-heap tree)) element)
    tree))

(defmethod merge ((self heap) (heap heap) (compare function) (accessor function))
  (let ((left (heap-element self))
        (right (heap-element heap)))
    (if left
        (if right
            (if (funcall compare (funcall accessor left) (funcall accessor right))
                (%make-heap :element left :sub (heap-sub heap))
                (%make-heap :element right :sub (heap-sub self)))
            self)
        heap)))

(defmethod %en ((self heap) element (compare function) (accessor function))
  (merge (%make-heap :element element) self compare accessor))

(defmethod en ((self tree) element)
  (setf (tree-heap self) (%en (tree-heap self) element (tree-compare self) (tree-accessor self)))
  self)

(defmethod merge-pairs ((self queue) (compare function) (accessor function))
  (let ((left (de self))
        (right (de self)))
    (if left
        (if right
            (merge (merge left right compare accessor) (merge-pairs self compare accessor) compare accessor)
            left)
        (%make-heap))))

(defmethod de ((self tree))
  (let ((element (heap-element (tree-heap self))))
    (setf (tree-heap self) (merge-pairs (heap-sub (tree-heap self)) (tree-compare self) (tree-accessor self)))
    element))

(defmethod %heap-empty-p ((self heap))
  (not (heap-element self)))

(defmethod heap-empty-p ((self tree))
  (%heap-empty-p (tree-heap self)))
