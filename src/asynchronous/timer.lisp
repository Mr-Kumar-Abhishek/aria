(in-package :cl-user)

(defpackage aria.asynchronous.timer
  (:use :cl)
  (:import-from :bordeaux-threads
                :make-semaphore
                :wait-on-semaphore
                :signal-semaphore)
  (:import-from :aria.asynchronous.scheduler
                :scheduler
                :gen-scheduler
                :add
                :end
                ::error-handler)
  (:import-from :aria.structure.pair-heap
                :pair-heap
                :en
                :de
                :emptyp
                :find-top)
  (:export :timer
           :gen-timer
           :settimeout
           :cleartimeout
           :end))

(in-package :aria.asynchronous.timer)

(defstruct task
  (callable nil :type function)
  (priority (get-internal-real-time) :type integer))

(defclass timer ()
  ((scheduler :initarg :scheduler
              :accessor scheduler
              :type scheduler)
   (tasks :initform (pair-heap :accessor #'accessor)
          :accessor tasks
          :type pair-heap)
   (semaphore :initform (make-semaphore)
              :accessor semaphore)))

(defmethod accessor ((self task))
  (task-priority self))

(defun gen-timer (&key (scheduler (gen-scheduler)))
  (loop-core (make-instance 'timer :scheduler scheduler)))

(defmethod settimeout ((self timer) (callback function) &optional (milliseconds 0))
  (let ((start (get-internal-real-time))
        (clearable (clearable callback)))
    (add (scheduler self)
         (lambda ()
           (en (tasks self) (make-task :callable (callback clearable) :priority (+ start milliseconds)))))
    (signal-semaphore (semaphore self))
    (cancel clearable)))

(defmethod loop-core ((self timer))
  (loop-core-inner (scheduler self) (tasks self) (semaphore self))
  self)

(defmethod loop-core-inner ((scheduler scheduler) (tasks pair-heap) semaphore)
  (add scheduler
       (lambda ()
         (if (not (emptyp tasks))
             (let* ((top (find-top tasks))
                    (lack (- (task-priority top) (get-internal-real-time))))
               (if (<= lack 0)
                   (error-handler (task-callable (de tasks)))
                   (wait-on-semaphore semaphore :timeout (/ lack 1000))))
             (wait-on-semaphore semaphore))
         (loop-core-inner scheduler tasks semaphore))))

(defclass clearable ()
  ((callback :initarg :callback
              :accessor callback
              :type function)
   (cancel :initarg :cancel
           :accessor cancel
           :type function)))

(defmethod clearable ((callback function))
  (let ((cancel nil))
    (make-instance 'clearable
                   :callback (lambda () (unless cancel (funcall callback)))
                   :cancel (lambda () (setf cancel t)))))

(defmethod cleartimeout ((clear function))
  (funcall clear))

(defmethod end ((self timer))
  (end (scheduler self))
  self)
