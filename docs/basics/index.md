# The Basics

The smallest useful programs you can write against the library.

Everything here uses the synchronous, ref-based API — calls go directly against a `Connection`, `Cursor`, or `Statement`. The [Advanced](../advanced/dbsession.md) section covers the async actor wrapper.

The call graph at a glance:

```text
Odbc.connect(Dsn(...))    → Connection | ConnectError
  Connection.exec(sql)    → RowCount | NoRowCount | ExecError
  Connection.query(sql)   → Cursor | ExecError
    Cursor.fetch()        → Row | EndOfRows | FetchError
    Cursor.values()       → iterator yielding (Row | FetchError)
  Connection.prepare(sql) → Statement | PrepareError
    Statement.bind(i, v)  → Bound | BindError
    Statement.execute()   → Executed | ExecError           (SELECT)
    Statement.execute_update() → RowCount | ExecError      (DML)
    Statement.fetch()     → Row | EndOfRows | FetchError
  Connection.close()
```

Every branch is something you handle: errors are values, not exceptions, and the compiler helps you see every case.

1. [Connecting](connecting.md) — establishing and closing a `Connection`
2. [Executing Statements](exec.md) — `exec()` for DDL and simple DML
3. [Querying](querying.md) — `query()`, `Cursor`, iteration
4. [Reading Rows](rows.md) — typed accessors and `SqlNull`
5. [SQL Types](sqltypes.md) — the full `SqlValue` union
