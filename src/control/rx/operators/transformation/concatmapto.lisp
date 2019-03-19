(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.concatmapto
  (:use :cl)
  (:import-from :aria.control.rx.operators.transformation.flatmap
                :flatmap)
  (:use :aria.control.rx.util.operator)
  (:export :concatmapto))

(in-package :aria.control.rx.operators.transformation.concatmapto)

(defmethod concatmapto ((self observable) (observable observable))
  (flatmap self (lambda (value) (declare (ignorable value)) observable) 1))
