(in-package :cl-user)

(defpackage aria-test.control.rx
  (:use :cl :fiveam)
  (:import-from :bordeaux-threads
                :make-thread
                :join-thread
                :make-semaphore
                :wait-on-semaphore
                :signal-semaphore)
  (:import-from :aria-test
                :top)
  (:import-from :aria.asynchronous.timer
                :gen-timer
                :settimeout
                :cleartimeout)
  (:import-from :aria.control.rx
                :observable
                :observer
                :subject
                :onnext
                :onfail
                :onover
                :subscribe
                :mapper
                :mapto
                :each
                :filter
                :debounce
                :throttle
                :throttletime))

(in-package :aria-test.control.rx)

(def-suite control.rx :in top)

(in-suite control.rx)

(defmethod gaptop ((seq sequence) (compare function))
  (let ((prev)
        (top))
    (map nil
         (lambda (x)
           (if prev
               (let ((diff (- prev x)))
                 (cond ((not top) (setf top diff))
                       ((not (funcall compare top diff))
                        (setf top diff)))))
           (setf prev x)
           x)
         seq)
    top))

(test subscribe-observable-async
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 10) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda () (dotimes (x 10) (funcall (onnext observer) x)))))))
         (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector) (signal-semaphore semaphore))))
    (join-thread th)
    (is (equal (reverse collector) (list 0 1 2 3 4 5 6 7 8 9)))))

(test subject
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 20) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda () (dotimes (x 10) (funcall (onnext observer) x)))))))
         (sub (subject))
         (collector0)
         (collector1))
    (subscribe sub (observer :onnext (lambda (value) (push value collector0) (signal-semaphore semaphore))))
    (subscribe sub (lambda (value) (push (* 2 value) collector1) (signal-semaphore semaphore)))
    (subscribe o sub)
    (join-thread th)
    (is (equal (reverse collector0) (list 0 1 2 3 4 5 6 7 8 9)))
    (is (equal (reverse collector1) (list 0 2 4 6 8 10 12 14 16 18)))))

(test observable-onfail
  (let ((o (observable
            (lambda (observer)
              (funcall (onnext observer) 0)
              (funcall (onfail observer) "err")
              (funcall (onnext observer) 1))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list 0 "err")))))

(test observable-error-handler
  (let ((o (observable
            (lambda (observer)
              (funcall (onnext observer) 0)
              (funcall (onnext observer) 1)
              (funcall (onnext observer) 2))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (cond ((eq value 1) (error "err")) (t (push value collector))))
                           :onfail (lambda (reason) (push (simple-condition-format-control reason) collector))))
    (is (equal (reverse collector) (list 0 "err")))))

(test observable-onover
  (let ((o (observable
            (lambda (observer)
              (funcall (onnext observer) 0)
              (funcall (onnext observer) 1)
              (funcall (onover observer))
              (funcall (onnext observer) 2))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 1 "over")))))

(test mapper
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (funcall (onnext observer) x)))))
        (collector))
    (subscribe (mapper o (lambda (x) (+ x 100))) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 100 101 102 103 104 105 106 107 108 109)))))

(test mapto
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (funcall (onnext observer) x)))))
        (collector))
    (subscribe (mapto o 100) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 100 100 100 100 100 100 100 100 100 100)))))

(test each
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (funcall (onnext observer) x)))))
        (collector0)
        (collector1))
    (subscribe (each o (lambda (x) (push (* 2 x) collector0) 100)) (lambda (value) (push value collector1)))
    (is (equal (reverse collector0) (list 0 2 4 6 8 10 12 14 16 18)))
    (is (equal (reverse collector1) (list 0 1 2 3 4 5 6 7 8 9)))))

(test filter
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (funcall (onnext observer) x)))))
        (collector))
    (subscribe (filter o (lambda (x) (eq 0 (mod x 2)))) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 0 2 4 6 8)))))

(test debounce
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 2) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                              (dotimes (x 10) (sleep 0.001) (funcall (onnext observer) x))
                              (sleep 0.021)
                              (dotimes (x 20) (sleep 0.001) (funcall (onnext observer) x)))))))
         (collector)
         (timer (gen-timer)))
    (subscribe (debounce o (lambda (x) (settimeout timer x 20)) #'cleartimeout)
               (lambda (value) (push value collector) (signal-semaphore semaphore)))
    (join-thread th)
    (is (equal (reverse collector) (list 9 19)))))

(test throttle
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 4) (wait-on-semaphore semaphore :timeout 0.2)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                                 (dotimes (x 7) (sleep 0.01)
                                          (funcall (onnext observer) x)))))))
         (collector)
         (times))
    (subscribe (throttle o (lambda (v)
                             (declare (ignorable v))
                             (observable
                              (lambda (observer)
                                (make-thread (lambda ()
                                               (dotimes (x 1)
                                                 (sleep 0.02)
                                                 (funcall (onnext observer) x))))))))
               (lambda (value) (push value collector) (push (get-internal-real-time) times) (signal-semaphore semaphore)))
    (join-thread th)
    (is (>= (length collector) 3))
    (is (<= (length collector) 4))
    (is (eq (first (reverse collector)) 0))
    (is (>= (gaptop times (lambda (x y) (< x y))) (* 0.02 1000)))))

(test throttle-timer-no-run
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 1) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                                 (dotimes (x 7) (sleep 0.01)
                                          (funcall (onnext observer) x)))))))
         (collector))
    (subscribe (throttle o (lambda (v)
                             (declare (ignorable v))
                             (observable
                              (lambda (observer)
                                (make-thread (lambda ()
                                               (dotimes (x 0)
                                                 (sleep 0.02)
                                                 (funcall (onnext observer) x))))))))
               (lambda (value) (push value collector) (signal-semaphore semaphore)))
    (join-thread th)
    (is (equal (reverse collector) (list 0)))))

(test throttletime
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 4) (wait-on-semaphore semaphore :timeout 0.2)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                                 (dotimes (x 7) (sleep 0.01)
                                          (funcall (onnext observer) x)))))))
         (collector)
         (times))
    (subscribe (throttletime o 20)
               (lambda (value) (push value collector) (push (get-internal-real-time) times) (signal-semaphore semaphore)))
    (join-thread th)
    (is (>= (length collector) 3))
    (is (<= (length collector) 4))
    (is (eq (first (reverse collector)) 0))
    (is (>= (gaptop times (lambda (x y) (< x y))) (* 0.02 1000)))))
