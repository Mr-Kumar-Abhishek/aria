(in-package :cl-user)

(defpackage aria.structure.ring
  (:use :cl)
  (:import-from :aria.structure.interface
                :en
                :de)
  (:export :ring
           :en
           :de
           :enr
           :der
           :size
           :emptyp
           :tolist
           :doring))

(in-package :aria.structure.ring)

(defstruct ring
  (array nil :type array)
  (head 0 :type integer)
  (tail 0 :type integer))

(defmethod ring ((size integer))
  (make-ring :array (make-array (+ 1 size) :initial-element nil)))

(defmethod en ((self ring) value)
  (with-slots (array head tail) self
    (let ((length (array-total-size array)))
      (setf head (mod (incf head) length))
      (setf (ring-head self) head)
      (if (equal head tail)
          (setf (ring-tail self) (mod (incf tail) length)))
      (setf (aref array head) value)))
  self)

(defmethod de ((self ring))
  (with-slots (array head tail) self
    (let ((length (array-total-size array)))
      (unless (equal tail head)
        (setf tail (mod (incf tail) length))
        (setf (ring-tail self) tail))
      (aref array tail))))

(defmethod enr ((self ring) value)
  (with-slots (array head tail) self
    (let ((length (array-total-size array)))
      (setf (aref array tail) value)
      (setf tail (mod (decf tail) length))
      (setf (ring-tail self) tail)
      (if (equal tail head)
          (setf (ring-head self) (mod (decf head) length)))))
  self)

(defmethod der ((self ring))
  (with-slots (array head tail) self
    (let ((length (array-total-size array))
          (value (aref array head)))
      (unless (equal head tail)
        (setf head (mod (decf head) length))
        (setf (ring-head self) head))
      value)))

(defmethod size ((self ring))
  (with-slots (array head tail) self
    (let ((length (array-total-size array)))
      (mod (- head tail) length))))

(defmethod emptyp ((self ring))
  (eq (ring-head self) (ring-tail self)))

(defmethod tolist ((self ring))
  (with-slots (array head tail) self
    (let* ((collect)
           (length (array-total-size array))
           (size (mod (- head tail) length)))
      (dotimes (x size)
        (push (aref array (mod (- head x) length)) collect))
      collect)))

(defmethod doring ((self ring) (consumer function))
  (with-slots (array head tail) self
    (let* ((length (array-total-size array))
           (size (mod (- head tail) length)))
      (dotimes (x size)
        (funcall consumer (aref array (mod (+ (+ tail 1) x) length))))
      self)))
