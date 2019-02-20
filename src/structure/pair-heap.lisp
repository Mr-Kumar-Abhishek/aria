(in-package :cl-user)

(defpackage aria.structure.pair-heap
  (:use :cl)
  (:import-from :atomics
                :atomic-update)
  (:export :heap
           :make-queue
           :en
           :de
           :queue-empty-p
           :find-top))

(in-package :aria.structure.pair-heap)
