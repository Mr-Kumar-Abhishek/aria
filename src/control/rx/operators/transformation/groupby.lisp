(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.groupby
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:export :groupby))

(in-package :aria.control.rx.operators.transformation.groupby)

(defmethod groupby ((self observable) (keyselector function))
  (operator self
            (lambda (subscriber)
              (let ((nexts (make-hash-table))
                    (overs (make-hash-table))
                    (obs (make-hash-table))
                    (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (let* ((key (funcall keyselector value))
                                   (ob (gethash key obs)))
                              (if ob
                                  (funcall (gethash key nexts) value)
                                  (progn (setf ob
                                               (observable (lambda (observer)
                                                             (next observer value)                                 
                                                             (with-caslock caslock
                                                               (setf (gethash key nexts) (lambda (value) (next observer value)))
                                                               (setf (gethash key overs) (lambda () (over observer)))))))
                                         (setf (gethash key obs) ob)
                                         (notifynext subscriber ob)))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (let ((overlist))
                              (with-caslock caslock
                                (setf overlist (loop for val being the hash-values of overs collect val)))
                              (map nil (lambda (over) (funcall over)) overlist))
                            (notifyover subscriber)))))))
