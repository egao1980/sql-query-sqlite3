(defsystem "sql-query-sqlite3"
  :version "0.1.0"
  :description "sql-query dialect backend — SQLite3"
  :author "egao1980"
  :license "MIT"
  :depends-on ("sql-query")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "extensions")
               (:file "dialect"))
  :in-order-to ((test-op (test-op "sql-query-sqlite3/tests"))))

(defsystem "sql-query-sqlite3/tests"
  :depends-on ("sql-query-sqlite3"
               "sql-backend-sqlite3"
               "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "helpers")
               (:file "sqlite3-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
