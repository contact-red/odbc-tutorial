# Executing

Once every parameter is bound, you run the statement. There are two ways to do that, and picking the right one matters.

## Two execute methods

```pony
fun ref execute():        (Executed | ExecError)   // opens a cursor
fun ref execute_update(): (RowCount | ExecError)   // reports affected rows
```

- `execute()` — for statements that produce a result set you're going to fetch. After a successful call the statement has an *open cursor* and you can iterate it with `fetch()` or `values()`.
- `execute_update()` — for DML (`INSERT`, `UPDATE`, `DELETE`) where you want the affected row count. Does not open a cursor.

Calling the wrong one isn't fatal — the library will catch it — but the shape of the return type tells you which one fits:

- If you're about to fetch rows → `execute()`
- If you just need "how many rows did that touch" → `execute_update()`

## `Executed` is a primitive

Successful `execute()` returns the `Executed` primitive, not the `Statement`. That's a small but deliberate design choice: after `execute()` the statement is in a distinct state (cursor open) with a different set of valid operations, and giving that state a name makes it visible in the code.

## A SELECT round-trip

Here's a fragment — the relevant bit of [sample 06](reuse.md):

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

`stmt.values()` returns a `StatementIterator` that's the same shape as the `CursorIterator` you saw in [Querying](../basics/querying.md) — yielding `Row` or `FetchError`, terminating on `EndOfRows`.

## ExecError during execute

The `ExecError` kinds you can see from a prepared statement's `execute()` / `execute_update()` are a superset of the ones from `Connection.exec()`:

| Kind | Means |
|------|-------|
| `QueryError` | General driver-reported SQL error |
| `ConstraintViolation` | SQLSTATE 23xxx — check/unique/foreign key etc. |
| `SyntaxError` | SQLSTATE 42xxx — bad SQL |
| `ConnectionLost` | SQLSTATE 08xxx — connection dropped mid-operation |
| `UnboundParams` | You called `execute` before binding every parameter |
| `StatementClosed` | You've already called `close()` on the statement |
| `ConnectionClosed` | The owning connection is closed |
| `CursorNotOpen` | Fetch called without a cursor (only from `fetch()`) |
| `CursorAlreadyOpen` | Second `execute()` without closing the previous cursor |

The library classifies driver errors into those kinds by SQLSTATE prefix. If you want to match on specific SQLSTATEs directly (for example, detecting deadlocks on MySQL's `40001`), use `e.unsafe_diag()` and inspect the raw chain — covered in [Reading Diagnostics](../errors/diagnostics.md).

## What's next

[Reusing Statements](reuse.md) puts `execute_update()`, `execute()`, and `close_cursor()` together to show how prepared statements pay for themselves on batches.
