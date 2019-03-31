(defsystem aria
  :depends-on (:atomics
               :bordeaux-threads)
  :pathname "src/"
  :in-order-to ((test-op (test-op "aria-test")))
  :components
  ((:module "asynchronous" :depends-on ("structure")
            :components
            ((:file "scheduler")
             (:file "timer" :depends-on ("scheduler"))))
   (:module "concurrency"
            :components
            ((:file "caslock")))
   (:module "control" :depends-on ("concurrency" "structure")
            :components
            ((:file "rx" :depends-on ("rx-module"))
             (:module "rx-module"
                      :pathname "rx"
                      :components
                      ((:file "common")
                       (:file "inner-subscriber" :depends-on ("observable" "subscriber"))
                       (:file "interface")
                       (:file "observable")
                       (:file "observer" :depends-on ("common"))
                       (:file "operators" :depends-on ("operators-module"))
                       (:file "outer-subscriber" :depends-on ("common" "interface" "observable" "observer" "subscriber"))
                       (:file "subject" :depends-on ("interface" "observer"))
                       (:file "subscriber" :depends-on ("common" "observable" "observer" "subscription"))
                       (:file "subscription" :depends-on ("common"))
                       (:module "util" :depends-on ("inner-subscriber" "observable" "observer" "outer-subscriber" "subject" "subscriber")
                                :components
                                ((:file "buffer")
                                 (:file "operation")
                                 (:file "operator")
                                 (:file "subscribe")))
                       (:module "operators-module" :depends-on ("common" "util")
                                :pathname "operators"
                                :components
                                ((:file "creation" :depends-on ("creation-module"))
                                 (:module "creation-module"
                                          :pathname "creation"
                                          :components
                                          ((:file "empty")
                                           (:file "from")
                                           (:file "of")
                                           (:file "range")
                                           (:file "start")
                                           (:file "thrown")))
                                 (:file "error-handling" :depends-on ("error-handling-module"))
                                 (:module "error-handling-module"
                                          :pathname "error-handling"
                                          :components
                                          ((:file "catcher")
                                           (:file "retry")
                                           (:file "retryuntil" :depends-on ("retry"))
                                           (:file "retrywhen" :depends-on ("retry"))
                                           (:file "retrywhile" :depends-on ("retry"))))
                                 (:file "filtering" :depends-on ("filtering-module"))
                                 (:module "filtering-module"
                                          :pathname "filtering"
                                          :components
                                          ((:file "debounce")
                                           (:file "distinct")
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
                                           (:file "takeuntil")
                                           (:file "takewhile")
                                           (:file "tap" :depends-on ("tapnext"))
                                           (:file "tapfail")
                                           (:file "tapnext")
                                           (:file "tapover")
                                           (:file "throttle")
                                           (:file "throttletime")))
                                 (:file "transformation" :depends-on ("transformation-module"))
                                 (:module "transformation-module"
                                          :pathname "transformation"
                                          :components
                                          ((:file "buffer")
                                           (:file "buffercount")
                                           (:file "concatmap" :depends-on ("flatmap"))
                                           (:file "concatmapto" :depends-on ("flatmap"))
                                           (:file "exhaustmap")
                                           (:file "expand")
                                           (:file "flatmap")
                                           (:file "groupby")
                                           (:file "mapper")
                                           (:file "mapto")
                                           (:file "reducer")
                                           (:file "scan")
                                           (:file "switchmap")
                                           (:file "window")
                                           (:file "windowcount" :depends-on ("window"))))))))))
   (:module "structure"
            :components
            ((:file "interface")
             (:file "mimo-queue" :depends-on ("interface" "queue" "miso-queue"))
             (:file "miso-queue" :depends-on ("interface" "queue"))
             (:file "pair-heap" :depends-on ("interface"))
             (:file "queue" :depends-on ("interface"))
             (:file "ring" :depends-on ("interface"))))))
