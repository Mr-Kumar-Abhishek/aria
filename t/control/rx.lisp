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
                :end)
  (:import-from :aria.control.rx
                :observable
                :observer
                :subject
                :subscriberp
                :onnext
                :onfail
                :onover
                :next
                :fail
                :over
                :subscribe
                :unsubscribe
                :isunsubscribed
                :pipe
                :with-pipe)
  ;; creation operators
  (:import-from :aria.control.rx
                :empty
                :from
                :of
                :range
                :start
                :thrown)
  ;; error-handling operators
  (:import-from :aria.control.rx
                :catcher
                :retry
                :retryuntil
                :retrywhen
                :retrywhile)
  ;; filtering operators
  (:import-from :aria.control.rx
                :distinct
                :debounce
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
                :tap
                :tapfail
                :tapnext
                :tapover
                :throttle
                :throttletime)
  ;; transformation operators
  (:import-from :aria.control.rx
                :buffer
                :buffercount
                :concatmap
                :concatmapto
                :exhaustmap
                :expand
                :flatmap
                :groupby
                :mapper
                :mapto
                :reducer
                :scan
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

(test subscriberp
  (let ((o (observable
             (lambda (observer)
               (declare (ignorable observer))))))
    (is (subscriberp (subscribe o (observer :onnext (lambda (value) value)))))))

(test subscriber-manually-unsubscribe
  (let* ((event)
         (collector)
         (o (observable
             (lambda (observer)
               (setf event (lambda () (next observer "next")))
               (lambda () (push "unsub" collector))))))
    (unsubscribe (subscribe o (observer :onnext (lambda (value) (push value collector))
                                        :onfail (lambda (reason) (declare (ignorable reason)) (push "fail" collector))
                                        :onover (lambda () (push "over" collector)))))
    (is (equal (reverse collector) (list "unsub")))
    (funcall event)
    (is (equal (reverse collector) (list "unsub")))))

(test subscriber-automatically-unsubscribe-onover
  (let* ((collector)
         (o (observable
             (lambda (observer)
               (over observer)
               (lambda () (push "unsub" collector))))))
    (subscribe o (observer :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list "over" "unsub")))))

(test subscriber-automatically-unsubscribe-onfail
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

(test observable-revolver-error-handler
  (let ((o (observable (lambda (observer)
                         (error "fail")
                         (next observer 0))))
        (collector))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onfail (lambda (reason) (push (simple-condition-format-control reason) collector))))
    (is (equal (reverse collector) (list "fail")))))

(test observable-next-error-handler
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

;; tools
(test pipe
  (let ((collector)
        (operation (pipe
                    (mapper (lambda (x) (+ x 1)))
                    (flatmap (lambda (val)
                               (funcall (pipe
                                         (mapper (lambda (x) (+ x (* 10 val)))))
                                        (of 1 2 3 4))))
                    (filter (lambda (x) (eq (mod x 2) 0)))))
        (o (of 0 1 2 3)))
    (subscribe (funcall operation o) (observer :onnext (lambda (value) (push value collector))
                                               :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 12 14
                                         22 24
                                         32 34
                                         42 44
                                         "over")))))

(test with-pipe
  (let ((collector)
        (o (with-pipe (of 0 1 2 3)
             (mapper (lambda (x) (+ x 1)))
             (flatmap (lambda (val)
                        (with-pipe (of 1 2 3 4)
                          (mapper (lambda (x) (+ x (* 10 val)))))))
             (filter (lambda (x) (eq (mod x 2) 0))))))
    (subscribe o (observer :onnext (lambda (value) (push value collector))
                           :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 12 14
                                         22 24
                                         32 34
                                         42 44
                                         "over")))))

;; creation operators

