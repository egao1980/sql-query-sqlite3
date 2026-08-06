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

(deftest type-ddl-sqlite-unsupported
  (let ((d (make-sqlite3-dialect)))
    (ok (signals (compile-sql (create-type :euros :as :numeric) :dialect d)
                 'sql-dialect-unsupported))
    (ok (signals (compile-sql (drop-type :euros) :dialect d)
                 'sql-dialect-unsupported))
    (ok (signals (compile-sql (create-domain :posint :as :integer) :dialect d)
                 'sql-dialect-unsupported))
    (ok (signals (compile-sql (alter-type :t (add-attribute :x :text)) :dialect d)
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

;;; ---- Vendor SQL gaps ----

(deftest sqlite-insert-or-replace
  (let* ((d (make-sqlite3-dialect))
         (sql (%sql (insert-into :users (insert-or :replace)
                                 (columns :id :name) (sql-values 1 "ada"))
                    d)))
    (%assert-contains sql "INSERT OR REPLACE INTO")))

(deftest sqlite-replace-into
  (let ((sql (%sql (replace-into :users (columns :id) (sql-values 1)))))
    (%assert-contains sql "INSERT OR REPLACE INTO")))

(deftest sqlite-on-conflict
  (let* ((d (make-sqlite3-dialect))
         (nothing (%sql (insert-into :t (columns :a) (sql-values 1)
                                     (on-conflict :target '(:a) :action :nothing))
                        d))
         (upd (%sql (insert-into :t (columns :a :b) (sql-values 1 2)
                                 (on-conflict :target '(:a)
                                              :action :update
                                              :set (list (:= :b 2)))
                                 (returning :a))
                    d)))
    (%assert-contains nothing "ON CONFLICT" "DO NOTHING")
    (%assert-contains upd "ON CONFLICT" "DO UPDATE SET" "RETURNING")
    (ok (< (search "ON CONFLICT" upd) (search "RETURNING" upd)))))

(deftest sqlite-rejects-pg-only-extensions
  (ok (signals (make-sql-extension :copy-table :users)
               'sql-dialect-unsupported))
  (ok (signals (make-sql-extension :create-materialized-view :mv
                                   (select (columns :id) (from :t)))
               'sql-dialect-unsupported))
  (ok (signals (make-sql-extension :partition-by :range :id)
               'sql-dialect-unsupported)))

(deftest sqlite-vendor-extension-registry
  (ok (find-sql-extension :insert-or))
  (ok (find-sql-extension :on-conflict))
  (ok (typep (insert-or :ignore) 'insert-or-clause)))
