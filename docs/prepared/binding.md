# Binding Parameters

A prepared statement has one or more `?` markers, e.g. `INSERT INTO t VALUES (?, ?)`. Binding associates a value with a marker by 1-based index.

## The bind method

```pony
fun ref bind(i: ParamIndex, v: SqlValue): (Bound | BindError)
```

`ParamIndex` wraps `U16` — like `ColIndex`, it keeps 1-based index arithmetic from silently mixing with other numeric values.

The value is any `SqlValue` variant (see [SQL Types](../basics/sqltypes.md)):

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

On success, `Bound`. On failure, a `BindError` with a `kind`.

## BindError kinds

| Kind | Meaning |
|------|---------|
| `ParamIndexOutOfRange` | Zero, or greater than the parameter count |
| `ParamTooLarge` | Value exceeded the maximum bind size (rare) |
| `DriverRejected` | Driver rejected the bind call |
| `BindStatementClosed` | Statement has been `close()`d |
| `BindConnectionClosed` | Connection has been `close()`d |

Every `BindError` carries the failing `ParamIndex` — `e.param_index()` — so you can point at the culprit in a batch.

## A complete example

```pony
--8<-- "05-prepared-bind/main.pony"
```

```shell
./build/05-prepared-bind
```

```text
inserted 1 row
```

## `bind_null` as a convenience

`stmt.bind(ParamIndex(3), SqlNull)` works. If you do that a lot:

```pony
stmt.bind_null(ParamIndex(3))
```

Same effect, slightly clearer intent.

## Partial variants

The `_p` variants raise instead of returning a union:

```pony
try
  stmt.bind_p(ParamIndex(1), SqlInteger(42))?
  stmt.bind_p(ParamIndex(2), SqlText("hello"))?
  stmt.execute_update_p()?
else
  env.err.print("insert failed")
end
```

Great for loops where any failure should abort the iteration — see [Reusing Statements](reuse.md).

## What's next

Now the two executes — [`execute()` for SELECTs and `execute_update()` for DML](executing.md).
