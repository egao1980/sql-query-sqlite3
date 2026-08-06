(defpackage #:sql-query-sqlite3/tests
  (:use #:cl #:rove #:sql-query #:sql-query-sqlite3)
  (:shadowing-import-from #:sql-query #:count #:union)
  (:export #:%sql #:%params #:%compile #:%has #:%norm
           #:%assert-contains #:%assert-absent))

(in-package #:sql-query-sqlite3/tests)
