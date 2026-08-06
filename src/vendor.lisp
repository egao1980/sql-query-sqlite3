(in-package #:sql-query-sqlite3)

;;; ---------------------------------------------------------------------------
;;; SQLite vendor AST — INSERT OR … / REPLACE INTO / ON CONFLICT
;;; ---------------------------------------------------------------------------

(defclass insert-or-clause (sql-extension sql-clause)
  ((action :initarg :action :reader insert-or-action
           :documentation ":replace | :rollback | :abort | :fail | :ignore")))

(defun insert-or (action)
  "INSERT OR REPLACE|IGNORE|… modifier clause for insert-into."
  (unless (member action '(:replace :rollback :abort :fail :ignore))
    (error 'sql-query-error
           :message (format nil "insert-or expects :replace/:rollback/:abort/:fail/:ignore, got ~s"
                            action)))
  (make-instance 'insert-or-clause :action action))

(defun replace-into (table &rest clauses)
  "REPLACE INTO — sugar for INSERT OR REPLACE INTO."
  (apply #'insert-into table (insert-or :replace) clauses))

;;; Shared ON CONFLICT (SQLite-compatible subset)

(defclass on-conflict-clause (sql-extension sql-clause)
  ((target :initarg :target :reader on-conflict-target :initform nil)
   (action :initarg :action :reader on-conflict-action :initform :nothing)
   (set :initarg :set :reader on-conflict-set :initform nil)
   (where :initarg :where :reader on-conflict-where :initform nil)))

(defun on-conflict (&key target (action :nothing) set where)
  "INSERT … ON CONFLICT [(cols)] DO NOTHING|UPDATE SET … (SQLite)."
  (unless (member action '(:nothing :update))
    (error 'sql-query-error
           :message (format nil "on-conflict :action expects :nothing or :update, got ~s" action)))
  (when (and (eq action :update) (null set))
    (error 'sql-query-error :message "on-conflict :update requires :set"))
  (make-instance 'on-conflict-clause
                 :target (when target
                           (mapcar #'ensure-expr (if (listp target) target (list target))))
                 :action action
                 :set (when set
                        (mapcar (lambda (a)
                                  (cond
                                    ((typep a 'binary-op) a)
                                    ((and (consp a) (= 2 (length a)))
                                     (:= (first a) (second a)))
                                    (t (error 'sql-query-error
                                              :message (format nil "bad on-conflict :set ~s" a)))))
                                (if (and (consp set) (not (typep set 'sql-node))
                                         (or (typep (first set) 'binary-op)
                                             (and (consp (first set)) (= 2 (length (first set))))))
                                    set
                                    (list set))))
                 :where (when where (ensure-expr where))))

(defmethod emit-insert-prefix ((dialect sqlite3-dialect) stmt stream ctx)
  (declare (ignore ctx))
  (let ((ior (find-if (lambda (c) (typep c 'insert-or-clause))
                      (statement-clauses stmt))))
    (if ior
        (progn
          (write-string "INSERT OR " stream)
          (write-string (ecase (insert-or-action ior)
                          (:replace "REPLACE")
                          (:rollback "ROLLBACK")
                          (:abort "ABORT")
                          (:fail "FAIL")
                          (:ignore "IGNORE"))
                        stream)
          (write-string " INTO " stream))
        (write-string "INSERT INTO " stream))))

(defmethod emit-sql ((dialect sqlite3-dialect) (clause on-conflict-clause) stream ctx)
  (write-string " ON CONFLICT" stream)
  (when (on-conflict-target clause)
    (write-string " (" stream)
    (emit-column-list dialect (on-conflict-target clause) stream ctx)
    (write-char #\) stream))
  (ecase (on-conflict-action clause)
    (:nothing (write-string " DO NOTHING" stream))
    (:update
     (write-string " DO UPDATE SET " stream)
     (loop for (a . rest) on (on-conflict-set clause)
           do (emit-sql dialect (binary-op-left a) stream ctx)
              (write-string " = " stream)
              (emit-sql dialect (binary-op-right a) stream ctx)
              (when rest (write-string ", " stream)))
     (when (on-conflict-where clause)
       (write-string " WHERE " stream)
       (emit-sql dialect (on-conflict-where clause) stream ctx)))))

(defmethod emit-insert-extras ((dialect sqlite3-dialect) stmt stream ctx)
  (let ((oc (find-if (lambda (c) (typep c 'on-conflict-clause))
                     (statement-clauses stmt))))
    (when oc
      (emit-sql dialect oc stream ctx))))

;;; Reject common Postgres-only extension nodes if shared constructors appear

(defmethod emit-sql ((dialect sqlite3-dialect) (stmt sql-extension) stream ctx)
  "Fallback: reject unknown sql-extension nodes cleanly."
  (declare (ignore stream ctx))
  (let ((name (class-name (class-of stmt))))
    (error 'sql-dialect-unsupported
           :feature name
           :dialect dialect
           :message (format nil "SQLite does not support ~s" name))))

;; More-specific methods above win for on-conflict-clause / insert-or-clause.
;; Explicit rejects for known PG-only symbols that might be interned via make-sql-extension:

(defun %sqlite-reject-pg (feature message)
  (lambda (&rest args)
    (declare (ignore args))
    (error 'sql-dialect-unsupported
           :feature feature
           :dialect (or *sql-dialect* (make-sqlite3-dialect))
           :message message)))

(defun register-sqlite3-vendor-extensions ()
  (register-sql-extension :insert-or #'insert-or :kind :node
                          :documentation "INSERT OR REPLACE|IGNORE|…")
  (register-sql-extension :replace-into
                          (lambda (table &rest clauses)
                            (apply #'replace-into table clauses))
                          :kind :statement)
  (register-sql-extension :on-conflict #'on-conflict :kind :node)
  ;; PG-only: register stubs that signal unsupported if accidentally used
  (dolist (pair '((:copy-table "SQLite has no COPY")
                  (:create-materialized-view "SQLite has no materialized views")
                  (:drop-materialized-view "SQLite has no materialized views")
                  (:refresh-materialized-view "SQLite has no materialized views")
                  (:partition-by "SQLite has no table partitioning")
                  (:create-table-partition-of "SQLite has no table partitioning")))
    (destructuring-bind (name msg) pair
      (unless (find-sql-extension name)
        (register-sql-extension name (%sqlite-reject-pg name msg) :kind :statement))))
  t)

(register-sqlite3-vendor-extensions)
