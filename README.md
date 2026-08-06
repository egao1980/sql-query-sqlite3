# sql-query-sqlite3

SQLite3 **dialect backend** for [`sql-query`](https://github.com/egao1980/sql-query) (cl-stack).

Separate project — same pattern as `sql-protocol` / `sql-backend-*`.

```lisp
(asdf:load-system "sql-query-sqlite3")
(asdf:load-system "sql-backend-sqlite3")   ; connectivity, optional

(compile-sql
 (select (columns :id) (from :users) (where (:= :active 1)))
 :dialect (sql-query-sqlite3:make-sqlite3-dialect))
```

Registers dialect `:sqlite3` and seeds JSON1 / datetime types, ops, and helpers (`json-extract`, `strftime`, …).

Brief: [sql.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/sql.md).

## License

MIT — see [LICENSE](LICENSE).
