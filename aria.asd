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
   (:module "control" :depends-on ("concurrency" "structure")
            :components
            ((:file "rx" :depends-on ((:module "rx")))
             (:module "rx"
                      :components
                      ((:file "common")
                       (:file "inner-subscriber" :depends-on ("subscriber"))
                       (:file "observable")
                       (:file "observer" :depends-on ("common"))
                       (:file "operators" :depends-on ("operators"))
                       (:file "outer-subscriber" :depends-on ("common" "observer" "subscriber"))
                       (:file "subject" :depends-on ("observer"))
                       (:file "subscriber" :depends-on ("common" "observer" "subscription"))
                       (:file "subscription" :depends-on ("common"))
                       (:module "util" :depends-on ("inner-subscriber" "observable" "observer" "outer-subscriber" "subject" "subscriber")
                                :components
                                ((:file "buffer")
                                 (:file "operation")
                                 (:file "operator")
                                 (:file "subscribe")))
                       (:module "operators" :depends-on ("common" "util")
                                :components
                                ((:file "creation" :depends-on ((:module "creation")))
                                 (:module "creation"
                                          :components
                                          ((:file "empty")
                                           (:file "from")
                                           (:file "of")
                                           (:file "range")
                                           (:file "thrown")))
                                 (:file "filtering" :depends-on ("filtering"))
                                 (:module "filtering"
                                          :components
                                          ((:file "debounce")
                                           (:file "distinct")
                                           (:file "each")
                                           (:file "filter")
                                           (:file "head")
                                           (:file "ignores")
                                           (:file "sample")
                                           (:file "single")
                                           (:file "skip")
                                           (:file "skipuntil")
                                           (:file "skipwhile")
                                           (:file "tail")
                                           (:file "take")
                                           (:file "throttle")
                                           (:file "throttletime")))
                                 (:file "transformation" :depends-on ("transformation"))
                                 (:module "transformation"
                                          :components
                                          ((:file "flatmap")
                                           (:file "mapper")
                                           (:file "mapto")
                                           (:file "switchmap")))))))))))
