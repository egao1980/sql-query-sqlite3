(defpackage #:sql-query-sqlite3
  (:use #:cl #:sql-query)
  (:shadowing-import-from #:sql-query #:count #:union)
  (:export #:sqlite3-dialect
           #:make-sqlite3-dialect
           #:use-sqlite3-dialect
           #:register-sqlite3-extensions
           #:json-extract #:json-object #:json-array #:json-set
           #:strftime #:datetime #:unixepoch
           ;; vendor SQL
           #:insert-or #:insert-or-clause #:replace-into
           #:on-conflict #:on-conflict-clause
           #:register-sqlite3-vendor-extensions))

(in-package #:sql-query-sqlite3)
