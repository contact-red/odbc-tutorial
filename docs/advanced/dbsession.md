# Async with DbSession

Up to this point we've used `Connection` directly — a `ref` object, non-sendable, synchronous. Fine for a script-shaped program. Awkward in a multi-actor program: only one actor can own the connection, and every call blocks its scheduler thread for the ODBC call's duration.

`DbSession` is an actor that wraps a `Connection` and exposes its operations as behaviours. Each behaviour takes a `Promise` that's fulfilled when the operation completes.

```pony
actor DbSession
  new create(dsn: Dsn, validate_utf8: Bool = true)

  be exec(sql: String val,
    promise: Promise[(RowCount | ExecError)])

  be query(sql: String val,
    promise: Promise[(Array[Row val] val | ExecError)])

  be begin(promise: Promise[(TxBegun | TxBeginError)])
  be commit(promise: Promise[(TxCommitted | TxCommitError)])
  be rollback(promise: Promise[(TxRolledBack | TxRollbackError)])

  be close()
```

Shape follows `Connection` one-for-one, with two differences:

- Results come back through `Promise`s, not synchronous returns.
- `query` returns *all* rows as a sendable `Array[Row val] val` rather than a non-sendable `Cursor`.

`Cursor` and `Statement` are `ref` — unsendable. So `DbSession.query` buffers the whole result set into memory. For very large result sets that's the wrong trade; build an actor per query with the cursor private. For ordinary sets it's simpler and good enough.

## What DbSession doesn't expose

`prepare` isn't a behaviour, and neither is `Statement`: a `Statement` is tied to its `Connection` and can't be sent out. If you need prepared statements inside an actor, build a custom actor that owns its own `Connection` and `Statement`s privately.

## A chained workflow

Promises compose. The sample does DROP → CREATE → INSERT → SELECT → DROP, each step triggered by the previous promise's fulfillment:

```pony
--8<-- "11-dbsession/main.pony"
```

```shell
./build/11-dbsession
```

```text
drop: 0 rows
create: 0 rows
insert: 2 rows
1 alpha
2 bravo
cleanup: 0 rows
```

## Why pass promises in, rather than returning them?

Behaviours take a `Promise` as a parameter rather than returning one. Two properties this buys you:

- Callers decide the promise type — `Promise[Result]`, or `Promise[MyCustomType]` populated via `.next[MyCustomType]` before the behaviour completes.
- The handoff is visible: `let p = Promise[...]; db.exec(sql, p)` reads more clearly than a chained fluent call.

Minor, but worth recognising when you chain behaviours.

## Closing down cleanly

`close()` is a behaviour — queued after any outstanding work. Send it last and the connection shuts down once the final operation's promise is fulfilled.

The sample's `_after_cleanup` does exactly that: it fires the final `close()` after the last DROP's promise resolves, so the session processes its queue in order and exits.
