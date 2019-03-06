(defsystem aria
  :depends-on (:atomics
               :bordeaux-threads)
  :pathname "src/"
  :in-order-to ((test-op (test-op "aria-test")))
  :components
  ((:module "structure"
            :components
            ((:file "queue")
             (:file "miso-queue" :depends-on ("queue"))
             (:file "mimo-queue" :depends-on ("queue" "miso-queue"))
             (:file "pair-heap")))
   (:module "asynchronous" :depends-on ("structure")
            :components
            ((:file "scheduler")
             (:file "timer" :depends-on ("scheduler"))))
   (:module "concurrency"
            :components
            ((:file "caslock")))
   (:module "control" :depends-on ("concurrency")
            :components
            ((:file "rx")))))
