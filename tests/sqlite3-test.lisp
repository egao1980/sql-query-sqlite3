(in-package #:sql-query-sqlite3/tests)

(deftest ddl-sqlite-backend
  (let* ((d (make-sqlite3-dialect))
         (ct (create-table :users
                (column :id :type :integer :primary-key t :autoincrement t)
                (column :name :type '(:varchar 255) :not-null t)))
         (sql (nth-value 0 (compile-sql ct :dialect d))))
    (ok (search "AUTOINCREMENT" sql))
    (ok (search "TEXT" sql))))

(deftest procedure-sqlite-unsupported
  (let ((stmt (create-procedure :bump
                 (params (in :by :integer))
                 (body (sql-fragment "UPDATE counters SET n = n + ?" 1)))))
    (ok (signals (compile-sql stmt :dialect (make-sqlite3-dialect))
                 'sql-dialect-unsupported))))

(deftest execute-roundtrip-sqlite
  (sql-protocol:with-connection (c :driver :sqlite3 :database-name ":memory:")
    (execute-query c (create-table :users
                        (column :id :type :integer :primary-key t :autoincrement t)
                        (column :name :type :text :not-null t))
                   :dialect (make-sqlite3-dialect))
    (execute-query c (insert-into :users (columns :name) (sql-values "ada"))
                   :dialect (make-sqlite3-dialect))
    (execute-query c (insert-into :users (columns :name) (sql-values "grace"))
                   :dialect (make-sqlite3-dialect))
    (let ((rows (fetch-all-query
                 c (select (columns :name)
                           (from :users)
                           (where (sql-like :name "%a%"))
                           (order-by :name))
                 :dialect (make-sqlite3-dialect))))
      (ok (equal 2 (length rows)))
      (ok (equal "ada" (getf (first rows) :name))))))

(deftest dialect-registry
  (ok (typep (gethash :sqlite3 sql-query:*sql-dialect-registry*)
             'sqlite3-dialect)))

(deftest sqlite-types-json-datetime
  (let ((d (make-sqlite3-dialect)))
    (ok (string= "TEXT" (dialect-type-sql d :json)))
    (ok (string= "TEXT" (dialect-type-sql d :timestamptz)))
    (ok (string= "BLOB" (dialect-type-sql d :bson)))
    (let ((sql (%sql (select
                      (columns (json-extract :doc "$.name")
                               (strftime "%Y-%m-%d" :created)
                               (unixepoch)
                               (json-object "a" 1)
                               (ensure-expr '(:->> :doc "$.x")))
                      (from :t))
                     d)))
      (%assert-contains sql
                        "json_extract" "strftime" "unixepoch" "json_object"
                        "->>"))))

(deftest sqlite-func-registry
  (let ((d (make-sqlite3-dialect)))
    (ok (find-sql-func d :json-set))
    (%assert-contains (%sql (select (columns (sql-func :json-array-length :doc)) (from :t)) d)
                      "json_array_length(")))
