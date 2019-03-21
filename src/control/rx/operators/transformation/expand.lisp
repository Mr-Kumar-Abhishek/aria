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
                                                      (notifyover inner)
                                                      (let ((needover)
                                                            (buffer))
                                                        (with-caslock caslock
                                                          (if (and isstop (emptyp buffers) (<= active 1))
                                                              (setf needover t))
                                                          (if (emptyp buffers)
                                                              (decf active)
                                                              (setf buffer (de buffers))))
                                                        (if needover (notifyover subscriber))
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
                            (let ((needover))
                              (with-caslock caslock
                                (setf isstop t)
                                (if (and (emptyp buffers) (eq active 0))
                                    (setf needover t)))
                              (if needover (notifyover subscriber)))))))))
