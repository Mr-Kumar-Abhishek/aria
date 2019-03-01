(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:export :observable
           :observer
           :suscribe
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
  ((observables :initform nil
                :accessor observables
                :type list)))


(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

(defmethod id (x) x)

(defmethod observer (&key (onnext #'id) (onfail #'id) (onover #'id))
  (make-instance 'observer :onnext onnext :onfail onfail :onover onover))

(defmethod filter ((self observable) (filter function))
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (subscribe self (observer :onnext (lambda (value) (if (funcall filter value)
                                                                         (funcall (onnext observer) value)))
                                             :onfail (onfail observer)
                                             :onover (onover observer))))))

(defmethod subscribe ((self observable) (ob observer))
  (funcall (revolver self) ob))

(defmethod subscribe ((self subject) (ob observer))
  )

(defmethod subscribe ((self observable) (onnext function))
  )

(defmethod subscribe ((self subject) (onnext function))
  )