(test empty
  (let* ((o (empty))
         (collector)
         (subscriber (subscribe o (observer :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list "end")))
    (is (isunsubscribed subscriber))))

(test from
  (let* ((o (from "hello world"))
         (collector)
         (subscriber (subscribe o (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list #\h #\e #\l #\l #\o #\  #\w #\o #\r #\l #\d "end")))
    (is (isunsubscribed subscriber))))

(test of
  (let* ((o (of 1 2 3 "hi" "go"))
         (collector)
         (subscriber (subscribe o (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list 1 2 3 "hi" "go" "end")))
    (is (isunsubscribed subscriber))))

(test range
  (let* ((o (range 0 10))
         (collector)
         (subscriber (subscribe o (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list 0 1 2 3 4 5 6 7 8 9 "end")))
    (is (isunsubscribed subscriber))))

(test start
  (let* ((o (start (lambda () 0)))
         (collector)
         (subscriber (subscribe o (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list 0 "end")))
    (is (isunsubscribed subscriber))))

(test thrown
  (let* ((o (thrown "fail"))
         (collector)
         (subscriber (subscribe o (observer :onfail (lambda (reason) (push reason collector))
                                            :onover (lambda () (push "end" collector))))))
    (is (equal (reverse collector) (list "fail")))
    (is (isunsubscribed subscriber))))

;; error-handling operators
(test catcher
  (let* ((collector)
         (o (observable
             (lambda (observer)
               (next observer 0)
               (fail observer 1)
               (fail observer 2)
               (fail observer 3)))))
    (subscribe (catcher o (lambda (value)
                            (observable
                             (lambda (observer)
                               (next observer value)
                               (lambda ()
                                 (push (format nil "unsub ~A" value) collector))))))
               (observer :onnext (lambda (value) (push (format nil "next ~A" value) collector))
                         :onfail (lambda (reason) (push (format nil "fail ~A" reason) collector))))
    (is (equal (reverse collector) (list "next 0" "next 1" "unsub 1" "next 2" "unsub 2" "next 3")))))

(test retry
  (let* ((count 0)
         (collector)
         (o (observable
             (lambda (observer)
               (let ((copy count))
                 (incf count)
                 (push (format nil "sub ~A" copy) collector)
                 (fail observer copy)
                 (lambda ()
                   (push (format nil "unsub ~A" copy) collector)))))))
    (subscribe (with-pipe o
                 (tapfail (lambda (reason) (push reason collector)))
                 (retry 2))
               (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "sub 0" 0
                                         "sub 1" 1
                                         "sub 2" 2
                                         2
                                         "unsub 2"
                                         "unsub 1"
                                         "unsub 0")))))
(test retryuntil
  (let* ((count 0)
         (collector)
         (o (observable
             (lambda (observer)
               (let ((copy count))
                 (incf count)
                 (push (format nil "sub ~A" copy) collector)
                 (fail observer copy)
                 (lambda ()
                   (push (format nil "unsub ~A" copy) collector)))))))
    (subscribe (with-pipe o
                 (tapfail (lambda (reason) (push reason collector)))
                 (retryuntil (lambda (val) (>= val 2))))
               (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "sub 0" 0
                                         "sub 1" 1
                                         "sub 2" 2
                                         2
                                         "unsub 2"
                                         "unsub 1"
                                         "unsub 0")))))

(test retryuntil-observable
  (let* ((count 0)
         (collector)
         (event)
         (notifier (observable
                    (lambda (observer)
                      (setf event (lambda ()
                                    (unless (< count 2)
                                      (next observer nil))
                                    (incf count)))
                      (lambda ()
                        (push "unsub notifier" collector)))))
         (o (observable
             (lambda (observer)
               (let ((copy count))
                 (funcall event)
                 (push (format nil "sub ~A" copy) collector)
                 (fail observer copy)
                 (lambda ()
                   (push (format nil "unsub ~A" copy) collector)))))))
    (subscribe (with-pipe o
                 (tapfail (lambda (reason) (push reason collector)))
                 (retryuntil notifier))
               (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "sub 0" 0
                                         "sub 1" 1
                                         "sub 2" 2
                                         2
                                         "unsub notifier"
                                         "unsub 2"
                                         "unsub 1"
                                         "unsub 0")))))

(test retrywhile
  (let* ((count 0)
         (collector)
         (o (observable
             (lambda (observer)
               (let ((copy count))
                 (incf count)
                 (push (format nil "sub ~A" copy) collector)
                 (fail observer copy)
                 (lambda ()
                   (push (format nil "unsub ~A" copy) collector)))))))
    (subscribe (with-pipe o
                 (tapfail (lambda (reason) (push reason collector)))
                 (retrywhile (lambda (val) (< val 2))))
               (observer :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "sub 0" 0
                                         "sub 1" 1
                                         "sub 2" 2
                                         2
                                         "unsub 2"
                                         "unsub 1"
                                         "unsub 0")))))

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
    (subscribe (debounce o (lambda (value)
                             (declare (ignorable value))
                             (observable (lambda (observer)
                                           (settimeout timer (lambda () (next observer nil)) 20)))))
               (lambda (value) (push value collector) (signal-semaphore semaphore)))
    (join-thread th)
    (end timer)
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
    (is (equal (reverse collector) (list "over" "unsub sampler" "unsub source")))))

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
    (is (equal (reverse collector) (list "fail" "unsub sampler" "unsub source")))))

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
    (is (equal (reverse collector) (list "unsub sampler" "unsub source")))))

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
  (let ((collector)
        (o (of 1 2 3 4 5 6)))
    (subscribe (skipuntil o (lambda (value) (not (eq 0 (mod value 2)))))
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 2 4 6)))))

