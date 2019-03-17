(in-package :cl-user)

(defpackage aria.structure.interface
  (:use :cl)
  (:export :de
           :en
           :ren
           :rde
           :size
           :emptyp))

(in-package :aria.structure.interface)

(defgeneric en (self value))

(defgeneric de (self))

(defgeneric enr (self value))

(defgeneric der (self))

(defgeneric size (self))

(defgeneric emptyp (self))
