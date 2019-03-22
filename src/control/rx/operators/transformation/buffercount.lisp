(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.buffercount
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.ring
                :ring
                :en
                :size
                :tolist)
  (:export :buffercount))

(in-package :aria.control.rx.operators.transformation.buffercount)

(defmethod buffercount ((self observable) (count integer) &optional (overlap count))
  "count will be set to 0 when < 0
   overlap will be set to count when <= 0"
  (unless (>= count 0)
    (setf count 0))
  (unless (> overlap 0)
    (setf overlap count))
  (operator self
            (lambda (subscriber)
              (let ((buffer (ring count))
                    (size 0)
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (let ((needsend)
                                  (send))
                              (with-caslock caslock
                                (incf size)
                                (en buffer value)
                                (unless (< size count)
                                  (setf needsend t)
                                  (setf send (tolist buffer))
                                  (decf size overlap)))
                              (if needsend
                                  (notifynext subscriber send))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (let* ((list (tolist buffer))
                                           (buffersize (size buffer))
                                           (lack (if (> count buffersize)
                                                     0
                                                     (- count size))))
                                      (dotimes (drop buffersize)
                                        (let ((acc (- lack drop)))
                                          (if (and list
                                                   (not (eq acc overlap))
                                                   (eq 0 (mod acc overlap)))
                                              (notifynext subscriber list)))
                                        (setf list (cdr list))))
                                    (notifyover subscriber)))))))
