# Reusing Statements

The point of preparing is to reuse. A single `Statement` can be executed many times — bind new values to the parameters, run it again, repeat. For a batch insert of a thousand rows, that's one prepare and a thousand executes instead of a thousand parse-and-plan cycles.

## The reuse pattern

Two operations control the lifecycle:

- **Rebind and re-execute** — after an `execute_update()`, the statement is back in the "ready to bind" state. Just bind new values and execute again.
- **`close_cursor()`** — after an `execute()` (SELECT), the statement has an open cursor. Call `close_cursor()` to close it and return to the "ready to bind" state, so you can bind and execute again.

## A batch of inserts, followed by a SELECT

The sample below prepares an INSERT, executes it three times with different values, then prepares a SELECT, executes it, and iterates:

```pony
--8<-- "06-prepared-reuse/main.pony"
```

Running it:

```shell
./build/06-prepared-reuse
```

Output:

```text
1 alpha
2 bravo
3 charlie
```

## What to notice

### Binding a parameter marks it dirty

The library keeps track of which parameters have been bound since the last execute. On re-execute after a rebind, only the changed parameters are pushed to the driver — an optimisation that matters when parameters carry large text or binary values.

In practice this is invisible to you. Just bind every parameter that needs to change and call execute.

### Partial variants make batches terse

The loop uses the partial `_p` variants:

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

One `try/else` around each iteration. If any step errors, the else branch reports it and the loop moves on to the next item. If you want the loop to abort on any error, wrap the whole `for` in a single `try`.

The trade-off: the `else` branch doesn't know *which* error fired. For a loop of identical inserts that's usually fine; the value of the item tells you enough. When you need the error kind, use the non-partial `bind()` / `execute_update()` and match on the union.

### `close_cursor()` vs `close()`

Two different operations on `Statement`:

- `close_cursor()` — closes any open cursor, unbinds columns, leaves the statement ready to bind and re-execute. Use this when you want to iterate a SELECT and then run the same statement again (or just start a fresh bind cycle).
- `close()` — frees the underlying `SQLHSTMT`. Idempotent. After this the statement is done; you can't use it again.

The sample calls `close_cursor()` after iterating the SELECT, then `close()` when it's done with the statement entirely.

### Prepare once, use many — but only on the same connection

`Statement` is tied to the `Connection` it was prepared on. If you close the connection, the statement is useless. And because both `Connection` and `Statement` are `ref` (non-sendable), you can't send a prepared statement to another actor to reuse it there.

For cross-actor reuse the pattern is different: either each actor owns its own `DbSession` and prepares its own statements, or you funnel all database work through a single actor that owns the connection. The [`DbSession`](../advanced/dbsession.md) advanced chapter shows the second pattern.
