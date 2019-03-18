(in-package :cl-user)

(defpackage aria.asynchronous.scheduler
  (:use :cl)
  (:shadow :signum)
  (:shadow :continue)
  (:import-from :bordeaux-threads
                :make-thread
                :make-semaphore
                :wait-on-semaphore
                :signal-semaphore
                :current-thread)
  (:import-from :atomics
                :atomic-update
                :cas)
  (:import-from :aria.structure.miso-queue
                :queue
                :miso-queue
                :en
                :de
                :emptyp)
  (:export :scheduler
           :gen-scheduler
	   :add
	   :end))

(in-package :aria.asynchronous.scheduler)

(defclass scheduler ()
  ((thread :initform nil
           :accessor thread)
   (tasks :initform (miso-queue)
          :accessor tasks
          :type queue)
   (signum :initform nil
           :accessor signum
           :type (or null keyword))
   (semaphore :initform (make-semaphore)
              :accessor semaphore)
   (pause :initform nil
          :accessor pause
          :type boolean)
   (pauselock :initform :free
              :type keyword))
  (:documentation "scheduler based on a functional lock-free"))

(defmethod end-check ((signum function) (onclose null))
  (lambda () (eq (funcall signum) :end)))

(defmethod end-check ((signum function) (onclose function))
  (lambda () (let ((end (eq (funcall signum) :end)))
               (if end (funcall onclose))
               end)))

(defmethod loop-core ((tasks queue) (endp function) (self scheduler) semaphore)
  (error-handler (de tasks))
  (if (not (funcall endp)) 
      (progn (if (emptyp tasks) (wait self tasks semaphore))
             (loop-core tasks endp self semaphore))))

(defmethod wait ((self scheduler) (tasks queue) semaphore)
  (if (cas (slot-value self 'pauselock) :using :using)
      (loop while (cas (slot-value self 'pauselock) :used :free))
      (progn (cas (slot-value self 'pauselock) :used :free)
             (setf (pause self) t) 
             (wait-on-semaphore semaphore :timeout 1)
             (setf (pause self) nil))))

(defmethod error-handler ((task function))
  (handler-case (funcall task)
    (error (condition) (print condition *error-output*))))

(defmethod error-handler (task))

(defun gen-scheduler (&key (onclose nil) (name "Anonymous scheduler thread"))
  (let* ((bt:*default-special-bindings* `((*standard-output* . ,*standard-output*)
                                          (*error-output* . ,*error-output*)))
         (scheduler (make-instance 'scheduler)))
    (setf (thread scheduler)
          (make-thread
           (lambda () (loop-core (tasks scheduler) (end-check (lambda () (signum scheduler)) onclose) scheduler (semaphore scheduler)))
           :name name))
    scheduler))

(defmethod add ((self scheduler) (task function))
  (en (tasks self) task)
  (continue self)
  self)

(defmethod end ((self scheduler))
  (setf (signum self) :end)
  (continue self)
  self)

(defmethod continue ((self scheduler))
  (if (cas (slot-value self 'pause) t t) ;; check
      (if (cas (slot-value self 'pauselock) :free :using) ;; get lock
          (progn (signal-semaphore (semaphore self))
                 (cas (slot-value self 'pauselock) :using :used)))))
