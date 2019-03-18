(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.buffercount
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.ring
                :make-ring
                :en
                :size
                :tolist)
  (:export :buffercount))

(in-package :aria.control.rx.operators.transformation.buffercount)

(defmethod buffercount ((self observable) (count integer) &optional (overlap count))
  "overlap will be set to count when <= 0"
  (unless (> overlap 0)
    (setf overlap count))
  (operator self
            (lambda (subscriber)
              (let ((buffer (make-ring count))
                    (size 0)
                    (caslock (caslock))
                    (isover))
                (observer :onnext
                          (lambda (value)
                            (let ((needsend)
                                  (send))
                              (with-caslock caslock
                                (unless isover
                                  (incf size)
                                  (en buffer value)
                                  (unless (< size count)
                                    (setf needsend t)
                                    (setf send (tolist buffer))
                                    (decf size overlap))
                                  (if needsend
                                      (notifynext subscriber send))))))
                          :onfail (on-notifyfail subscriber)
                          :onover (lambda ()
                                    (with-caslock caslock
                                      (setf isover t))
                                    (let ((list (tolist buffer))
                                          (length (- count size)))
                                      (dotimes (drop (size buffer))
                                        (setf list (cdr list))
                                        (if (and (eq 0 (mod (- length drop 1) overlap))
                                                 list)
                                            (notifynext subscriber list))))
                                    (notifyover subscriber)))))))
