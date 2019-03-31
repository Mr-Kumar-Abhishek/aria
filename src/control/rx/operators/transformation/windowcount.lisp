(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.windowcount
  (:use :cl)
  (:use :aria.control.rx.util.operator)
  (:import-from :aria.structure.ring
                :ring
                :en
                :de
                :size
                :tolist)
  (:import-from :aria.control.rx.operators.transformation.window
                ::window
                ::create-window
                ::source
                ::next
                ::fail
                ::over)
  (:export :windowcount))

(in-package :aria.control.rx.operators.transformation.windowcount)

(defmethod windowcount ((self observable) (count integer) &optional (overlap count))
  "count will be set to 0 when < 0
   overlap will be set to count when <= 0"
  (unless (>= count 0)
    (setf count 0))
  (unless (> overlap 0)
    (setf overlap count))
  (operator self
            (lambda (subscriber)
              (let* ((size 0)
                     (windows (ring count))
                     (caslock (caslock)))
                (observer :onnext
                          (lambda (value)
                            (let ((toopen)
                                  (toclose)
                                  (cache))
                              (with-caslock caslock
                                (incf size)
                                (if (and (not (eq 0 overlap))
                                         (eq 0 (mod (- size 1) overlap)))
                                    (progn (setf toopen (create-window))
                                           (en windows toopen)))
                                (setf cache (tolist windows)))
                              (if toopen (notifynext subscriber (source toopen)))
                              (map nil (lambda (window) (next window value)) cache)
                              (with-caslock caslock
                                (unless (< size count)
                                  (decf size overlap)
                                  (setf toclose (de windows))))
                              (if toclose (over toclose))))
                          :onfail (on-notifyfail subscriber)
                          :onover
                          (lambda ()
                            (let ((cache))
                              (with-caslock caslock
                                (setf cache (tolist windows)))
                              (map nil (lambda (window) (over window)) cache)
                              (notifyover subscriber))))))))
