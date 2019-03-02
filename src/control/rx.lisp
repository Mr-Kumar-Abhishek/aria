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
           :operator
           :mapper
           :mapto
           :each
           :filter
           :debounce
           :throttle))

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

(defmethod id (&optional x) x)

(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

(defmethod wrap-observer (&key (onnext #'id) (onfail #'id) (onover #'id))
  (let ((complete nil))
    (make-instance 'observer
                   :onnext (lambda (value)
                             (unless complete
                               (handler-case (funcall onnext value)
                                 (error (reason) (setf complete t) (funcall onfail reason)))))
                   :onfail (lambda (reason) (unless complete (setf complete t) (funcall onfail reason)))
                   :onover (lambda () (unless complete (setf complete t) (funcall onover))))))

(defmethod observer (&key (onnext #'id) (onfail #'id) (onover #'id))
  (wrap-observer :onnext onnext :onfail onfail :onover onover))

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

(defmethod subscribe ((self observable) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod subscribe ((self subject) (ob observer))
  (push ob (observers self))
  self)

(defmethod subscribe ((self subject) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod switchmap ())

(defmethod operator ((self observable) (pass function))
  "pass needs receive a observer and return a observer"
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (subscribe self (funcall pass observer)))))

(defmethod mapper ((self observable) (function function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (funcall (onnext observer) (funcall function value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod mapto ((self observable) value)
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (x) (declare (ignorable x)) (funcall (onnext observer) value))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod each ((self observable) (consumer function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (funcall consumer value) (funcall (onnext observer) value))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod filter ((self observable) (predicate function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (if (funcall predicate value)
                                                    (funcall (onnext observer) value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod debounce ((self observable) (timer function) (clear function))
  "timer needs receive a onnext consumer and return a timer cancel handler
   clear needs receive a timer cancel handler"
  (let ((cancel))
    (operator self
              (lambda (observer)
                (observer :onnext
                          (lambda (value)
                            (let ((cancel-handler cancel))
                              (if (not cancel-handler)
                                  (setf cancel (funcall timer (lambda ()
                                                                (setf cancel nil)
                                                                (funcall (onnext observer) value))))
                                  (progn (funcall clear cancel-handler)
                                         (setf cancel (funcall timer (lambda ()
                                                                       (setf cancel nil)
                                                                       (funcall (onnext observer) value))))))))
                          :onfail (onfail observer)
                          :onover (onover observer))))))

(defmethod throttle ((self observable) (timer function))
  "timer needs receive a value and return a onservable"
  (let ((gap)
        (last1)
        (last2))
    (operator self
              (lambda (observer)
                (observer :onnext
                          (lambda (value)
                            (unless (or gap last1 last2)
                              (setf last1 (get-internal-real-time))
                              (setf last2 last1)
                              (funcall (onnext observer) value)
                              (subscribe (funcall timer value)
                                         (lambda (x)
                                           (declare (ignorable x))
                                           (let ((now (get-internal-real-time)))
                                             (setf gap (- now last1))
                                             (setf last1 now)))))
                            (let ((now (get-internal-real-time))
                                  (gap-copy gap))
                              (if (and gap-copy
                                       (>= now (+ gap-copy last2)))
                                  (progn (funcall (onnext observer) value)
                                         (setf last2 now))))))))))
