# SQL Types

`SqlValue` is the closed union of every value type the library carries across the ODBC boundary. Every parameter you bind is a `SqlValue`. Every column you fetch is a `SqlValue` (wrapped in a `Row` or `MutableRow`).

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

Closed means there's no extension point — if the library doesn't have a variant for a SQL type, you can't add one without modifying the library. The trade-off: exhaustive matching and no hidden dispatch, at the cost of flexibility.

## The variants

| Variant | Pony carrier | Typical SQL types |
|---------|-------------|-------------------|
| `SqlNull` | *(primitive)* | `NULL` in any column |
| `SqlBool` | `Bool` | `BOOLEAN`, `BIT` |
| `SqlTinyInt` | `I8` | `TINYINT` (not on Postgres) |
| `SqlSmallInt` | `I16` | `SMALLINT` |
| `SqlInteger` | `I32` | `INTEGER`, `INT` |
| `SqlBigInt` | `I64` | `BIGINT` |
| `SqlFloat` | `F64` | `REAL`, `FLOAT`, `DOUBLE PRECISION` |
| `SqlText` | `String val` | `CHAR`, `VARCHAR`, `TEXT`, `LONGVARCHAR` |
| `SqlDate` | `(year, month, day)` | `DATE` |
| `SqlTime` | `(hour, minute, second)` | `TIME` |
| `SqlTimestamp` | `(date, time, fraction)` | `TIMESTAMP`, `TIMESTAMPTZ` |
| `SqlDecimal` | `String val` | `NUMERIC`, `DECIMAL` |

A few variants deserve attention.

### `SqlFloat` absorbs all floats

`REAL`, `FLOAT`, and `DOUBLE PRECISION` all come back through `SQL_C_DOUBLE` as `SqlFloat` (`F64`). There's no separate `SqlReal`. Precision differences on the write side are your problem to enforce at the SQL level.

### `SqlText` is UTF-8 validated by default

`Odbc.connect(dsn, validate_utf8 = true)` — the default — checks every text column against UTF-8 rules on fetch. Invalid bytes raise `FetchError(InvalidUtf8)`. Pass `false` only when you trust the source (or want dirty bytes anyway).

### `SqlDecimal` is a `String`

Exact numerics (`NUMERIC(20, 4)` etc.) don't fit cleanly into `F64`, and silent conversion loses precision. `SqlDecimal` stores the driver's text representation verbatim. Round-tripping is lossless; arithmetic is your problem.

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

Not all drivers populate `fraction`. Postgres sends microsecond precision, surfaced as nanoseconds with three trailing zeros.

Timezones aren't represented directly. `TIMESTAMPTZ` comes back converted to the session's time zone; select the offset separately or set the session zone explicitly if you need it.

### The four integer types

Widths are preserved on both sides. `SqlTinyInt(3)` binds as `SQL_TINYINT`; `SqlBigInt(3)` binds as `SQL_BIGINT`. Some databases (Postgres) lack narrower column types — drivers widen for you on write.

Reads preserve width too: a `SMALLINT` column comes back as `SqlSmallInt`, not `SqlBigInt`. `Row.int()` exists so you don't have to match on the width when you don't care.

## Round-tripping every variant

The sample creates a table with one column per supported variant, binds a value into each, and reads them back:

```pony
--8<-- "08-all-types/main.pony"
```

```shell
./build/08-all-types
```

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
    Postgres lacks distinct column types for `SqlTinyInt`, `SqlSmallInt`, and
    `SqlInteger` in this sample — we'd just be watching the driver widen them
    to `BIGINT`. On MariaDB, pick `TINYINT` / `SMALLINT` / `INT` columns to see
    the narrower variants come back.

## What's next

So far every statement has been a literal string. [Prepared Statements](../prepared/index.md) fixes that.
