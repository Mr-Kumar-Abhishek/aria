(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock
                :with-caslock-once)
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
           :operator-with-subscriptions-context
           :operator-with-passfail-over-context
           :operator-with-passfail-holdover-context
           :subscribe-unsafe
           :subscribe-with-passfail-over-context)
  (:export :subscriptions-context
           :register
           :register-source
           :unregister
           :unsubscribe-all)
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
           :sample
           :tail
           :take
           :throttle
           :throttletime)
  ;;transformation operators
  (:export :flatmap
           :mapper
           :mapto
           :switchmap))

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

(defmethod tautology (value)
  (declare (ignorable value))
  t)

(defmethod next ((self observer) value)
  (funcall (onnext self) value))

(defmethod fail ((self observer) reason)
  (funcall (onfail self) reason))

(defmethod over ((self observer))
  (funcall (onover self)))

(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

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

(defmethod subscribe ((self observable) (observer observer))
  (let* ((isover)
         (isfail)
         (subscription)
         (ob (observer :onnext (onnext observer)
                       :onfail (lambda (reason)
                                 (setf isfail t)
                                 (fail observer reason)
                                 (if subscription
                                     (unsubscribe subscription)))
                       :onover (lambda ()
                                 (setf isover t)
                                 (over observer)
                                 (if subscription
                                     (unsubscribe subscription))))))
    (setf subscription (subscription-pass (funcall (revolver self) ob)))
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

(defmethod operator ((self observable) (pass function))
  "pass needs receive a observer and return a observer"
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (subscribe-unsafe self (funcall pass observer)))))

(defmethod operator-with-subscriptions-context ((self observable) (pass function))
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (let* ((context (subscriptions-context)))
                     (register-source context (subscribe-unsafe self (funcall pass observer context)))
                     (lambda ()
                       (unsubscribe-all context))))))

(defmethod subscribe-unsafe ((self observable) (observer observer))
  "designed for customize operator
   need to manually unsubscribe the subscription when onfail or onover happens"
  (subscription-pass (funcall (revolver self) observer)))

(defmethod operator-with-passfail-over-context ((self observable) (pass function))
  "automatically unsubscribe all when source fail, over"
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (let* ((context (fail-over-context))
                          (observer (funcall pass observer context))
                          (ob (source-over context (source-passfail context observer)))
                          (source (subscribe-unsafe self ob)))
                     (if (isunsubscribed context)
                         (unsubscribe source)
                         (register-source context source))
                     (lambda ()
                       (unsubscribe-all context))))))

(defmethod operator-with-passfail-holdover-context ((self observable) (pass function))
  "automatically unsubscribe all when source fail, source over while all inner over"
  (make-instance 'observable
                 :revolver
                 (lambda (observer)
                   (let* ((context (fail-over-context))
                          (observer (funcall pass observer context))
                          (ob (source-holdover context (source-passfail context observer)))
                          (source (subscribe-unsafe self ob)))
                     (if (isunsubscribed context)
                         (unsubscribe source)
                         (register-source context source))
                     (lambda ()
                       (unsubscribe-all context))))))

(defclass subscriptions-context ()
  ((subscriptions :initform nil
                  :accessor subscriptions
                  :type list)
   (source :initform nil
           :accessor source
           :type (or null subscription))
   (spinlock :initform (caslock)
             :accessor spinlock
             :type caslock)
   (isunsubscribed :initform nil
                   :accessor isunsubscribed
                   :type boolean)))

