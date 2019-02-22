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
                :make-heap
                :en
                :de
                :heap-empty-p
                :find-top)
  (:export :timer
           :gen-timer
           :settimeout
           :end))

(in-package :aria.asynchronous.timer)

(defstruct task
  (callable nil :type function)
  (priority (get-internal-real-time) :type integer))

(defclass timer ()
  ((scheduler :initarg :scheduler
              :accessor scheduler
              :type scheduler)
   (tasks :initform (make-heap :accessor #'accessor)
          :accessor tasks
          :type pair-heap)
   (semaphore :initform (make-semaphore)
              :accessor semaphore)))

(defmethod accessor ((self task))
  (task-priority self))

(defun gen-timer (&key (scheduler (gen-scheduler)))
  (loop-core (make-instance 'timer :scheduler scheduler)))

(defmethod settimeout ((self timer) (callback function) &optional (milliseconds 0))
  (let ((start (get-internal-real-time)))
    (add (scheduler self)
         (lambda ()
           (en (tasks self) (make-task :callable callback :priority (+ start milliseconds)))))
    (signal-semaphore (semaphore self))
    self))

(defmethod loop-core ((self timer))
  (loop-core-inner (scheduler self) (tasks self) (semaphore self))
  self)

(defmethod loop-core-inner ((scheduler scheduler) (tasks pair-heap) semaphore)
  (add scheduler
       (lambda ()
         (if (not (heap-empty-p tasks))
             (let* ((top (find-top tasks))
                    (lack (- (task-priority top) (get-internal-real-time))))
               (if (<= lack 0)
                   (error-handler (task-callable (de tasks)))
                   (wait-on-semaphore semaphore :timeout (/ lack 1000))))
             (wait-on-semaphore semaphore))
         (loop-core-inner scheduler tasks semaphore))))
