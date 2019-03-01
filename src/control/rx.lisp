(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:export :observable
           :observer
           :subject
           :onnext
           :onfail
           :onover
           :subscribe
           :filter))

(in-package :aria.control.rx)

(defclass observable ()
  ((revolver :initarg :revolver
             :accessor revolver
             :type function)))

(defclass observer ()
  ((onnext :initarg :onnext
           :accessor onnext
           :type function)
   (onfail :initarg :onfail
           :accessor onfail
           :type function)
   (onover :initarg :onover
           :accessor onover
           :type function)))

(defclass subject (observer)
  ((observers :initform nil
                :accessor observers
                :type list)))

(defmethod id (x) x)

(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

(defmethod observer (&key (onnext #'id) (onfail #'id) (onover #'id))
  (make-instance 'observer :onnext onnext :onfail onfail :onover onover))

(defmethod broadcast ((self subject) (method function))
  (lambda (&rest args)
    (map nil (lambda (observer) (apply (funcall method observer) args)) (observers self))))

(defmethod subject ()
  (let ((self (make-instance 'subject)))
    (setf (onnext self) (broadcast self #'onnext))
    (setf (onfail self) (broadcast self #'onfail))
    (setf (onover self) (broadcast self #'onover))
    self))

(defmethod subscribe ((self observable) (ob observer))
  (funcall (revolver self) ob))

(defmethod subscribe ((self subject) (ob observer))
  (push ob (observers self))
  self)

(defmethod subscribe ((self observable) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod subscribe ((self subject) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod filter ((self observable) (predicate function))
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (subscribe self (observer :onnext (lambda (value) (if (funcall predicate value)
                                                                         (funcall (onnext observer) value)))
                                             :onfail (onfail observer)
                                             :onover (onover observer))))))
