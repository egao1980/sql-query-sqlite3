# sql-query-sqlite3

SQLite3 **dialect backend** for [`sql-query`](https://github.com/egao1980/sql-query) (cl-stack).

**Version:** `0.2.0` (requires `sql-query` ≥ 0.2.0 for insert/trigger/lock hooks).  
Separate project — same pattern as `sql-protocol` / `sql-backend-*`.

```lisp
(asdf:load-system "sql-query-sqlite3")
(asdf:load-system "sql-backend-sqlite3")   ; connectivity, optional

(compile-sql
 (select (columns :id) (from :users) (where (:= :active 1)))
 :dialect (sql-query-sqlite3:make-sqlite3-dialect))
```

Registers dialect `:sqlite3` (`?` params), JSON1 / datetime type+op seeds, and:

| Constructor | SQL |
|-------------|-----|
| `insert-or` / `replace-into` | `INSERT OR REPLACE\|IGNORE\|…` / `REPLACE INTO` |
| `on-conflict` | SQLite `ON CONFLICT DO NOTHING\|UPDATE` (+ `returning`) |

Rejected on this dialect (`sql-dialect-unsupported`): CREATE/DROP/ALTER TYPE & DOMAIN, CREATE PROCEDURE / CALL, and Postgres-only extensions (COPY, matviews, partitions) when those constructors are used.

Brief: [sql.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/sql.md).

## License

MIT — see [LICENSE](LICENSE).
