(in-package :cl-user)

(defpackage aria.control.rx.util.operation
  (:use :cl)
  (:import-from :aria.control.rx.observable
                :observable)
  (:export :pipe
           :with-pipe
           :operation
           :combine))

(in-package :aria.control.rx.util.operation)

(defmacro operation (operator rest)
  (let ((observable (gensym "observable")))
    `(lambda (,observable)
       (,operator ,observable ,@rest))))

(defmethod combine ((self function) (operation function))
  (lambda (observable)
    (funcall operation (funcall self observable))))

(defmethod combine ((self null) (operation function))
  (declare (ignorable self))
  operation)

(defmacro pipe (&rest rest)
  (let ((x (car `,rest))
        (y (cdr `,rest)))
    `(pipe-reduce nil ,x ,y)))

(defmacro pipe-reduce (acc cur rest)
  (let* ((operator (car `,cur))
         (arglist (cdr `,cur))
         (end (eq `,rest nil))
         (nextacc `(combine ,acc (operation ,operator ,arglist)))
         (nextcur (car `,rest))
         (nextrest (cdr `,rest)))
    (if end
       nextacc
       `(pipe-reduce ,nextacc ,nextcur ,nextrest))))

(defmacro with-pipe (observable &rest rest)
  `(funcall (pipe ,@rest) ,observable))
