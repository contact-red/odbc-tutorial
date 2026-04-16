# Binding Parameters

A prepared statement has one or more *parameter markers* — the `?` characters in SQL like `INSERT INTO t VALUES (?, ?)`. Binding a parameter is the act of associating a value with a marker, identified by a 1-based index.

## The bind method

```pony
fun ref bind(i: ParamIndex, v: SqlValue): (Bound | BindError)
```

The index is a `ParamIndex` — a small wrapper over `U16`. Like `ColIndex`, it exists to keep 1-based index arithmetic from silently mixing with other numeric values.

The value is a `SqlValue` — any of the variants covered in [SQL Types](../basics/sqltypes.md). You construct one with the variant's class:

```pony
SqlBool(true)
SqlTinyInt(12)
SqlSmallInt(1000)
SqlInteger(1_000_000)
SqlBigInt(9_000_000_000)
SqlFloat(3.14159)
SqlText("hello")
SqlDate(2026, 4, 16)
SqlTime(9, 30, 0)
SqlTimestamp(2026, 4, 16, 9, 30, 0)
SqlDecimal("1234.5678")
SqlNull
```

On success, `bind` returns the `Bound` primitive. On failure, a `BindError` with a `kind` field you can match on.

## BindError kinds

| Kind | Meaning |
|------|---------|
| `ParamIndexOutOfRange` | The index was zero or greater than the statement's parameter count |
| `ParamTooLarge` | Value exceeded the maximum bind size (rare; mostly for oversize strings) |
| `DriverRejected` | The ODBC driver rejected the bind call |
| `BindStatementClosed` | The statement has been `close()`d |
| `BindConnectionClosed` | The connection has been `close()`d |

Every `BindError` also carries the `ParamIndex` that failed — `e.param_index()` — which makes it easy to point at the culprit in a batch.

## A complete example

```pony
--8<-- "05-prepared-bind/main.pony"
```

Running it:

```shell
./build/05-prepared-bind
```

Output:

```text
inserted 1 row
```

## `bind_null` as a convenience

Binding `SqlNull` works:

```pony
stmt.bind(ParamIndex(3), SqlNull)
```

If you find yourself doing that a lot, there's `bind_null`:

```pony
stmt.bind_null(ParamIndex(3))
```

Identical effect; just slightly less typing and slightly more obvious intent.

## Partial variants

As with every non-trivial method on `Connection`, there's a `_p` variant that raises instead of returning a union:

```pony
try
  stmt.bind_p(ParamIndex(1), SqlInteger(42))?
  stmt.bind_p(ParamIndex(2), SqlText("hello"))?
  stmt.execute_update_p()?
else
  env.err.print("insert failed")
end
```

Great for loops where you want "any step failing aborts the iteration", and you'll see this in the [Reusing Statements](reuse.md) sample.

## What's next

Binding sets up the parameters. Now the two executes — [`execute()` for SELECTs and `execute_update()` for DML](executing.md).
