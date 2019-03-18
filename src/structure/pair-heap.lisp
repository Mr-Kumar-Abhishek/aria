(in-package :cl-user)

(defpackage aria.structure.pair-heap
  (:use :cl)
  (:shadow :merge)
  (:shadow :copy-tree)
  (:import-from :atomics
                :atomic-update)
  (:import-from :aria.structure.interface
                :en
                :de
                :emptyp)
  (:import-from :aria.structure.queue
                :queue
                :en
                :de)
  (:export :pair-heap
           :en
           :de
           :emptyp
           :find-top))

(in-package :aria.structure.pair-heap)

(defstruct tree
  (sub (queue) :type queue)
  (element nil))

(defstruct pair-heap
  (tree (make-tree) :type tree)
  (compare nil :type function)
  (accessor nil :type function))

(defstruct (heap (:include pair-heap)))

(defmethod compare (x y)
  (< x y))

(defmethod accessor (element)
  element)

(defmethod pair-heap (&key (element nil) (compare #'compare) (accessor #'accessor))
  (let ((heap (make-heap :compare compare :accessor accessor)))
    (setf (tree-element (heap-tree heap)) element)
    heap))

(defmethod merge ((self tree) (tree tree) (compare function) (accessor function))
  (let ((left (tree-element self))
        (right (tree-element tree)))
    (if left
        (if right
            (if (funcall compare (funcall accessor left) (funcall accessor right))
                (make-tree :element left :sub (en (tree-sub self) tree))
                (make-tree :element right :sub (en (tree-sub tree) self)))
            self)
        tree)))

(defmethod %en ((self tree) element (compare function) (accessor function))
  (merge (make-tree :element element) self compare accessor))

(defmethod en ((self heap) element)
  (setf (heap-tree self) (%en (heap-tree self) element (heap-compare self) (heap-accessor self)))
  self)

(defmethod merge-pairs ((self queue) (compare function) (accessor function))
  (let ((left (de self))
        (right (de self)))
    (if left
        (if right
            (merge (merge left right compare accessor) (merge-pairs self compare accessor) compare accessor)
            left)
        (make-tree))))

(defmethod de ((self heap))
  (let ((element (tree-element (heap-tree self))))
    (setf (heap-tree self) (merge-pairs (tree-sub (heap-tree self)) (heap-compare self) (heap-accessor self)))
    element))

(defmethod %emptyp ((self tree))
  (not (tree-element self)))

(defmethod emptyp ((self heap))
  (%emptyp (heap-tree self)))

(defmethod find-top ((self heap))
  (tree-element (heap-tree self)))
