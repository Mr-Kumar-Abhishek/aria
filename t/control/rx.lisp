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
  (:import-from :aria.control.rx
                :observable
                :observer
                :subject
                :onnext
                :onfail
                :onover
                :subscribe
                :filter))

(in-package :aria-test.control.rx)

(def-suite control.rx :in top)

(in-suite control.rx)

(test subscribe-observable-async
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 10) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (bt:make-thread (lambda () (dotimes (x 10) (funcall (onnext observer) x)))))))
         (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector) (signal-semaphore semaphore))))
    (join-thread th)
    (is (equal (reverse collector) (list 0 1 2 3 4 5 6 7 8 9)))))

(test subject
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 20) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (bt:make-thread (lambda () (dotimes (x 10) (funcall (onnext observer) x)))))))
         (sub (subject))
         (collector0)
         (collector1))
    (subscribe sub (observer :onnext (lambda (value) (push value collector0) (signal-semaphore semaphore))))
    (subscribe sub (lambda (value) (push (* 2 value) collector1) (signal-semaphore semaphore)))
    (subscribe o sub)
    (join-thread th)
    (is (equal (reverse collector0) (list 0 1 2 3 4 5 6 7 8 9)))
    (is (equal (reverse collector1) (list 0 2 4 6 8 10 12 14 16 18)))))

(test filter
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (funcall (onnext observer) x)))))
        (collector))
    (subscribe (filter o (lambda (x) (eq 0 (mod x 2)))) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 0 2 4 6 8)))))
