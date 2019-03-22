(in-package :cl-user)

(defpackage aria.control.rx.util.operator
  (:use :cl)
  (:import-from :aria.concurrency.caslock
                :caslock
                :with-caslock
                :with-caslock-once)
  (:export :caslock
           :with-caslock
           :with-caslock-once)
  (:import-from :aria.control.rx.inner-subscriber
                :inner-subscriber
                :subscribe-subscriber)
  (:import-from :aria.control.rx.observable
                :observable)
  (:import-from :aria.control.rx.outer-subscriber
                :outer-subscriber
                :subscribe-subscriber)
  (:import-from :aria.control.rx.subscriber
                :connect
                :unsubscribe)
  (:export :operator
           :within-inner-subscriber)
  (:import-from :aria.control.rx.inner-subscriber
                :notifynext
                :notifyfail
                :notifyover
                :unsubscribe)
  (:import-from :aria.control.rx.observer
                :observer)
  (:import-from :aria.control.rx.outer-subscriber
                :notifynext
                :notifyfail
                :notifyover
                :before
                :after)
  (:import-from :aria.control.rx.subscriber
                :subscriber
                ::isstop
                :next
                :fail
                :over
                :onnext
                :onfail
                :onover
                :on-notifynext
                :on-notifyfail
                :on-notifyover
                :unsubscribe)
  (:export :subscriber
           ::isstop
           :observable
           :observer
           :next
           :fail
           :over
           :onnext
           :onfail
           :onover
           :notifynext
           :notifyfail
           :notifyover
           :on-notifynext
           :on-notifyfail
           :on-notifyover
           :before
           :after
           :unsubscribe))

(in-package :aria.control.rx.util.operator)

(defmethod operator ((self observable) (pass function))
  (observable (lambda (observer)
                (let ((subscriber (outer-subscriber observer)))
                  (connect subscriber (funcall pass subscriber)) (format t "~%sub ~A" subscriber)
                  (subscribe-subscriber self subscriber)
                  (lambda ()
                    (unsubscribe subscriber))))))

(defmethod within-inner-subscriber ((self observable) (parent subscriber) (pass function))
  (let* ((subscriber (inner-subscriber parent))
         (observer (funcall pass subscriber)))
    (subscribe-subscriber self (connect subscriber observer))
    subscriber))

