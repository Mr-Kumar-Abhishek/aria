(defsystem aria-test
  :depends-on (:aria)
  :pathname "t/"
  :perform (test-op (o c)
                    (symbol-call :aria-test '#:run-all-tests))
  :components
  ((:file "test")))