(test skipuntil-observable
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 4)
                            (next observer x))
                          (fail observer "source fail")
                          (lambda ()
                            (push "source unsub" collector))))))
    (subscribe (skipuntil o (observable (lambda (observer)
                                          (next observer 4)
                                          (lambda ()
                                            (push "inner unsub" collector)))))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "inner unsub" 0 1 2 3 "source fail" "source unsub")))))

(test skipuntil-observable-inner-fail
  (let* ((collector)
         (o (observable (lambda (observer)
                          (dotimes (x 4)
                            (next observer x))
                          (fail observer "source fail")
                          (lambda ()
                            (push "source unsub" collector))))))
    (subscribe (skipuntil o (observable (lambda (observer)
                                          (fail observer "inner fail")
                                          (lambda ()
                                            (push "inner unsub" collector)))))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector))))
    (is (equal (reverse collector) (list "inner fail" "inner unsub" "source unsub")))))

(test skipuntil-observable-async
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 4) (wait-on-semaphore semaphore :timeout 0.2)))))
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
                                          (push "inner unsub" collector)
                                          (signal-semaphore semaphore)))))
               (observer :onnext (lambda (value) (push value collector) (signal-semaphore semaphore))
                         :onfail (lambda (reason) (push reason collector))))
    (join-thread th)
    (is (equal (reverse collector) (list "inner unsub" 1 2 3)))))

(test skipuntil-observable-async-inner-fail
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 3) (wait-on-semaphore semaphore :timeout 0.2)))))
         (collector)
         (o (observable (lambda (observer)
                          (make-thread (lambda ()
                                         (dotimes (x 4)
                                           (sleep 0.01)
                                           (next observer x))))
                          (lambda ()
                            (push "source unsub" collector)
                            (signal-semaphore semaphore))))))
    (subscribe (skipuntil o
                          (observable (lambda (observer)
                                        (make-thread
                                         (lambda ()
                                           (sleep 0.015)
                                           (fail observer "fail")))
                                        (lambda ()
                                          (push "inner unsub" collector)
                                          (signal-semaphore semaphore)))))
               (observer :onnext (lambda (value) (push value collector))
                         :onfail (lambda (reason) (push reason collector) (signal-semaphore semaphore))))
    (join-thread th)
    (is (equal (reverse collector) (list "fail" "inner unsub" "source unsub")))))

