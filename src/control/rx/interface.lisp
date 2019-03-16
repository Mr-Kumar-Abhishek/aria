(in-package :cl-user)

(defpackage aria.control.rx.interface
  (:use :cl)
  (:export :subscribe))

(in-package :aria.control.rx.interface)

(defgeneric subscribe (self observer))
