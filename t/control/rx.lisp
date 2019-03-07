(in-package :cl-user)

(defpackage aria-test.control.rx
  (:use :cl :test-interface)
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
                :subscriptionp
                :onnext
                :onfail
                :onover
                :next
                :fail
                :over
                :subscribe
                :unsubscribe
                :isunsubscribed)
  ;; creation operators
  (:import-from :aria.control.rx
                :of
                :from
                :range
                :empty
                :thrown)
  ;; filtering operators
  (:import-from :aria.control.rx
                :distinct
                :debounce
                :each
                :filter
                :head
                :ignores
                :sample
                :single
                :skip
                :skipuntil
                :tail
                :take
                :throttle
                :throttletime)
  ;; transformation operators
  (:import-from :aria.control.rx
                :flatmap
                :mapper
                :mapto
                :switchmap))

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
               (make-thread (lambda () (dotimes (x 10) (next observer x)))))))
         (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector) (signal-semaphore semaphore))))
    (join-thread th)
    (is (equal (reverse collector) (list 0 1 2 3 4 5 6 7 8 9)))))

(test subscriptionp
  (let ((o (observable
             (lambda (observer)
               (declare (ignorable observer))))))
    (is (subscriptionp (subscribe o (observer :onnext (lambda (value) value)))))))

(test subscription-manually-unsubscribe
  (let* ((collector)
         (o (observable
             (lambda (observer)
               (declare (ignorable observer))
               (lambda () (push "unsub" collector))))))
    (unsubscribe (subscribe o (observer :onfail (lambda () (push "fail" collector))
                                        :onover (lambda (reason) (push reason collector)))))
    (is (equal (reverse collector) (list "unsub")))))

(test subscription-automatically-unsubscribe-onover
  (let* ((collector)
         (o (observable
             (lambda (observer)
               (over observer)
               (lambda () (push "unsub" collector))))))
    (subscribe o (observer :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list "over" "unsub")))))

(test subscription-automatically-unsubscribe-onfail
  (let* ((collector)
         (o (observable
             (lambda (observer)
               (fail observer "fail")
               (lambda () (push "unsub" collector))))))
    (subscribe o (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "fail" "unsub")))))

(test subject
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 20) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda () (dotimes (x 10) (next observer x)))))))
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
              (next observer 0)
              (fail observer "err")
              (next observer 1))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list 0 "err")))))

(test observable-error-handler
  (let ((o (observable
            (lambda (observer)
              (next observer 0)
              (next observer 1)
              (next observer 2))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (cond ((eq value 1) (error "err")) (t (push value collector))))
                           :onfail (lambda (reason) (push (simple-condition-format-control reason) collector))))
    (is (equal (reverse collector) (list 0 "err")))))

(test observable-onover
  (let ((o (observable
            (lambda (observer)
              (next observer 0)
              (next observer 1)
              (over observer)
              (next observer 2))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 1 "over")))))

;; creation operators

(test of
  (let* ((o (of 1 2 3 "hi" "go"))
         (collector)
         (subscription (subscribe o (observer :onnext (lambda (value) (push value collector))
                                              :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list 1 2 3 "hi" "go" "end")))
    (is (isunsubscribed subscription))))

(test from
  (let* ((o (from "hello world"))
         (collector)
         (subscription (subscribe o (observer :onnext (lambda (value) (push value collector))
                                              :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list #\h #\e #\l #\l #\o #\  #\w #\o #\r #\l #\d "end")))
    (is (isunsubscribed subscription))))

(test range
  (let* ((o (range 0 10))
         (collector)
         (subscription (subscribe o (observer :onnext (lambda (value) (push value collector))
                                              :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list 0 1 2 3 4 5 6 7 8 9 "end")))
    (is (isunsubscribed subscription))))

(test empty
  (let* ((o (empty))
         (collector)
         (subscription (subscribe o (observer :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list "end")))
    (is (isunsubscribed subscription))))

(test thrown
  (let* ((o (thrown "fail"))
         (collector)
         (subscription (subscribe o (observer :onfail (lambda (reason) (push reason collector))
                                              :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list "fail")))
    (is (isunsubscribed subscription))))

;; filtering operators

(test debounce
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 2) (wait-on-semaphore semaphore)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                              (dotimes (x 10) (sleep 0.001) (next observer x))
                              (sleep 0.021)
                              (dotimes (x 20) (sleep 0.001) (next observer x)))))))
         (collector)
         (timer (gen-timer)))
    (subscribe (debounce o (lambda (x) (settimeout timer x 20)) #'cleartimeout)
               (lambda (value) (push value collector) (signal-semaphore semaphore)))
    (join-thread th)
    (is (equal (reverse collector) (list 9 19)))))

(test distinct
  (let* ((o (observable
             (lambda (observer)
               (next observer 0)
               (next observer 0)
               (next observer 2)
               (next observer 2)
               (next observer 0)
               (next observer 2))))
         (collector))
    (subscribe (distinct o)
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 0 2 0 2)))))