(test skipwhile
  (let ((collector)
        (o (of 1 2 3 4 5 6)))
    (subscribe (skipwhile o (lambda (value) (eq 0 (mod value 2))))
               (lambda (value) (push value collector)))
    (is (equal (reverse collector) (list 2 4 6)))))

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


(test tap
  (let ((collector0)
        (collectornext)
        (collectorover)
        (collector1)
        (collectorfail)
        (o (range 0 10))
        (ofail (thrown 10)))
    (subscribe (tap o (observer :onnext (lambda (value) (push (* 2 value) collectornext) 100)
                                :onover (lambda () (push "tapover" collectorover))))
               (observer :onnext (lambda (value) (push value collector0))
                         :onover (lambda () (push "over" collector0))))
    (subscribe (tap ofail (observer :onfail (lambda (reason) (push (* 2 reason) collectorfail))))
               (observer :onfail (lambda (reason) (push reason collector1))))
    (is (equal (reverse collector0) (list 0 1 2 3 4 5 6 7 8 9 "over")))
    (is (equal (reverse collectornext) (list 0 2 4 6 8 10 12 14 16 18)))
    (is (equal (reverse collectorover) (list "tapover")))
    (is (equal (reverse collector1) (list 10)))
    (is (equal (reverse collectorfail) (list 20)))))

(test tap-function
  (let ((o (observable
            (lambda (observer)
              (dotimes (x 10) (next observer x)))))
        (collector0)
        (collector1))
    (subscribe (tap o (lambda (x) (push (* 2 x) collector0) 100)) (lambda (value) (push value collector1)))
    (is (equal (reverse collector0) (list 0 2 4 6 8 10 12 14 16 18)))
    (is (equal (reverse collector1) (list 0 1 2 3 4 5 6 7 8 9)))))

(test tapfail
  (let ((o (thrown "fail"))
        (collector0)
        (collector1))
    (subscribe (tapfail o (lambda (reason) (push (format nil "tap~A" reason) collector0)))
               (observer :onfail (lambda (reason) (push reason collector1))))
    (is (equal (reverse collector0) (list "tapfail")))
    (is (equal (reverse collector1) (list "fail")))))

(test tapnext
  (let ((o (range 0 5))
        (collector0)
        (collector1))
    (subscribe (tapnext o (lambda (x) (push (* 2 x) collector0) 100)) (lambda (value) (push value collector1)))
    (is (equal (reverse collector0) (list 0 2 4 6 8)))
    (is (equal (reverse collector1) (list 0 1 2 3 4)))))

