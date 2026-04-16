# Connecting

Every ODBC program starts by asking a driver manager to open a connection. The Pony entry point is the `Odbc` primitive and its single method, `connect`.

## The smallest program

```pony
--8<-- "01-connect/main.pony"
```

Three things to notice.

### `Dsn` is a distinct type

`Dsn("DSN=psqlred")` wraps the connection string in a `val` class. That distinction exists so connection strings — which often contain credentials — can't be accidentally confused with ordinary `String` values that might get logged or returned to users. The library never renders a `Dsn` in error messages; it redacts everything that came from driver-supplied diagnostics too.

### `Odbc.connect` returns a union

```pony
fun connect(dsn: Dsn, validate_utf8: Bool = true): (Connection | ConnectError)
```

There's no exception, no partial function, no `None` — just a union. You match on it. On success you get a `Connection`; on failure a `ConnectError`.

The `validate_utf8` argument defaults to `true` and keeps a safety check on text columns. Setting it to `false` skips that validation — faster, but only safe if you control the data source.

### `Connection.close()` is idempotent

You can call it multiple times. You can also skip calling it — the library has a `_final()` safety net — but explicit `close()` is strongly preferred. It flushes any in-flight transaction with a rollback (we'll get to that in the [Transactions](../transactions/index.md) section) and releases the underlying `SQLHDBC` and `SQLHENV` handles immediately.

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

Pass a different DSN name as the first argument if you named yours something other than `psqlred`:

```shell
./build/01-connect my_dsn
```

## What a failure looks like

Try a DSN that doesn't exist:

```shell
./build/01-connect definitely_not_a_real_dsn
```

You'll see:

```text
connect: ConnectError: driver connect failed [IM002]
```

That's the *redacted* form of the error. The library won't put the driver's raw message into `.string()` because it could contain credentials. When you actually need to see what the driver said (for debugging, not for user-facing output), you call `e.unsafe_diag()` — covered in [Errors and Diagnostics](../errors/diagnostics.md).

## What's next

A connection on its own does nothing. The next page [Executing Statements](exec.md) introduces `exec()` — the simplest way to run SQL.
