(in-package :cl-user)

(defpackage aria-test.asynchronous.scheduler
  (:use :cl :test-interface)
  (:shadow :count)
  (:import-from :bordeaux-threads
                :make-thread
                :join-thread
                :thread)
  (:import-from :atomics
                :atomic-update)
  (:import-from :aria-test
                :top)
  (:import-from :aria.asynchronous.scheduler
                :gen-scheduler
                :add
                :end))

(in-package :aria-test.asynchronous.scheduler)

(def-suite asynchronous.scheduler :in top)

(in-suite asynchronous.scheduler)

(defmacro atomic-incf (place &optional (delta 1))
  (let ((p (gensym "place")))
    `(atomic-update ,place (lambda (,p) (setf ,p (+ ,p ,delta))))))

(defun times (max f)
  (do ((i 0 (+ i 1)))
      ((>= i max) 'done)
    (funcall f i)))

(defstruct count
  (thread 0 :type number)
  (task 0 :type number))

(defparameter async nil)
(defparameter hot nil)
(defparameter *schedulers* (list))
(defmethod test-async ((number number) (callback function) (count count))
  (setf *schedulers* (list))
  (times number
         (lambda (n)
           (declare (ignorable n))
           (let ((scheduler (gen-scheduler :onclose (lambda () (atomic-incf (count-thread count))
                                                            (if (eq number (count-thread count))
                                                                (funcall callback) ;; excute when all threads over
                                                                )))))
             (push scheduler *schedulers*)
             (times 1000
                    (lambda (i)
                      (add scheduler
                           (lambda ()
                             (atomic-incf (count-task count))
                             (if (eq i 999)
                                 (add scheduler (lambda () (end scheduler))))))))))))

(defclass blocker()
  ((thread :accessor thread
           :type thread)
   (end :initform nil
        :accessor end
        :type boolean)))

(defmethod initialize-instance :after ((self blocker) &key)
  (setf (thread self) (make-thread (lambda () (loop while (not (end self)) do (sleep 0.125)))))
  self)

(defmethod release ((self blocker))
  (setf (end self) t))

(test scheduler-async
  (setf async (make-count))
  (let ((blocker (make-instance 'blocker)))
    (test-async 1000 (lambda () (release blocker)) async)
    (join-thread (thread blocker)))
  (is (eq (count-task async) 1000000)))

(defparameter multi nil)
(defparameter *scheduler* nil)
(defmethod test-multi-in ((number number) (callback function) (count count))
  (let ((scheduler (gen-scheduler :onclose callback)))
    (setf *scheduler* scheduler)
    (times number
           (lambda (n)
             (declare (ignorable n))
             (make-thread (lambda () (times 1000 (lambda (i)
                                                   (add scheduler (lambda () (atomic-incf (count-task count))))
                                                   (if (eq i 999)
                                                       (add scheduler (lambda ()
                                                                        (atomic-incf (count-thread count))
                                                                        (if (eq (count-thread count) number)
                                                                            (end scheduler)))))))))))))


(test scheduler-multi-in
  (setf multi (make-count))
  (let ((blocker (make-instance 'blocker)))
    (test-multi-in 1000 (lambda () (release blocker)) multi)
    (join-thread (thread blocker)))
  (is (eq (count-task multi) 1000000)))