(test tapover
  (let ((o (empty))
        (collector0)
        (collector1))
    (subscribe (tapover o (lambda () (push "tapover" collector0)))
               (observer :onover (lambda () (push "over" collector1))))
    (is (equal (reverse collector0) (list "tapover")))
    (is (equal (reverse collector1) (list "over")))))

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
         (subscriber
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
    (unsubscribe subscriber)
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
                                         "inner unsub 10"
                                         "source unsub")))))

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
(test buffer
  (let* ((collector)
         (event1)
         (event2)
         (event3)
         (o (observable (lambda (observer)
                          (push "source start" collector)
                          (let ((x 0)) (setf event1 (lambda () (next observer (incf x)))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (notifier (observable
                    (lambda (observer)
                      (push "inner start" collector)
                      (setf event2 (lambda () (next observer nil)))
                      (setf event3 (lambda () (over observer)))
                      (lambda ()
                        (push "inner unsub" collector))))))
    (subscribe (buffer o notifier)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (funcall event1) (funcall event1) (funcall event1) (funcall event2)
    (funcall event2)
    (funcall event1) (funcall event1) (funcall event2)
    (funcall event3)
    (is (equal (reverse collector) (list "inner start"
                                         "source start"
                                         '(1 2 3)
                                         nil
                                         '(4 5)
                                         "over"
                                         "inner unsub"
                                         "source unsub")))))

(test buffercount
  (let* ((collector)
         (o (of 0 1 2 3 4 5 6 7 8 9 10)))
    (subscribe (buffercount o 4 2)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list '(0 1 2 3)
                                         '(2 3 4 5)
                                         '(4 5 6 7)
                                         '(6 7 8 9)
                                         '(8 9 10)
                                         '(10)
                                         "over")))))

(test buffercount-lack
  (let* ((collector)
         (o (of 0 1 2 3)))
    (subscribe (buffercount o 5)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list '(0 1 2 3)
                                         "over")))))

(test concatmap
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 3) (wait-on-semaphore semaphore)))))
         (collector)
         (o (observable (lambda (observer)
                          (dotimes (x 3)
                            (next observer (* 10 (+ x 1))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (make-thread (lambda ()
                                                   (dotimes (x 3)
                                                     (next observer (+ x 1)))
                                                   (over observer)))
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector)
                                      (signal-semaphore semaphore))))
                                 (lambda (x) (+ x val)))))
         (subscriber (subscribe (concatmap o observablefn)
                                (observer :onnext (lambda (value) (push value collector))
                                          :onover (lambda () (push "over" collector))))))
    (join-thread th)
    (is (equal (reverse collector) (list 11 12 13  "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33 "inner unsub 30")))
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33 "inner unsub 30"
                                         "source unsub")))))

(test concatmapto
  (let* ((collector)
         (o (range 0 5)))
    (subscribe (concatmapto o (of 5 6))
               (observer :onnext (lambda (x) (push x collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 5 6 5 6 5 6 5 6 5 6 "over")))))

(test exhaustmap
  (let* ((collector)
         (event1)
         (event2)
         (event3)
         (o (observable (lambda (observer)
                          (let ((x 0))
                            (setf event1 (lambda () (next observer (* 10 (incf x))))))
                          (lambda ()
                            (push "source unsub" collector)))))
         (observablefn (lambda (val)
                         (mapper (observable
                                  (lambda (observer)
                                    (let ((x 0))
                                      (setf event2 (lambda () (next observer (incf x))))
                                      (setf event3 (lambda () (over observer))))
                                    (lambda ()
                                      (push (format nil "inner unsub ~A" val) collector))))
                                 (lambda (x) (+ x val)))))
         (subscriber (subscribe (exhaustmap o observablefn)
                                (observer :onnext (lambda (value) (push value collector))
                                          :onover (lambda () (push "over" collector))))))
    (funcall event1) (funcall event2) (funcall event1) (funcall event2)
    (funcall event3)
    (funcall event1) (funcall event2) (funcall event2)
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 "inner unsub 10"
                                         31 32
                                         "inner unsub 30"
                                         "source unsub")))))

(test expand
  (let* ((collector)
         (o (observable (lambda (observer)
                          (next observer 0)
                          (over observer)
                          (lambda ()
                            (push "source unsub" collector))))))
    (subscribe (expand o (lambda (value)
                           (observable (lambda (observer)
                                         (if (< value 5)
                                             (next observer (+ value 1)))
                                         (lambda ()
                                           (push (format nil "unsub ~A" value) collector))))))
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 1 2 3 4 5)))))

(test expand-over-by-take
  (let* ((collector)
         (o (of 0)))
    (subscribe (take (expand o (lambda (value) (of (+ value 1)))) 5)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 1 2 3 4 "over")))))