(test distinct-compare
  (let* ((o (observable
             (lambda (observer)
               (next observer (lambda () 0))
               (next observer (lambda () 0))
               (next observer (lambda () 2))
               (next observer (lambda () 2))
               (next observer (lambda () 0))
               (next observer (lambda () 2)))))
         (collector))
    (subscribe (distinct o (lambda (x y) (eq (funcall x) (funcall y))))
               (lambda (value) (push value collector)))
    (is (equal (map 'list (lambda (supplier) (funcall supplier)) (reverse collector)) (list 0 2 0 2)))))

(test each
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (next observer x)))))
        (collector0)
        (collector1))
    (subscribe (each o (lambda (x) (push (* 2 x) collector0) 100)) (lambda (value) (push value collector1)))
    (is (equal (reverse collector0) (list 0 2 4 6 8 10 12 14 16 18)))
    (is (equal (reverse collector1) (list 0 1 2 3 4 5 6 7 8 9)))))

(test filter
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (next observer x)))))
        (collector))
    (subscribe (filter o (lambda (x) (eq 0 (mod x 2)))) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 0 2 4 6 8)))))

(test head
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (head o) (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 1)))))

(test head-precidate
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (head o (lambda (value) (> value 2))) (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 3)))))

(test head-no-exist-fail
  (let ((o (of 1 2 3 4))
        (collector))
    (handler-case
        (subscribe (head o (lambda (value) (> value 4)))
                   (observer :onnext (lambda (value) (push value collector))
                             :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))))
      (error (reason) (declare (ignorable reason)) (push "handle error" collector)))
    (is (equal (reverse collector) (list "fail")))))

(test head-precidate-default
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (head o (lambda (value) (> value 4)) "default")
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))))
    (is (equal (reverse collector) (list "default")))))

(test ignores
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (ignores o) (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list)))))

(test ignores-onfail
  (let ((o (thrown "fail"))
        (collector))
    (subscribe (ignores o) (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "fail")))))

(test ignores-onover
  (let ((o (empty))
        (collector))
    (subscribe (ignores o) (observer :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list "over")))))

(test sample
  (let* ((event1)
         (event2)
         (event3)
         (collector)
         (o (sample (observable (lambda (observer)
                                  (setf event1 (lambda () (next observer "event1")))
                                  (setf event2 (lambda () (next observer "event2")))))
                    (observable (lambda (observer)
                                  (setf event3 (lambda () (next observer "event3"))))))))
    (subscribe o (observer :onnext (lambda (value) (push value collector))))
    (funcall event1)
    (funcall event2)
    (funcall event3)
    (funcall event3)
    (is (equal (reverse collector) (list "event2" "event2")))))

(test sample-automatically-unsubcribe-all-onover
  (let* ((end)
         (collector)
         (o (sample (observable (lambda (observer)
                                  (setf end (lambda () (over observer)))
                                  (lambda () (push "unsub source" collector))))
                    (observable (lambda (observer)
                                  (declare (ignorable observer))
                                  (lambda () (push "unsub sampler" collector)))))))
    (subscribe o (observer :onover (lambda () (push "over" collector))))
    (funcall end)
    (is (equal (reverse collector) (list "over" "unsub source" "unsub sampler")))))

