(in-package :cl-user)

(defpackage aria.structure.ring
  (:use :cl)
  (:import-from :aria.structure.interface
                :en
                :de)
  (:export :ring
           :make-ring
           :en
           :de
           :enr
           :der
           :size
           :emptyp
           :tolist))

(in-package :aria.structure.ring)

(defstruct (ring (:constructor %make-ring))
  (array nil :type array)
  (head 0 :type integer)
  (tail 0 :type integer))

(defmethod make-ring ((size integer))
  (%make-ring :array (make-array (+ 1 size))))

(defmethod en ((self ring) value)
  (let* ((array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array)))
    (setf head (mod (incf head) length))
    (setf (ring-head self) head)
    (if (equal head tail)
        (setf (ring-tail self) (mod (incf tail) length)))
    (setf (aref array head) value))
  self)

(defmethod de ((self ring))
  (let* ((array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array)))
    (unless (equal tail head)
      (setf tail (mod (incf tail) length))
      (setf (ring-tail self) tail))
    (aref array tail)))

(defmethod enr ((self ring) value)
  (let* ((array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array)))
    (setf (aref array tail) value)
    (setf tail (mod (decf tail) length))
    (setf (ring-tail self) tail)
    (if (equal tail head)
        (setf (ring-head self) (mod (decf head) length))))
  self)

(defmethod der ((self ring))
  (let* ((array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array)))
    (let ((value (aref array head)))
      (unless (equal head tail)
        (setf head (mod (decf head) length))
        (setf (ring-head self) head))
      value)))

(defmethod size ((self ring))
  (let* ((array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array)))
    (mod (- head tail) length)))

(defmethod emptyp ((self ring))
  (eq (ring-head self) (ring-tail self)))

(defmethod tolist ((self ring))
  (let* ((collect)
         (array (ring-array self))
         (head (ring-head self))
         (tail (ring-tail self))
         (length (array-total-size array))
         (size (mod (- head tail) length)))
    (dotimes (x size)
      (push (aref array (mod (- head x) length)) collect))
    collect))
