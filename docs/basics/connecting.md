# Connecting

Every ODBC program starts by asking a driver manager to open a connection. The Pony entry point is `Odbc.connect`.

## The smallest program

```pony
--8<-- "01-connect/main.pony"
```

Three things to notice.

### `Dsn` is a distinct type

`Dsn("DSN=psqlred")` wraps the connection string in a `val` class. The point: connection strings often contain credentials, so they can't be accidentally confused with `String` values that might get logged or surfaced to users. The library never renders a `Dsn` in error messages and redacts driver-supplied diagnostics too.

### `Odbc.connect` returns a union

```pony
fun connect(dsn: Dsn, validate_utf8: Bool = true): (Connection | ConnectError)
```

No exception, no partial function, no `None` — just a union. Match on it.

`validate_utf8 = true` keeps a safety check on text columns. Setting it to `false` is faster but only safe if you trust the data source.

### `Connection.close()` is idempotent

Safe to call multiple times. A `_final()` safety net catches forgotten closes, but explicit is preferred: `close()` rolls back any in-flight transaction (see [Transactions](../transactions/index.md)) and releases the `SQLHDBC` and `SQLHENV` handles immediately.

## Running it

From `code-samples/`:

```shell
corral run -- ponyc -o build 01-connect
./build/01-connect
```

Output:

```text
Connected to psqlred
Closed.
```

Pass a different DSN name as `argv[1]` if yours isn't `psqlred`:

```shell
./build/01-connect my_dsn
```

## What a failure looks like

```shell
./build/01-connect definitely_not_a_real_dsn
```

```text
connect: ConnectError: driver connect failed [IM002]
```

That's the *redacted* form. The driver's raw message can contain credentials, so `.string()` never includes it. For debugging, use `e.unsafe_diag()` — see [Errors and Diagnostics](../errors/diagnostics.md).

## What's next

A connection on its own does nothing. [Executing Statements](exec.md) introduces `exec()`.