(test sample-automatically-unsubcribe-all-onfail
  (let* ((end)
         (collector)
         (o (sample (observable (lambda (observer)
                                  (setf end (lambda () (fail observer "fail")))
                                  (lambda () (push "unsub source" collector))))
                    (observable (lambda (observer)
                                  (declare (ignorable observer))
                                  (lambda () (push "unsub sampler" collector)))))))
    (subscribe o (observer :onfail (lambda (reason) (push reason collector))))
    (funcall end)
    (is (equal (reverse collector) (list "fail" "unsub source" "unsub sampler")))))

(test sample-manually-unsubcribe-all
  (let* ((end)
         (collector)
         (o (sample (observable (lambda (observer)
                                  (setf end (lambda () (over observer)))
                                  (lambda () (push "unsub source" collector))))
                    (observable (lambda (observer)
                                  (declare (ignorable observer))
                                  (lambda () (push "unsub sampler" collector)))))))
    (unsubscribe (subscribe o (observer :onover (lambda () (push "over" collector)))))
    (is (equal (reverse collector) (list "unsub source" "unsub sampler")))))

(test single
  (let ((collector)
        (o (of 1 2 3 3 4)))
    (subscribe (single o (lambda (x) (eq x 4)))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 4 "over")))))

(test single-duplicated-matched
  (let ((collector)
        (o (of 1 2 3 3 4)))
    (subscribe (single o (lambda (x) (eq x 3)))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list "fail")))))

(test single-not-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 4)
                            (next observer x))))))
    (subscribe (single o (lambda (x) (eq x 0)))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))
                         :onover (lambda () (push "over" collector))))
    (is (eq (reverse collector) nil))))

(test single-empty-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 4)
                            (next observer x))
                          (over observer)))))
    (subscribe (single o (lambda (x) (eq x 0)))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 "over")))))

(test skip
  (let ((collector)
        (o (of 1 2 3 4)))
    (subscribe (skip o 2) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 3 4)))))

(test skip-zero
  (let ((collector)
        (o (of 1 2 3 4)))
    (subscribe (skip o 0) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 1 2 3 4)))))

(test skipuntil
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 3) (wait-on-semaphore semaphore :timeout 0.2)))))
         (collector)
         (o (observable (lambda (observer)
                          (make-thread (lambda ()
                                         (dotimes (x 4)
                                           (sleep 0.01)
                                           (next observer x))))
                          (lambda ()
                            (push "source unsub" collector))))))
    (subscribe (skipuntil o
                          (observable (lambda (observer)
                                        (make-thread
                                         (lambda ()
                                           (sleep 0.015)
                                           (next observer "notify")
                                           (fail observer "fail")))
                                        (lambda ()
                                          (push "inner unsub" collector)))))
               (observer :onnext (lambda (value) (push value collector) (signal-semaphore semaphore))
                         :onfail (lambda (reason) (push reason collector))))
    (join-thread th)
    (is (equal (reverse collector) (list "inner unsub" 1 2 3)))))

(test skipuntil-inner-fail
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 1) (wait-on-semaphore semaphore :timeout 0.2)))))
         (collector)
         (o (observable (lambda (observer)
                          (make-thread (lambda ()
                                         (dotimes (x 4)
                                           (sleep 0.01)
                                           (next observer x))))
                          (lambda ()
                            (push "source unsub" collector))))))
    (subscribe (skipuntil o
                          (observable (lambda (observer)
                                        (make-thread
                                         (lambda ()
                                           (sleep 0.015)
                                           (fail observer "fail")))
                                        (lambda ()
                                          (push "inner unsub" collector)))))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector) (signal-semaphore semaphore))))
    (join-thread th)
    (is (equal (reverse collector) (list "fail" "source unsub" "inner unsub")))))

(test tail
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (tail o) (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 4)))))

(test tail-precidate
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (tail o (lambda (value) (< value 3))) (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 2)))))

(test tail-no-exist-fail
  (let ((o (of 1 2 3 4))
        (collector))
    (handler-case
        (subscribe (tail o (lambda (value) (> value 4)))
                   (observer :onnext (lambda (value) (push value collector))
                             :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))))
      (error (reason) (declare (ignorable reason)) (push "handle error" collector)))
    (is (equal (reverse collector) (list "fail")))))

