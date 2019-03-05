(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:export :observable
           :observablep
           :subscribe)
  (:export :subscription
           :subscriptionp
           :unsubscribe
           :isunsubscribed)
  (:export :observer
           :observerp
           :onnext
           :onfail
           :onover
           :next
           :fail
           :over)
  (:export :subject
           :subjectp
           :subscribe)
  ;; help customize operators
  (:export :operator
           :operator-auto-unsubcribe)
  ;; creation operators
  (:export :of
           :from
           :range
           :empty
           :thrown)
  ;; filtering operators
  (:export :distinct
           :debounce
           :each
           :filter
           :head
           :ignores
           :mapper
           :mapto
           :sample
           :tail
           :take
           :throttle
           :throttletime))

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
   (lock :initform :free
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

(defclass caslock ()
  ((lock :initform :free
         :accessor lock
         :type keyword)))

(defmethod caslock ()
  (make-instance 'caslock))

(defmacro with-caslock (caslock &rest expr)
  `(progn (loop while (not (cas (slot-value ,caslock 'lock) :free :used)))
          ,@expr
          (setf (slot-value ,caslock 'lock) :free)))

(defmacro with-caslock-once (caslock &rest expr)
  `(if (cas (slot-value ,caslock 'lock) :free :used)
       (progn ,@expr)))

(defmethod wrap-observer (&key (onnext #'id) (onfail #'id) (onover #'id))
  (let ((complete)
        (caslock (caslock)))
    (make-instance 'observer
                   :onnext (lambda (value)
                             (unless complete
                               (handler-case (funcall onnext value)
                                 (error (reason) (with-caslock-once caslock
                                                   (setf complete t)
                                                   (funcall onfail reason))))))
                   :onfail (lambda (reason)
                             (with-caslock-once caslock
                               (setf complete t)
                               (funcall onfail reason)))
                   :onover (lambda ()
                             (with-caslock-once caslock
                               (setf complete t)
                               (funcall onover))))))

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
        (isfail)
        (onfail (onfail ob))
        (subscription))
    (setf (onover ob) (lambda () (setf isover t) (funcall onover)))
    (setf (onfail ob) (lambda (reason) (setf isfail t) (funcall onfail reason)))
    (setf subscription (subscription-pass (funcall (revolver self) ob)))
    (let ((onover (onover ob))
          (onfail (onfail ob)))
      ;; method unsubscribe is thread safe
      (setf (onover ob) (lambda () (funcall onover) (unsubscribe subscription)))
      (setf (onfail ob) (lambda (reason) (funcall onfail reason) (unsubscribe subscription))))
    (if (or isover isfail)
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
  (if (cas (slot-value self 'lock) :free :used)
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

(defmethod operator-auto-unsubcribe ((self observable) (pass function))
  "pass needs receive a observer, a subscription register and return a observer
   thread safe"
  (let* ((subscriptions)
         (isunsub)
         (caslock (caslock))
         (register (lambda (subscription)
                     (with-caslock caslock
                       (if isunsub
                           (unsubscribe (subscription-pass subscription))
                           (push (subscription-pass subscription) subscriptions)))))
         (unsuball (lambda ()
                     (with-caslock caslock
                       (setf isunsub t))
                     (map nil (lambda (unsub) (unsubscribe unsub)) subscriptions))))
    (make-instance 'observable
                   :revolver
                   (lambda (observer)
                     (let* ((ob (funcall pass observer register))
                            (onfail (onfail ob))
                            (onover (onover ob)))
                       (funcall register (subscribe self ob))
                       (setf (onfail ob) (lambda (reason) (funcall onfail reason) (funcall unsuball)))
                       (setf (onover ob) (lambda () (funcall onover) (funcall unsuball)))
                       unsuball)))))

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
                (loop for x from start to (+ start count -1) do (next observer x))
                (over observer))))

(defmethod empty ()
  (observable (lambda (observer) (over observer))))

(defmethod thrown (reason)
  (observable (lambda (observer) (fail observer reason))))

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

(defmethod tautology (value)
  (declare (ignorable value))
  t)

(defmethod head ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take first value which compliance with predicate from next, then call observer.over
   will use a default value if there is no match"
  (operator self
            (lambda (observer)
              (let ((firstlock (caslock))
                    (hasfirst))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (with-caslock-once firstlock
                                  (setf hasfirst t)
                                  (next observer value)
                                  (over observer))))
                          :onfail (onfail observer)
                          :onover (lambda ()
                                    (unless hasfirst
                                        (if default-supplied
                                            (next observer default)
                                            (error "first value not exist")))
                                    (onover observer)))))))

(defmethod ignores ((self observable))
  "ignore all values from next, only receive fail and over"
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (declare (ignorable value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod tail ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take last value which compliance with predicate from next
   will use a default value if there is no match"
  (operator self
            (lambda (observer)
              (let ((last)
                    (haslast))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (progn (setf last value)
                                       (unless haslast
                                         (setf haslast t)))))
                          :onfail (onfail observer)
                          :onover (lambda ()
                                    (if haslast
                                        (next observer last)
                                        (if default-supplied
                                            (next observer default)
                                            (error "tail value not exist")))
                                    (over observer)))))))

(defmethod sample ((self observable) (sampler observable))
  (operator-auto-unsubcribe
   self
   (lambda (observer register)
     (let ((last))
       (funcall register
                (subscribe sampler
                           (lambda (x)
                             (declare (ignorable x))
                             (next observer last))))
       (observer :onnext
                 (lambda (value)
                   (setf last value))
                 :onfail (onfail observer)
                 :onover (onover observer))))))

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

(defmethod take ((self observable) (count number))
  (operator self
            (lambda (observer)
              (let ((takes 0)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (with-caslock caslock
                              (if (< takes count)
                                  (progn (next observer value)
                                         (incf takes)
                                         (unless (< takes count)
                                           (over observer)))
                                  (over observer))))
                          :onfail (onfail observer)
                          :onover (onover observer))))))

(defmethod throttle ((self observable) (observablefn function))
  "observablefn needs receive a value and return a observable"
  (operator self
            (lambda (observer)
              (let ((disable))
                (observer :onnext
                          (lambda (value)
                            (unless disable
                              (setf disable t)
                              (next observer value)
                              (subscribe (take (funcall observablefn value) 2)
                                         (observer :onover (lambda () (setf disable nil))))))
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

