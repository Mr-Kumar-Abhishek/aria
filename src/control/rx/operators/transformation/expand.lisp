(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.expand
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.queue
                :queue
                :en
                :de
                :emptyp)
  (:export :expand))

(in-package :aria.control.rx.operators.transformation.expand)

(defmethod expand ((self observable) (observablefn function) &optional (concurrent -1))
  (operator self
            (lambda (subscriber)
              (let ((isstop)
                    (buffers (queue))
                    (caslock (caslock))
                    (active 0))
                (observer :onnext
                          (lambda (value)
                            (flet ((lazysub ()
                                     (lambda ()
                                       (notifynext subscriber value)
                                       (within-inner-subscriber
                                        (funcall observablefn value)
                                        subscriber
                                        (lambda (inner)
                                          (observer :onnext (onnext subscriber)
                                                    :onfail (onfail subscriber)
                                                    :onover
                                                    (lambda ()
                                                      (let ((buffer))
                                                        (with-caslock caslock
                                                          (notifyover inner)
                                                          (if (and isstop (emptyp buffers) (<= active 1))
                                                              (notifyover subscriber))
                                                          (if (emptyp buffers)
                                                              (decf active)
                                                              (setf buffer (de buffers))))
                                                        (if buffer (funcall buffer))))))))))
                              (let ((immediate))
                                (with-caslock caslock
                                  (if (or (< active concurrent)
                                          (< concurrent 0))
                                      (progn (setf immediate t)
                                             (incf active))
                                      (en buffers (lazysub))))
                                (if immediate
                                    (funcall (lazysub))))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (with-caslock caslock
                              (setf isstop t)
                              (if (and (emptyp buffers) (eq active 0))
                                  (notifyover subscriber)))))))))