(defmethod subscriptions-context ()
  (make-instance 'subscriptions-context))

(defmethod register ((self subscriptions-context) (subscription subscription))
  (with-caslock (spinlock self)
    (if (isunsubscribed self)
        (unsubscribe subscription)
        (push subscription (subscriptions self)))))

(defmethod register-source ((self subscriptions-context) (subscription subscription))
  (setf (source self) subscription))

(defmethod unregister ((self subscriptions-context) (subscription subscription))
  (with-caslock (spinlock self)
    (unless (isunsubscribed self)
      (setf (subscriptions self) (remove subscription (subscriptions self))))))

(defmethod unregister ((self subscriptions-context) (subscription null)))

(defmethod unsubscribe-all ((self subscriptions-context))
  (with-caslock (spinlock self)
    (setf (isunsubscribed self) t))
  (let ((source (source self)))
    (if (subscriptionp source)
        (unsubscribe source)))
  (map nil (lambda (sub) (unsubscribe sub)) (reverse (subscriptions self))))

(defclass fail-context (subscriptions-context)
  ((isfail :initform nil
           :accessor isfail
           :type boolean)))

(defmethod fail-context ()
  (make-instance 'fail-context))

(defclass over-context (subscriptions-context)
  ((isover :initform nil
           :accessor isover
           :type boolean)))

(defmethod over-context ()
  (make-instance 'over-context))

(defclass fail-over-context (fail-context over-context)
  ())

(defmethod fail-over-context ()
  (make-instance 'fail-over-context))

(defmethod source-passfail ((context fail-context) (observer observer))
  (observer :onnext
            (lambda (value)
              (unless (isfail context)
                (next observer value)))
            :onfail (lambda (reason)
                      (fail observer reason)
                      (unsubscribe-all context))
            :onover (onover observer)))

(defmethod source-over ((context over-context) (observer observer))
  (observer :onnext (onnext observer)
            :onfail (onfail observer)
            :onover (lambda ()
                      (setf (isover context) t)
                      (over observer)
                      (if (source context) (unsubscribe-all context)))))

(defmethod source-holdover ((context over-context) (observer observer))
  (observer :onnext (onnext observer)
            :onfail (onfail observer)
            :onover (lambda ()
                      (setf (isover context) t)
                      (let ((active))
                        (with-caslock (spinlock context)
                          (setf active (> (length (subscriptions context)) 0)))
                        (unless active
                          (over observer)
                          (unsubscribe-all context))))))

(defmethod inner-passfail ((context fail-context) (observer observer))
  "inner fail will cause source fail"
  (observer :onnext (onnext observer)
            :onfail
            (lambda (reason)
              (setf (isfail context) t)
              (fail observer reason))
            :onover (onover observer)))

(defmethod subscribe-inner-over ((self observable) (context over-context) (observer observer))
  "source coult only over after all inner over"
  (let* ((current)
         (isover))
    (setf current (subscribe-unsafe self (observer :onnext (onnext observer)
                                                   :onfail (onfail observer)
                                                   :onover
                                                   (lambda ()
                                                     (setf isover t)
                                                     (if (isover context)
                                                         (progn (over observer)
                                                                (unsubscribe-all context))
                                                         (progn (unregister context current)
                                                                (if current
                                                                    (unsubscribe current))))))))
    (if isover
        (unsubscribe current)
        (register context current))
    current))

(defmethod subscribe-with-passfail-over-context ((self observable) (context fail-over-context) (observer observer))
  "designed for customize operator
   inner fail will cause source fail
   inner over will not cause source over
   automatically manage inner subscriptions"
  (subscribe-inner-over self context (inner-passfail context observer)))

;; operators
;; creation operators
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

;; filtering operators
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
                                            (fail observer "first value not exist")))
                                    (over observer)))))))

(defmethod ignores ((self observable))
  "ignore all values from next, only receive fail and over"
  (operator self
            (lambda (observer)
              (observer :onnext (lambda (value) (declare (ignorable value)))
                        :onfail (onfail observer)
                        :onover (onover observer)))))

(defmethod sample ((self observable) (sampler observable))
  (operator-with-subscriptions-context
   self
   (lambda (observer context)
     (let ((last))
       (register context (subscribe-unsafe sampler
                                           (observer :onnext (lambda (x)
                                                               (declare (ignorable x))
                                                               (next observer last))
                                                     :onfail (onfail observer)
                                                     :onover (onover observer))))
       (observer :onnext
                 (lambda (value)
                   (setf last value))
                 :onfail (lambda (reason)
                           (fail observer reason)
                           (unsubscribe-all context))
                 :onover (lambda ()
                           (over observer)
                           (unsubscribe-all context)))))))

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
                                            (fail observer "tail value not exist")))
                                    (over observer)))))))

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
  (operator-with-passfail-over-context
   self
   (lambda (observer context)
     (let ((disable))
       (observer :onnext
                 (lambda (value)
                   (unless disable
                     (setf disable t)
                     (next observer value)
                     (let ((current)
                           (isnext))
                       (setf current (subscribe-with-passfail-over-context
                                      (funcall observablefn value)
                                      context
                                      (observer :onnext
                                                (lambda (x)
                                                  (declare (ignorable x))
                                                  (setf disable nil)
                                                  (setf isnext t)
                                                  (if current
                                                      (unsubscribe current))))))
                       (if isnext
                           (unsubscribe current)))))
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

;; transformation operators
(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1))
  "observablefn needs receive a value from next and return a observable
   flatmap will hold all subscriptions from observablefn
   concurrent could limit max size of hold subscriptions"
  (operator-with-passfail-holdover-context
   self
   (lambda (observer context)
     (observer :onnext
               (lambda (value)
                 (let ((restrict))
                   (unless (< concurrent 0)
                     (with-caslock (spinlock context)
                       (unless (< (length (subscriptions context)) concurrent)
                         (setf restrict t))))
                   (unless restrict
                     (subscribe-with-passfail-over-context
                      (funcall observablefn value)
                      context
                      observer))))
               :onfail (onfail observer)
               :onover (onover observer)))))

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

(defmethod switchmap ((self observable) (observablefn function))
  (operator-with-passfail-holdover-context
   self
   (lambda (observer context)
     (let ((prev))
       (observer :onnext
                 (lambda (value)
                   (if prev
                       (progn (unregister context prev)
                              (unsubscribe prev)))
                   (setf prev (subscribe-with-passfail-over-context
                               (funcall observablefn value)
                               context
                               observer)))
                 :onfail (onfail observer)
                 :onover (onover observer))))))
