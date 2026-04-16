# Async with DbSession

Everything up to this point has used `Connection` directly — a `ref` object, non-sendable, synchronous. That's fine for a program that's basically a database script. For a Pony program built from multiple actors, it's awkward: only one actor can own the connection, and every call to the database blocks that actor's scheduler thread for the duration of the ODBC call.

`DbSession` is an actor that wraps a `Connection` and exposes its operations as behaviours. Each behaviour takes a `Promise` that gets fulfilled when the operation completes.

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

The shape follows the `Connection` API one-for-one, with two differences:

- Results come back through `Promise`s, not synchronous returns
- `query` returns *all* rows as a sendable `Array[Row val] val`, rather than a non-sendable `Cursor`

`Cursor` and `Statement` are `ref` — you can't send them. So `DbSession.query` fetches the whole result set into memory and gives you back a sendable array. For very large result sets that's the wrong trade-off; in that case you need a different structure (an actor per query, with the cursor owned privately). For ordinary result sets it's simpler and good enough.

## What DbSession doesn't expose

`prepare` isn't a behaviour. Neither is `Statement`. That's because a `Statement` is tied to its `Connection`, and you can't send the handle out of the actor where it lives. If you need prepared statements inside a `DbSession`, the model is: build a custom actor that inherits from `DbSession`'s design but manages its own `Statement`s privately.

## A chained workflow

Promises compose. The sample below does DROP → CREATE → INSERT → SELECT → DROP in order, with each step triggered by the previous promise's fulfillment:

```pony
--8<-- "11-dbsession/main.pony"
```

Running it:

```shell
./build/11-dbsession
```

Output:

```text
drop: 0 rows
create: 0 rows
insert: 2 rows
1 alpha
2 bravo
cleanup: 0 rows
```

## Why pass promises in, rather than returning them?

A small convention the library follows: behaviours take a `Promise` as a parameter rather than returning one. This looks odd at first (most promise-based APIs return the promise) but it has two nice properties:

- Callers can decide the promise type. You might want `Promise[Result]`, or a more specific `Promise[MyCustomType]` populated via `.next[MyCustomType]` before the behaviour completes.
- The callsite makes the promise-handoff visible: `let p = Promise[...]; db.exec(sql, p)` is more self-documenting than a chained fluent call.

It's a minor point but worth recognising when you're chaining behaviours.

## Closing down cleanly

`DbSession.close()` is a behaviour — it's queued after any outstanding work. Send it last in your pipeline and the connection shuts down cleanly once the final operation's promise has been fulfilled.

The sample's `_after_cleanup` behaviour does exactly that: it fires the last `close()` behaviour after the final `DROP`'s promise fulfils, so the session processes its queue in order and exits.
