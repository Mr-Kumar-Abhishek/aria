(defsystem aria-test
  :depends-on (:fiveam
               :bordeaux-threads
               :atomics
               :aria)
  :pathname "t/"
  :perform (test-op (o c)
                    (symbol-call :aria-test '#:run-all-tests))
  :components
  ((:file "test" :depends-on ("test-interface"))
   (:file "test-interface")
   (:module "asynchronous"
            :depends-on ("test")
            :components
            ((:file "scheduler")
             (:file "timer")))
   (:module "control"
            :depends-on ("test")
            :components
            ((:file "rx")))))
