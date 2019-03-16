(in-package :cl-user)

(defpackage aria.control.rx.operators.transformation.concatmap
  (:use :cl)
  (:import-from :aria.control.rx.operators.transformation.flatmap
                :flatmap)
  (:use :aria.control.rx.util.operator)
  (:export :concatmap))

(in-package :aria.control.rx.operators.transformation.concatmap)

(defmethod concatmap ((self observable) (observablefn function))
  "not guarantee order when parallel"
  (flatmap self observablefn 1))