(test tail-precidate-default
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (tail o (lambda (value) (> value 4)) "default")
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))))
    (is (equal (reverse collector) (list "default")))))

(test take
  (let ((o (of 1 2 3 4))
        (collector))
    (subscribe (take o 2)
               (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 1 2)))))

(test take-automatically-unsubscribe
  (let* ((end)
         (collector)
         (semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 1) (wait-on-semaphore semaphore :timeout 0.2)))))
         (o (observable (lambda (observer)
                          (make-thread (lambda ()
                                         (loop for x from 0
                                            while (not end)
                                            do (next observer x)
                                              (sleep 0.005))))
                          (lambda ()
                            (setf end t)
                            (push "source unsub" collector)
                            (signal-semaphore semaphore))))))
    (subscribe (take o 2)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (join-thread th)
    (is (equal (reverse collector) (list 0 1 "over" "source unsub")))))

(test throttle
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x (+ 6 3 3)) (wait-on-semaphore semaphore :timeout 0.2)))))
         (collector)
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                              (dotimes (x 6)
                                (push (format nil "gen ~A" x) collector)
                                (next observer x)
                                (signal-semaphore semaphore)
                                (sleep 0.05))))
               (lambda () (push "source unsub" collector)))))
         (times)
         (subscription
          (subscribe
           (throttle
            o
            (lambda (x)
              (push (format nil "receive ~A" x) collector)
              (observable (lambda (observer)
                            (let ((end))
                              (make-thread (lambda ()
                                             (loop for x from 0 to 100
                                                while (not end)
                                                do (sleep 0.06)
                                                  (push (format nil "send ~A" x) collector)
                                                  (next observer x))))
                              (lambda ()
                                (push (format nil "unsub ~A" x) collector)
                                (setf end t)
                                (signal-semaphore semaphore)))))))
           (lambda (value)
             (push value collector)
             (push (get-internal-real-time) times)
             (signal-semaphore semaphore)))))
    (join-thread th)
    (unsubscribe subscription)
    (is (equal (reverse collector) (list "gen 0" 0 "receive 0" "gen 1" "send 0" "unsub 0"
                                         "gen 2" 2 "receive 2" "gen 3" "send 0" "unsub 2"
                                         "gen 4" 4 "receive 4" "gen 5" "send 0" "unsub 4"
                                         "source unsub")))
    (is (>= (gaptop times (lambda (x y) (< x y))) (* 0.06 1000)))))

(test throttle-inner-automatically-unsubscribe
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 1)
                              (next observer (+ x 1)))
                            (lambda ()
                              (push (format nil "inner unsub ~A" val) collector)))))))
    (subscribe (throttle o observablefn)
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 10 "inner unsub 10"
                                         20 "inner unsub 20"
                                         30 "inner unsub 30")))))

(test throttle-over-inner-not-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (declare (ignorable observer))
                            (lambda ()
                              (push (format nil "inner unsub ~A" val) collector)))))))
    (subscribe (throttle o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 10
                                         "over"
                                         "source unsub"
                                         "inner unsub 10")))))

(test throttletime
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 4) (wait-on-semaphore semaphore :timeout 0.2)))))
         (o (observable
             (lambda (observer)
               (make-thread (lambda ()
                                 (dotimes (x 7) (sleep 0.01)
                                          (next observer x)))))))
         (collector)
         (times))
    (subscribe (throttletime o 20)
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
                                          (next observer x)))))))
         (collector))
    (subscribe (throttle o (lambda (v)
                             (declare (ignorable v))
                             (observable
                              (lambda (observer)
                                (make-thread (lambda ()
                                               (dotimes (x 0)
                                                 (sleep 0.02)
                                                 (next observer x))))))))
               (lambda (value) (push value collector) (signal-semaphore semaphore)))
    (join-thread th)
    (is (equal (reverse collector) (list 0)))))

;; transformation operators
(test flatmap
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (dotimes (x 3)
                                      (next observer (+ x 1)))
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val))))))
    (unsubscribe (subscribe (flatmap o observablefn)
                            (observer :onnext (lambda (value) (push value collector))
                                      :onover (lambda () (push "over" collector)))))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33
                                         "source unsub"
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30")))))

