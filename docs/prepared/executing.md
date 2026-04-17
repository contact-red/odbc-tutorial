# Executing

Once the parameters are bound, run the statement. Two ways, and picking the right one matters.

## Two execute methods

```pony
fun ref execute():        (Executed | ExecError)   // opens a cursor
fun ref execute_update(): (RowCount | ExecError)   // reports affected rows
```

- `execute()` — for statements with a result set to fetch. On success the statement has an *open cursor*, iterated with `fetch()` or `values()`.
- `execute_update()` — for DML where you want the affected row count. No cursor.

Calling the wrong one isn't fatal (the library catches it), but the return type is the signal:

- About to fetch rows → `execute()`
- Just need a row count → `execute_update()`

## `Executed` is a primitive

Successful `execute()` returns the `Executed` primitive, not the `Statement`. After `execute()` the statement is in a distinct state (cursor open) with different valid operations; naming the state makes that visible.

## A SELECT round-trip

A fragment from [sample 06](reuse.md):

```pony
match \exhaustive\ conn.prepare(
  "SELECT id, label FROM tut_reuse ORDER BY id")
| let stmt: Statement =>
  match \exhaustive\ stmt.execute()
  | Executed =>
    for result in stmt.values() do
      match \exhaustive\ result
      | let row: Row => // ...
      | let e: FetchError => // ...
      end
    end
    stmt.close_cursor()
  | let e: ExecError =>
    env.err.print("execute: " + e.string())
  end
  stmt.close()
| let e: PrepareError =>
  env.err.print("prepare: " + e.string())
end
```

`stmt.values()` returns a `StatementIterator` — same shape as the `CursorIterator` from [Querying](../basics/querying.md): yields `Row` or `FetchError`, stops on `EndOfRows`.

## ExecError kinds

The `ExecError` kinds from a prepared statement's `execute()` / `execute_update()` are a superset of those from `Connection.exec()`:

| Kind | Means |
|------|-------|
| `QueryError` | General driver-reported SQL error |
| `ConstraintViolation` | SQLSTATE 23xxx — check/unique/FK |
| `SyntaxError` | SQLSTATE 42xxx — bad SQL |
| `ConnectionLost` | SQLSTATE 08xxx — dropped mid-operation |
| `UnboundParams` | Execute before binding every parameter |
| `StatementClosed` | Statement already `close()`d |
| `ConnectionClosed` | Owning connection is closed |
| `CursorNotOpen` | Fetch without a cursor (from `fetch()` only) |
| `CursorAlreadyOpen` | Second `execute()` without closing the cursor |

Kinds are classified by SQLSTATE prefix. To match specific SQLSTATEs directly (e.g. MySQL's `40001` for deadlocks), use `e.unsafe_diag()` — see [Reading Diagnostics](../errors/diagnostics.md).

## What's next

[Reusing Statements](reuse.md) puts `execute_update()`, `execute()`, and `close_cursor()` together on a batch.
