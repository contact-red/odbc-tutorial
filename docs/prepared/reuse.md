# Reusing Statements

The point of preparing is to reuse. A single `Statement` can execute many times: rebind, run, repeat. For a batch insert of a thousand rows, that's one prepare and a thousand executes instead of a thousand parse-and-plans.

## The reuse pattern

Two operations drive the lifecycle:

- **Rebind and re-execute** — after `execute_update()`, the statement is back in "ready to bind". Bind new values and execute again.
- **`close_cursor()`** — after `execute()` (SELECT) the statement has an open cursor. `close_cursor()` closes it and returns to "ready to bind".

## A batch of inserts, followed by a SELECT

The sample prepares an INSERT, executes it three times, then prepares a SELECT and iterates:

```pony
--8<-- "06-prepared-reuse/main.pony"
```

```shell
./build/06-prepared-reuse
```

```text
1 alpha
2 bravo
3 charlie
```

## What to notice

### Binding marks a parameter dirty

The library tracks which parameters have been rebound since the last execute and only pushes changed ones to the driver — matters when parameters carry large text or binary. Invisible to callers: just bind what changes and execute.

### Partial variants make batches terse

```pony
for (id, label) in items.values() do
  try
    stmt.bind_p(ParamIndex(1), SqlInteger(id))?
    stmt.bind_p(ParamIndex(2), SqlText(label))?
    stmt.execute_update_p()?
  else
    env.err.print("insert " + id.string() + " failed")
  end
end
```

One `try/else` per iteration. Any step erroring drops into `else`; the loop moves on. Wrap the whole `for` in a single `try` to abort the batch on first failure.

Trade-off: the `else` branch doesn't know *which* error fired. For identical inserts the item value tells you enough. When you need the kind, use the non-partial `bind()` / `execute_update()`.

### `close_cursor()` vs `close()`

- `close_cursor()` — closes any open cursor, unbinds columns, leaves the statement ready to bind and re-execute.
- `close()` — frees the `SQLHSTMT`. Idempotent. After this the statement is done.

The sample calls `close_cursor()` after the SELECT loop, then `close()` when done.

### Prepare once, use many — but only on the same connection

`Statement` is tied to the `Connection` it was prepared on. Close the connection and the statement is useless. Both are `ref` (non-sendable), so you can't send a prepared statement across actors.

For cross-actor reuse: either each actor owns its own `DbSession` and prepares its own statements, or you funnel all database work through a single actor owning the connection. [`DbSession`](../advanced/dbsession.md) shows the second pattern.