(test expand-async-over-by-take
  (let* ((semaphore (make-semaphore))
         (th (make-thread (lambda () (dotimes (x 5) (wait-on-semaphore semaphore)))))
         (timer (gen-timer))
         (collector)
         (o (observable (lambda (observer)
                          (next observer 0)
                          (lambda ()
                            (push "source unsub" collector)
                            (signal-semaphore semaphore))))))
    (subscribe (take (expand o (lambda (value)
                                 (observable (lambda (observer)
                                               (push (format nil "sub ~A" value) collector)
                                               (settimeout timer (lambda ()
                                                                   (next observer (+ value 1))))
                                               (lambda ()
                                                 (push (format nil "unsub ~A" value) collector)
                                                 (signal-semaphore semaphore))))))
                     4)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (join-thread th)
    (end timer)
    (is (equal (reverse collector) (list 0 "sub 0" 1 "sub 1" 2 "sub 2" 3 "over" "unsub 0" "unsub 1" "unsub 2" "source unsub" "sub 3" "unsub 3")))))

(test expand-concurrent-0
  (let* ((collector)
         (o (of 0)))
    (subscribe (expand o (lambda (value)
                           (observable (lambda (observer)
                                         (if (< value 5)
                                             (next observer (+ value 1))))))
                       0)
               (observer :onnext (lambda (value) (push value collector))))
    (is (eq (length collector) 0))))

(test expand-concurrent-limit-stuck
  (let* ((collector)
         (o (of 0)))
    (subscribe (expand o (lambda (value)
                           (observable (lambda (observer)
                                         (if (< value 5)
                                             (next observer (+ value 1))))))
                       1)
               (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 0)))))

(test expand-concurrent-limit-unstuck
  (let* ((collector)
         (o (of 0)))
    (subscribe (expand o (lambda (value)
                           (observable (lambda (observer)
                                         (if (< value 5)
                                             (next observer (+ value 1)))
                                         (over observer))))
                       1)
               (observer :onnext (lambda (value) (push value collector))))
    (is (equal (reverse collector) (list 0 1 2 3 4 5)))))

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
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30"
                                         "source unsub")))))

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
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30"
                                         "source unsub")))))

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
                                         "inner unsub 10"
                                         "source unsub")))))

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
         (subscriber (subscribe (flatmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "over" collector))))))
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33)))
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 13
                                         21 22 23
                                         31 32 33
                                         "inner unsub 10"
                                         "inner unsub 20"
                                         "inner unsub 30"
                                         "source unsub")))))

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

(test groupby
  (let* ((collector)
         (o (range 0 9)))
    (subscribe (with-pipe o
                 (groupby (lambda (value) (mod value 3)))
                 (flatmap (lambda (val) (buffercount val 3))))
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list '(0 3 6)
                                         '(1 4 7)
                                         '(2 5 8)
                                         "over")))))

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

(test reducer
  (let ((collector)
        (o (range 0 100)))
    (subscribe (reducer o (lambda (acc cur) (+ acc cur)) 0)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 4950 "over")))))

(test scan
  (let ((collector)
        (o (range 0 5)))
    (subscribe (scan o (lambda (acc cur) (+ acc cur)) 0)
               (observer :onnext (lambda (value) (push value collector))
                         :onover (lambda () (push "over" collector))))
    (is (equal (reverse collector) (list 0 1 3 6 10 "over")))))

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
         (subscriber (subscribe (switchmap o observablefn)
                                  (lambda (value) (push value collector)))))
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33)))
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33 "inner unsub 30"
                                         "source unsub")))))

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
         (subscriber (subscribe (switchmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onover (lambda () (push "over" collector))))))
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33)))
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 13 "inner unsub 10"
                                         21 22 23 "inner unsub 20"
                                         31 32 33 "inner unsub 30"
                                         "source unsub")))))

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
         (subscriber (subscribe (switchmap o observablefn)
                                  (observer :onnext (lambda (value) (push value collector))
                                            :onfail (lambda (reason) (push reason collector))))))
    (is (equal (reverse collector) (list 11 12 13
                                         "fail"
                                         "inner unsub 10"
                                         "source unsub")))
    (unsubscribe subscriber)
    (is (equal (reverse collector) (list 11 12 13
                                         "fail"
                                         "inner unsub 10"
                                         "source unsub")))))
