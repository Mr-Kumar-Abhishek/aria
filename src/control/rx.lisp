(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:export :observable
           :subscription
           :observer
           :subject
           :observablep
           :subscriptionp
           :observerp
           :subjectp
           :onnext
           :onfail
           :onover
           :next
           :fail
           :over
           :subscribe
           :unsubscribe
           :isunsubscribed
           :operator
           :of
           :from
           :range
           :empty
           :thrown
           :mapper
           :mapto
           :each
           :filter
           :debounce
           :throttle
           :throttletime
           :distinct))

(in-package :aria.control.rx)

(defclass observable ()
  ((revolver :initarg :revolver
             :accessor revolver
             :type function)))

(defclass subscription ()
  ((onunsubscribe :initarg :onunsubscribe
                  :accessor onunsubscribe
                  :type (or null function))
   (isunsubscribed :initform nil
                   :accessor isunsubscribed
                   :type boolean)
   (locker :initform :free
           :type keyword)))

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

(defmethod observablep ((self observable))
  (declare (ignorable self))
  t)

(defmethod observablep (self)
  (declare (ignorable self))
  nil)

(defmethod subscriptionp ((self subscription))
  (declare (ignorable self))
  t)

(defmethod subscriptionp (self)
  (declare (ignorable self))
  nil)

(defmethod observerp ((self observer))
  (declare (ignorable self))
  t)

(defmethod observerp (self)
  (declare (ignorable self))
  nil)

(defmethod subjectp ((self subject))
  (declare (ignorable self))
  t)

(defmethod subjectp (self)
  (declare (ignorable self))
  nil)

(defmethod id (&optional x) x)

(defmethod next ((self observer) value)
  (funcall (onnext self) value))

(defmethod fail ((self observer) reason)
  (funcall (onfail self) reason))

(defmethod over ((self observer))
  (funcall (onover self)))

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

(defmethod subscription-pass (self)
  (declare (ignorable self))
  (make-instance 'subscription :onunsubscribe nil))

(defmethod subscription-pass ((self function))
  (let ((unsubscribed))
    (make-instance 'subscription :onunsubscribe (lambda () (unless unsubscribed (setf unsubscribed t) (funcall self))))))

(defmethod subscription-pass ((self subscription))
  self)

(defmethod subscribe ((self observable) (ob observer))
  (let ((isover)
        (onover (onover ob))
        (subscription))
    (setf (onover ob)
          (lambda ()
            (setf isover t)
            (funcall onover)))
    (setf subscription (subscription-pass (funcall (revolver self) ob)))
    (let ((onover (onover ob)))
      (setf (onover ob) (lambda () (funcall onover) (unsubscribe subscription)))) ;; method unsubscribe is thread safe
    (if isover
        (unsubscribe subscription))
    subscription))

(defmethod subscribe ((self observable) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod subscribe ((self subject) (ob observer))
  (push ob (observers self))
  self)

(defmethod subscribe ((self subject) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod unsubscribe ((self subscription))
  (if (cas (slot-value self 'locker) :free :used)
      (progn (setf (isunsubscribed self) t)
             (let ((onunsubscribe (onunsubscribe self)))
               (if onunsubscribe
                   (funcall onunsubscribe))))))

(defmethod switchmap ())

(defmethod operator ((self observable) (pass function))
  "pass needs receive a observer and return a observer"
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (subscribe self (funcall pass observer)))))

;; operators
;; operators.creation
(defmethod of (&rest rest)
  (observable (lambda (observer)
                (loop for x in rest do (next observer x))
                (over observer))))

(defmethod from ((seq sequence))
  (observable (lambda (observer)
                (map nil (lambda (x) (next observer x)) seq)
                (over observer))))

(defmethod range ((start number) (count number))
  (observable (lambda (observer)
                (loop for x from start to (+ start count -1) do (next observer x)))))

(defmethod empty ()
  (observable (lambda (observer) (over observer))))

(defmethod thrown (reason)
  (observable (lambda (observer)
                (fail observer reason))))

;; operators.filtering
(defmethod mapper ((self observable) (function function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (next observer (funcall function value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod mapto ((self observable) value)
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (x) (declare (ignorable x)) (next observer value))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod each ((self observable) (consumer function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (funcall consumer value) (next observer value))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod filter ((self observable) (predicate function))
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (if (funcall predicate value)
                                                    (next observer value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod debounce ((self observable) (timer function) (clear function))
  "timer needs receive a onnext consumer and return a timer cancel handler
   clear needs receive a timer cancel handler"
  (operator self
            (lambda (observer)
              (let ((cancel))
                (observer :onnext
                          (lambda (value)
                            (let ((cancel-handler cancel))
                              (if (not cancel-handler)
                                  (setf cancel (funcall timer (lambda ()
                                                                (setf cancel nil)
                                                                (next observer value))))
                                  (progn (funcall clear cancel-handler)
                                         (setf cancel (funcall timer (lambda ()
                                                                       (setf cancel nil)
                                                                       (next observer value))))))))
                          :onfail (onfail observer)
                          :onover (onover observer))))))

(defmethod throttle ((self observable) (observablefn function))
  "observablefn needs receive a value and return a observable"
  (operator self
            (lambda (observer)
              (let ((gap)
                    (last1)
                    (last2))
                (observer :onnext
                          (lambda (value)
                            (let ((now (get-internal-real-time))
                                  (gap-copy gap))
                              (if gap-copy
                                  (if (>= now (+ gap-copy last2))
                                      (progn (setf last2 now)
                                             (next observer value)))
                                  (unless (or last1 last2)
                                    (setf last1 now)
                                    (setf last2 last1)
                                    (next observer value)
                                    (subscribe (funcall observablefn value)
                                               (lambda (x)
                                                 (declare (ignorable x))
                                                 (let ((now (get-internal-real-time)))
                                                   (setf gap (- now last1))
                                                   (setf last1 now))))))))
                          :onfail (onfail observer)
                          :onover (onover observer))))))

(defmethod throttletime ((self observable) (milliseconds number))
  (operator self
            (lambda (observer)
              (let ((last))
                (observer :onnext
                          (lambda (value)
                            (let ((now (get-internal-real-time)))
                              (if last
                                  (if (>= now (+ last milliseconds))
                                      (progn (next observer value)
                                             (setf last now)))
                                  (progn (setf last now)
                                         (next observer value)))))
                          :onfail (onfail observer)
                          :onover (onover observer))))))

(defmethod distinct ((self observable) &optional (compare #'eq))
  "distinct won't send value to next until it change
   compare receive two value and return boolean, use eq as default compare method"
  (operator self
            (lambda (observer)
              (let ((last)
                    (init t))
                (observer :onnext
                          (lambda (value)
                            (if init
                                (progn (setf init nil)
                                       (setf last value)
                                       (next observer value))
                                (unless (funcall compare last value)
                                  (setf last value)
                                  (next observer value)))))))))

