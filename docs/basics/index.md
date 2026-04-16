# The Basics

This section walks through the smallest useful programs you can write against the library.

Everything here uses the synchronous, ref-based API — you call methods directly on a `Connection`, a `Cursor`, or a `Statement`. Once you're comfortable with the shape, the [Advanced](../advanced/dbsession.md) section covers the async actor wrapper.

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

Every branch of every union is something you handle. That's the library's core design choice: errors are values, not exceptions, and the compiler helps you see every case.

Onward:

1. [Connecting](connecting.md) — establishing and closing a `Connection`
2. [Executing Statements](exec.md) — `exec()` for DDL and simple DML
3. [Querying](querying.md) — `query()`, `Cursor`, and iteration
4. [Reading Rows](rows.md) — typed accessors and `SqlNull`
5. [SQL Types](sqltypes.md) — the full `SqlValue` union
