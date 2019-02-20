(defsystem aria
  :depends-on (:atomics)
  :pathname "src/"
  :in-order-to ((test-op (test-op "aria-test")))
  :components
  ((:module "structure"
            :components
            ((:file "miso-queue")
             (:file "pair-heap")))))
