# SQL Types

`SqlValue` is the closed union of every value type the library can carry across the ODBC boundary. Every parameter you bind is a `SqlValue`. Every column you fetch is a `SqlValue` (wrapped in a `Row` or `MutableRow`).

```pony
type SqlValue is
  ( SqlNull
  | SqlBool
  | SqlTinyInt | SqlSmallInt | SqlInteger | SqlBigInt
  | SqlFloat
  | SqlText
  | SqlDate | SqlTime | SqlTimestamp
  | SqlDecimal )
```

The union is closed in the sense that there's no extension point — if the library doesn't already have a variant for a SQL type, you can't add one without modifying the library. This is a deliberate trade-off: closed unions give you exhaustive matching and no hidden dispatch, at the cost of flexibility.

## The variants

| Variant | Pony carrier | Typical SQL types it maps to |
|---------|-------------|------------------------------|
| `SqlNull` | *(primitive)* | `NULL` in any column |
| `SqlBool` | `Bool` | `BOOLEAN`, `BIT` |
| `SqlTinyInt` | `I8` | `TINYINT` (not available on Postgres) |
| `SqlSmallInt` | `I16` | `SMALLINT` |
| `SqlInteger` | `I32` | `INTEGER`, `INT` |
| `SqlBigInt` | `I64` | `BIGINT` |
| `SqlFloat` | `F64` | `REAL`, `FLOAT`, `DOUBLE PRECISION` |
| `SqlText` | `String val` | `CHAR`, `VARCHAR`, `TEXT`, `LONGVARCHAR` |
| `SqlDate` | `(year, month, day)` | `DATE` |
| `SqlTime` | `(hour, minute, second)` | `TIME` |
| `SqlTimestamp` | `(date, time, fraction)` | `TIMESTAMP`, `TIMESTAMPTZ` |
| `SqlDecimal` | `String val` | `NUMERIC`, `DECIMAL` |

A few variants deserve special attention.

### `SqlFloat` absorbs all floats

The library reads `REAL`, `FLOAT`, and `DOUBLE PRECISION` all through `SQL_C_DOUBLE`, so they all come back as `SqlFloat` with an `F64` inside. There's no separate `SqlReal`. If the write-side precision difference matters to you, you need to enforce it at the SQL level.

### `SqlText` is UTF-8 validated by default

`Odbc.connect(dsn, validate_utf8 = true)` — the default — checks every text column against UTF-8 rules on fetch. Invalid bytes raise `FetchError(InvalidUtf8)`. Pass `false` to skip the check; only do that if you control the data source and know the bytes are clean (or know they aren't but you want them anyway).

### `SqlDecimal` is a `String`

Exact numeric types (`NUMERIC(20, 4)` etc.) don't fit cleanly into an `F64`, and converting them to one silently would lose precision. `SqlDecimal` stores the driver-supplied text representation verbatim. Round-tripping is lossless; arithmetic is your problem.

### `SqlTimestamp` has a nanosecond fraction

```pony
class val SqlTimestamp
  let year: I16
  let month: U16
  let day: U16
  let hour: U16
  let minute: U16
  let second: U16
  let fraction: U32  // nanoseconds
```

The `fraction` field is `U32` nanoseconds. Not all drivers populate it; Postgres sends microsecond precision, which the library surfaces as a nanosecond count with three trailing zeros.

Timezones are not represented directly. Postgres's `TIMESTAMPTZ` comes back converted to the session's time zone; if you need the offset, select it separately or set the session time zone explicitly.

### The four integer types

Writes preserve the width you give them: `SqlTinyInt(3)` binds as `SQL_TINYINT` to the driver, `SqlBigInt(3)` binds as `SQL_BIGINT`. Some databases (Postgres) don't have a `TINYINT` column type at all — if you bind one to a `SMALLINT` column, the driver widens for you; if you bind one to no column (e.g. as a SELECT parameter), most drivers accept the implicit widening too.

Reads preserve the width as well: a `SMALLINT` column comes back as `SqlSmallInt`, not `SqlBigInt`. That's why `Row.int()` exists — it widens all four to `I64` so you don't have to match on the specific variant when you don't care.

## Round-tripping every variant

The sample below creates a table with one column per variant that Postgres supports, binds a value into each, then reads them all back:

```pony
--8<-- "08-all-types/main.pony"
```

Running it:

```shell
./build/08-all-types
```

Output:

```text
flag:   true
big:    9000000000
ratio:  3.14159
label:  hello
born:   2026-04-16
at:     09:30:00
ts:     2026-04-16 09:30:00
amount: 1234.5678
```

!!! note "Missing variants"
    This sample doesn't use `SqlTinyInt` or `SqlSmallInt` or `SqlInteger`
    because Postgres doesn't have distinct column types for all of them —
    we'd just be relying on the driver widening them to `BIGINT` on the wire.
    On MariaDB you'd pick `TINYINT`, `SMALLINT`, and `INT` columns and see
    the narrower `SqlValue` variants come back.

## What's next

So far every statement we've run has been a literal string. Parameters have been interpolated the hard way. [Prepared Statements](../prepared/index.md) fixes that.