(test flatmap-concurrent-0
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1)))))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val))))))))
    (subscribe (flatmap o observablefn 0)
               (lambda (value) (push value collector)))
    (is (eq (length collector) 0))))

(test flatmap-concurrent-limit-stuck
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1)))))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val))))))))
    (subscribe (flatmap o observablefn 2)
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23)))))

(test flatmap-concurrent-limit-unstuck
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1)))))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val)))
                            (over observer))))))
    (subscribe (flatmap o observablefn 2)
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33)))))

(test flatmap-inner-fail
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (if (eq val 30)
                                (fail observer "fail"))
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val)))
                            (lambda ()
                                (push (format nil "inner unsub ~A" val) collector)))))))
    (subscribe (flatmap o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         "fail"
                                         "source unsub"
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30")))))

(test flatmap-inner-fail-immediately
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val)))
                            (fail observer "fail")
                            (lambda ()
                                (push (format nil "inner unsub ~A" val) collector)))))))
    (subscribe (flatmap o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list 11 12 13
                                         "fail"
                                         "source unsub"
                                         "inner unsub 10")))))

(test flatmap-over-inner-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val)))
                            (over observer)
                            (lambda ()
                                (push (format nil "inner unsub ~A" val) collector)))))))
    (subscribe (flatmap o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 11 12 13
                                         "inner unsub 10"
                                         21 22 23
                                         "inner unsub 20"
                                         31 32 33
                                         "inner unsub 30"
                                         "over"
                                         "source unsub")))))

(test flatmap-over-inner-not-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (observable
                          (lambda (observer)
                            (dotimes (x 3)
                              (next observer (+ (+ x 1) val)))
                            (lambda ()
                              (push (format nil "inner unsub ~A" val) collector))))))
         (subscription (subscribe (flatmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "over" collector))))))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33)))
    (unsubscribe subscription)
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33
                                         "source unsub"
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30")))))

(test flatmap-take-inner-fail
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (take (observable
                                (lambda (observer) 
                                  (dotimes (x 3)
                                    (next observer (+ (+ x 1) val))
                                    (if (eq (+ x 1) 3) (fail observer "fail"))) 
                                  (lambda ()
                                    (push (format nil "inner unsub ~A" val) collector))))
                               2))))
    (subscribe (flatmap o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list 11 12 "inner unsub 10"
                                         21 22 "inner unsub 20"
                                         31 32 "inner unsub 30")))))

(test mapper
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (next observer x)))))
        (collector))
    (subscribe (mapper o (lambda (x) (+ x 100))) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 100 101 102 103 104 105 106 107 108 109)))))

(test mapto
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (next observer x)))))
        (collector))
    (subscribe (mapto o 100) (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 100 100 100 100 100 100 100 100 100 100)))))

(test switchmap
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (dotimes (x 3)
                                      (next observer (+ x 1)))
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val)))))
         (subscription (subscribe (switchmap o observablefn)
                                  (lambda (value) (push value collector)))))
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33)))
    (unsubscribe subscription)
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33
                                         "source unsub"
                                         "inner unsub 30")))))

(test switchmap-over-inner-not-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (dotimes (x 3)
                                      (next observer (+ x 1))) 
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val)))))
         (subscription (subscribe (switchmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "over" collector))))))
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33)))
    (unsubscribe subscription)
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33
                                         "source unsub"
                                         "inner unsub 30")))))

(test switchmap-over-inner-over
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer) 
                                    (dotimes (x 3)
                                      (next observer (+ x 1)))
                                    (over observer)
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val))))))
    (subscribe (switchmap o observablefn)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33 "inner unsub 30"
                                         "over"
                                         "source unsub")))))

(test switchmap-inner-fail
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (dotimes (x 3)
                                      (next observer (+ x 1)))
                                    (fail observer "fail")
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val)))))
         (subscription (subscribe (switchmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onfail (lambda (reason) (push reason collector))))))
    (is (equal (reverse collector) (list 11 12 13
                                         "fail"
                                         "source unsub"
                                         "inner unsub 10")))
    (unsubscribe subscription)
    (is (equal (reverse collector) (list 11 12 13
                                         "fail"
                                         "source unsub"
                                         "inner unsub 10")))))
