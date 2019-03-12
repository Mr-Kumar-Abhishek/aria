(in-package :cl-user)

(defpackage aria.control.rx
  (:use :cl)
  (:import-from :atomics
                :cas)
  (:import-from :aria.structure.mimo-queue
                :queue
                :make-queue
                :en
                :de
                :queue-empty-p)
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
  (:export :operator)
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
           :single
           :skip
           :skipuntil
           :skipwhile
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

(declaim (optimize (speed 0) (safety 3) (debug 3) (compilation-speed 0)))

(defclass observable ()
  ((revolver :initarg :revolver
             :accessor revolver
             :type function)))

(defclass subscription ()
  ((onunsubscribe :initarg :onunsubscribe
                  :accessor onunsubscribe
                  :type function)
   (isunsubscribed :initform nil
                   :accessor isunsubscribed
                   :type boolean)
   (lock :initform (caslock)
         :accessor lock
         :type caslock)))

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

(defmethod empty-function (&rest rest)
  (declare (ignorable rest)))

(defmethod safe-funcall ((function function) &rest rest)
  (unless (eq function #'empty-function)
    (apply function rest)))

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
  (funcall (onnext self) value)
  nil)

(defmethod fail ((self observer) reason)
  (funcall (onfail self) reason)
  nil)

(defmethod over ((self observer))
  (funcall (onover self))
  nil)

(defmethod observable ((revolver function))
  (make-instance 'observable :revolver revolver))

(defmethod observer (&key (onnext #'empty-function) (onfail #'empty-function) (onover #'empty-function))
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

(defmethod subscription-pass (self)
  (declare (ignorable self))
  (make-instance 'subscription :onunsubscribe #'empty-function))

(defmethod subscription-pass ((self function))
  (let ((unsubscribed))
    (make-instance 'subscription :onunsubscribe (lambda () (unless unsubscribed (setf unsubscribed t) (funcall self))))))

(defmethod subscription-pass ((self subscription))
  self)

(defmethod subscribe ((self observable) (observer observer))
  (let ((subscriber (outer-subscriber observer)))
    (connect subscriber (observer :onnext (on-notifynext subscriber)
                                  :onfail (on-notifyfail subscriber)
                                  :onover (on-notifyover subscriber)))
    (subscribe-subscriber self subscriber)
    (source subscriber)))

(defclass subscriber ()
  (;; isstop, flag for subscription
   (isstop :initform nil
           :accessor isstop
           :type boolean)
   ;; isclose, flag for next, fail, over
   (isclose :initform nil
            :accessor isclose
            :type boolean)
   ;; spinlock, for inner subscriptions automatically manage
   (spinlock :initform (caslock)
             :accessor spinlock
             :type caslock)
   (notifylock :initform (caslock)
               :accessor notifylock
               :type caslock)
   (source :initform nil
           :accessor source
           :type (or null subscription))
   (inners :initform nil
           :accessor inners
           :type list)
   (donext :initform #'empty-function
           :accessor donext
           :type function)
   (dofail :initform #'empty-function
           :accessor dofail
           :type function)
   (doover :initform #'empty-function
           :accessor doover
           :type function)))

(defclass buffer ()
  ())

(defclass nextbuffer (buffer)
  ((value :initarg :value
          :accessor value)))

(defclass failbuffer (buffer)
  ((reason :initarg :reason
           :accessor reason)))

(defclass overbuffer (buffer)
  ())

(defmethod process-buffer ((self subscriber) (buffer nextbuffer))
  (next self (value buffer)))

(defmethod process-buffer ((self subscriber) (buffer failbuffer))
  (fail self (reason buffer)))

(defmethod process-buffer ((self subscriber) (buffer overbuffer))
  (over self))

(defmethod nextbuffer (value)
  (make-instance 'nextbuffer :value value))

(defmethod failbuffer (reason)
  (make-instance 'failbuffer :reason reason))

(defmethod overbuffer ()
  (make-instance 'overbuffer))

(defclass inner-subscriber (subscriber)
  ((parent :initarg :parent
           :accessor parent
           :type subscriber)))

(defclass outer-subscriber (subscriber)
  ((destination :initarg :destination
                :accessor destination
                :type (or subscriber observer))
   (onbefore :initform #'empty-function
             :accessor onbefore
             :type function)
   (onafter :initform #'empty-function
            :accessor onafter
            :type function)))

(defmethod next ((self subscriber) value)
 (unless (isstop self)
    (handler-case (safe-funcall (donext self) value)
      (error (reason) (fail self reason)))))

(defmethod fail ((self subscriber) reason)
  (unless (isstop self)
    (safe-funcall (dofail self) reason)))

(defmethod over ((self subscriber))
  (unless (isstop self)
    (safe-funcall (doover self))))

(defmethod outer-subscriber ((self observer))
  (make-instance 'outer-subscriber :destination self))

(defmethod outer-subscriber ((self subscriber))
  (make-instance 'outer-subscriber :destination self))

(defmethod inner-subscriber ((parent subscriber))
  (make-instance 'inner-subscriber :parent parent))

(defmethod subscribe-subscriber :around ((self observable) (subscriber subscriber))
  (call-next-method)
  (if (isstop subscriber)
      (unsubscribe subscriber))
  subscriber)

(defmethod subscribe-subscriber ((self observable) (subscriber subscriber))
  (setf (source subscriber) (subscription-pass (funcall (revolver self) subscriber))))

(defmethod subscribe-subscriber ((self observable) (subscriber outer-subscriber))
  (safe-funcall (onbefore subscriber))
  (call-next-method)
  (safe-funcall (onafter subscriber)))

(defmethod subscribe-subscriber ((self observable) (subscriber inner-subscriber))
  (register (parent subscriber) subscriber)
  (call-next-method))

(defmethod within-inner-subscriber ((self observable) (parent subscriber) (pass function))
  (let* ((subscriber (inner-subscriber parent))
         (observer (funcall pass subscriber)))
    (subscribe-subscriber self (connect subscriber observer))
    subscriber))

(defmethod register ((self subscriber) (inner subscriber))
  (with-caslock (spinlock self)
    (if (isstop self)
        (unsubscribe inner)
        (push inner (inners self))))
  inner)

(defmethod unregister ((self subscriber) (inner subscriber))
  (with-caslock (spinlock self)
    (unless (isstop self)
      (setf (inners self) (remove inner (inners self)))))
  inner)

(defmethod unregister ((self subscriber) (subscription null)))

(defmethod unsubscribe :around ((self subscriber))
  (with-caslock (spinlock self)
    (setf (isstop self) t))
  (map nil (lambda (sub) (unsubscribe sub)) (reverse (inners self)))
  (call-next-method)
  self)

(defmethod unsubscribe ((self subscriber))
  (unsubscribe (source self)))

(defmethod unsubscribe ((self inner-subscriber))
  (unregister (parent self) self)
  (call-next-method))

(defmethod notifynext :around ((self subscriber) value)
  (unless (or (isclose self) (isstop self))
    (call-next-method))
  nil)

(defmethod notifyfail :around ((self subscriber) reason)
  (unless (or (isclose self) (isstop self))
    (with-caslock-once (notifylock self)
      (setf (isclose self) t)
      (call-next-method)
      (unsubscribe self)))
  nil)

(defmethod notifyover :around ((self subscriber))
  (unless (or (isclose self) (isstop self))
    (with-caslock-once (notifylock self)
      (setf (isclose self) t)
      (call-next-method)
      (unsubscribe self)))
  nil)

(defmethod notifynext ((self outer-subscriber) value)
  (next (destination self) value))

(defmethod notifyfail ((self outer-subscriber) reason)
  (fail (destination self) reason))

(defmethod notifyover ((self outer-subscriber))
  (over (destination self)))

(defmethod notifynext ((self inner-subscriber) value)
  (declare (ignorable self value)))

(defmethod notifyfail ((self inner-subscriber) reason)
  (declare (ignorable self reason)))

(defmethod notifyover ((self inner-subscriber))
  (declare (ignorable self)))

(defmethod on-notifynext ((self subscriber))
  (lambda (value)
    (notifynext self value)))

(defmethod on-notifyfail ((self subscriber))
  (lambda (reason)
    (notifyfail self reason)))

(defmethod on-notifyover ((self subscriber))
  (lambda ()
    (notifyover self)))

(defmethod operator ((self observable) (pass function))
  (observable (lambda (observer)
                (let ((subscriber (outer-subscriber observer)))
                  (connect subscriber (funcall pass subscriber))
                  (subscribe-subscriber self subscriber)
                  (lambda ()
                    (unsubscribe subscriber))))))

(defmethod before ((self outer-subscriber) (supplier function))
  (setf (onbefore self) supplier))

(defmethod after ((self outer-subscriber) (supplier function))
  (setf (onafter self) supplier))

(defmethod connect ((self subscriber) (observer observer))
  (setf (donext self) (onnext observer))
  (setf (dofail self) (onfail observer))
  (setf (doover self) (onover observer))
  self)

(defmethod connect ((self subscriber) (subscriber subscriber))
  (error "not support"))

(defmethod subscribe ((self observable) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod subscribe ((self subject) (ob observer))
  (push ob (observers self))
  self)

(defmethod subscribe ((self subject) (onnext function))
  (subscribe self (observer :onnext onnext)))

(defmethod unsubscribe ((self subscription))
  (with-caslock-once (lock self)
    (setf (isunsubscribed self) t)
    (safe-funcall (onunsubscribe self))))

(defmethod unsubscribe (self))

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

(defmethod range ((start integer) (count integer))
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
            (lambda (subscriber)
              (let ((last)
                    (init t))
                (observer :onnext
                          (lambda (value)
                            (if init
                                (progn (setf init nil)
                                       (setf last value)
                                       (notifynext subscriber value))
                                (unless (funcall compare last value)
                                  (setf last value)
                                  (notifynext subscriber value))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))

(defmethod debounce ((self observable) (timer function) (clear function))
  "timer needs receive a onnext consumer and return a timer cancel handler
   clear needs receive a timer cancel handler"
  (operator self
            (lambda (subscriber)
              (let ((cancel))
                (observer :onnext
                          (lambda (value)
                            (let ((cancel-handler cancel))
                              (if (not cancel-handler)
                                  (setf cancel (funcall timer (lambda ()
                                                                (setf cancel nil)
                                                                (notifynext subscriber value))))
                                  (progn (funcall clear cancel-handler)
                                         (setf cancel (funcall timer (lambda ()
                                                                       (setf cancel nil)
                                                                       (notifynext subscriber value))))))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))

(defmethod each ((self observable) (consumer function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (funcall consumer value) (notifynext subscriber value))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod filter ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (if (funcall predicate value)
                                                    (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod head ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take first value which compliance with predicate from next, then call observer.over
   will use a default value if there is no match"
  (operator self
            (lambda (subscriber)
              (let ((firstlock (caslock))
                    (hasfirst))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (with-caslock-once firstlock
                                  (setf hasfirst t)
                                  (notifynext subscriber value)
                                  (over subscriber))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (unless hasfirst
                                        (if default-supplied
                                            (notifynext subscriber default)
                                            (notifyfail subscriber "first value not exist")))
                                    (notifyover subscriber)))))))

(defmethod ignores ((self observable))
  "ignore all values from next, only receive fail and over"
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (declare (ignorable value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod sample ((self observable) (sampler observable))
  (operator self
   (lambda (subscriber)
     (let ((last)
           (hasvalue))
       (after subscriber
              (lambda ()
                (within-inner-subscriber
                 sampler
                 subscriber
                 (lambda (inner)
                   (declare (ignorable inner))
                   (observer :onnext (lambda (x)
                                       (declare (ignorable x))
                                       (if hasvalue
                                           (notifynext subscriber last)))
                             :onfail (on-notifyfail subscriber)
                             :onover (on-notifyover subscriber))))))
       (observer :onnext
                 (lambda (value)
                   (setf last value)
                   (unless hasvalue
                     (setf hasvalue t)))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))

(defmethod single ((self observable) (predicate function))
  "get the only one value which match the predicate
   fail on duplicate
   observable must be over"
  (operator self
            (lambda (subscriber)
              (let ((caslock (caslock))
                    (count 0)
                    (result))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (with-caslock caslock
                                  (if (> count 0)
                                      (fail subscriber "observable emits duplicated matched value")
                                      (progn (incf count)
                                             (setf result value))))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (with-caslock caslock
                              (if (eq count 1)
                                  (notifynext subscriber result)))
                            (notifyover subscriber)))))))

(defmethod skip ((self observable) (number number))
  (operator self
            (lambda (subscriber)
              (let ((count 0)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (with-caslock caslock
                              (if (< count number)
                                  (incf count)
                                  (notifynext subscriber value))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))

(defmethod skipuntil ((self observable) (notifier observable))
  (operator self
   (lambda (subscriber)
     (let ((notify))
       (before subscriber
               (lambda ()
                 (within-inner-subscriber
                  notifier
                  subscriber
                  (lambda (inner)
                    (observer :onnext
                              (lambda (value)
                                (declare (ignorable value))
                                (unless notify
                                  (setf notify t)
                                  (unsubscribe inner)))
                              :onfail
                              (lambda (reason)
                                (fail subscriber reason))
                              :onover
                              (on-notifyover inner))))))
       (observer :onnext
                 (lambda (value)
                   (if notify
                       (notifynext subscriber value)))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))

(defmethod skipwhile ((self observable) (predicate function))
  (operator self
            (lambda (subscriber)
              (observer :onnext
                        (lambda (value)
                          (if (funcall predicate value)
                              (notifynext subscriber value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod tail ((self observable) &optional (predicate #'tautology) (default nil default-supplied))
  "only take last value which compliance with predicate from next
   will use a default value if there is no match"
  (operator self
            (lambda (subscriber)
              (let ((last)
                    (haslast))
                (observer :onnext
                          (lambda (value)
                            (if (funcall predicate value)
                                (progn (setf last value)
                                       (unless haslast
                                         (setf haslast t)))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (if haslast
                                        (notifynext subscriber last)
                                        (if default-supplied
                                            (notifynext subscriber default)
                                            (notifyfail subscriber "tail value not exist")))
                                    (notifyover subscriber)))))))

(defmethod take ((self observable) (count number))
  (operator self
   (lambda (subscriber)
     (let ((takes 0)
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (with-caslock caslock
                     (if (< takes count)
                         (progn (notifynext subscriber value)
                                (incf takes)
                                (unless (< takes count)
                                  (notifyover subscriber)))
                         (notifyover subscriber))))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))

(defmethod throttle ((self observable) (observablefn function))
  "observablefn needs receive a value and return a observable"
  (operator self
   (lambda (subscriber)
     (let ((disable))
       (observer :onnext
                 (lambda (value)
                   (unless disable
                     (setf disable t)
                     (notifynext subscriber value)
                     (within-inner-subscriber
                      (funcall observablefn value)
                      subscriber
                      (lambda (inner)
                        (observer :onnext
                                  (lambda (x)
                                    (declare (ignorable x))
                                    (setf disable nil)
                                    (unsubscribe inner))
                                  :onfail (on-notifyfail inner)
                                  :onover (on-notifyover inner))))))
                 :onfail (on-notifyfail subscriber)
                 :onover (on-notifyover subscriber))))))

(defmethod throttletime ((self observable) (milliseconds number))
  (operator self
            (lambda (subscriber)
              (let ((last))
                (observer :onnext
                          (lambda (value)
                            (let ((now (get-internal-real-time)))
                              (if last
                                  (if (>= now (+ last milliseconds))
                                      (progn (notifynext subscriber value)
                                             (setf last now)))
                                  (progn (setf last now)
                                         (notifynext subscriber value)))))
                          :onfail (on-notifyfail subscriber)
                          :onover (on-notifyover subscriber))))))

(defmethod isrestrict ((self subscriber) (concurrent integer))
  (let ((restrict))
    (unless (< concurrent 0)
      (with-caslock (spinlock self)
        (unless (< (list-length (inners self)) concurrent)
          (setf restrict t))))
    restrict))

;; transformation operators
(defmethod flatmap ((self observable) (observablefn function) &optional (concurrent -1))
  "observablefn needs receive a value from next and return a observable
   flatmap will hold all subscriptions from observablefn
   concurrent could limit max size of hold subscriptions"
  (operator self
   (lambda (subscriber)
     (let ((isstop)
           (buffers (make-queue))
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (if (isrestrict subscriber concurrent)
                       (en buffers (nextbuffer value))
                       (within-inner-subscriber
                        (funcall observablefn value)
                        subscriber
                        (lambda (inner)
                          (observer :onnext
                                    (lambda (value)
                                      (notifynext subscriber value))
                                    :onfail
                                    (lambda (reason)
                                      (fail subscriber reason))
                                    :onover
                                    (lambda ()
                                      (with-caslock caslock
                                        (if (and isstop (queue-empty-p buffers))
                                            (notifyover subscriber))
                                        (notifyover inner))
                                      (unless (queue-empty-p buffers)
                                        (process-buffer subscriber (de buffers)))))))))
                 :onfail (on-notifyfail subscriber)
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t)
                             (let ((ishold))
                               (with-caslock (spinlock subscriber)
                                 (unless (eq (list-length (inners subscriber)) 0)
                                   (setf ishold t)))
                               (unless ishold
                                 (notifyover subscriber))))))))))

(defmethod mapper ((self observable) (function function))
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (value) (notifynext subscriber (funcall function value)))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod mapto ((self observable) value)
  (operator self
            (lambda (subscriber)
              (observer :onnext (lambda (x) (declare (ignorable x)) (notifynext subscriber value))
                        :onfail (on-notifyfail subscriber)
                        :onover (on-notifyover subscriber)))))

(defmethod switchmap ((self observable) (observablefn function))
  "switchmap will hold the last subscription from last call of observablefn"
  (operator self
   (lambda (subscriber)
     (let ((prev)
           (isstop)
           (caslock (caslock)))
       (observer :onnext
                 (lambda (value)
                   (unless isstop
                     (if prev
                         (unsubscribe prev))
                     (setf prev (within-inner-subscriber
                                 (funcall observablefn value)
                                 subscriber
                                 (lambda (inner)
                                   (observer :onnext
                                             (lambda (value)
                                               (notifynext subscriber value))
                                             :onfail
                                             (lambda (reason)
                                               (fail subscriber reason))
                                             :onover
                                             (lambda ()
                                               (with-caslock caslock
                                                 (if isstop (notifyover subscriber))
                                                 (notifyover inner)))))))))
                 :onfail (lambda (reason)
                           (notifyfail subscriber reason))
                 :onover (lambda ()
                           (with-caslock caslock
                             (setf isstop t)
                             (if (isstop prev)
                                 (notifyover subscriber)))))))))
