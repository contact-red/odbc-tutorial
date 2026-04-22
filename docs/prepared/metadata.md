# Prepare-Time Metadata

`prepare()` returns a `Statement` before any parameters are bound and before anything is executed. At that point the driver already knows the *shape* of the statement: how many parameters it takes, which types they are, which columns the result set will have, and whether those columns are nullable. Two methods on `Statement` expose that shape.

Useful for build-time tools that validate SQL against a live database, for generating bindings, or for logging a schema snapshot next to a migration. No execution, no binding — just prepare and describe.

## Two describe methods

```pony
fun ref parameter_types(): (Array[SqlTypeTag] val | MetadataError)
fun ref column_types():    (Array[ColumnMeta]  val | MetadataError)
```

- `parameter_types()` — one `SqlTypeTag` per `?` marker, in 1-based order. Returns an empty array for statements with no parameters. Backed by `SQLDescribeParam`.
- `column_types()` — one `ColumnMeta` per result column. Returns an empty array for non-result statements (INSERT, UPDATE, DELETE, DDL). Backed by `SQLDescribeCol`.

Both are available the moment `prepare()` succeeds; neither requires any parameter to be bound.

## `SqlTypeTag` is parallel to `SqlValue`

Where `SqlValue` carries a value *with* its storage, `SqlTypeTag` names the type *without* a value:

```pony
type SqlTypeTag is
  ( SqlTagBool
  | SqlTagTinyInt | SqlTagSmallInt | SqlTagInteger | SqlTagBigInt
  | SqlTagFloat
  | SqlTagText
  | SqlTagDate | SqlTagTime | SqlTagTimestamp | SqlTagDecimal
  | SqlTagUnknown )
```

Eleven of the variants are primitives — one per `SqlValue` family. `SqlTagUnknown` is a class carrying the raw ODBC type code (`raw_type: I16`) for any SQL type this library does not map to a `SqlValue`. Every variant has a `.string()` that renders short human-readable names: `"Integer"`, `"Text"`, `"Timestamp"`, `"Unknown(-7)"`, and so on.

## `ColumnMeta` bundles three facts

```pony
class val ColumnMeta
  let name:     String val
  let type_tag: SqlTypeTag
  let nullable: Nullability
```

`Nullability` is a *tri-state*, not a boolean:

```pony
type Nullability is (NoNulls | Nullable | NullableUnknown)
```

`NullableUnknown` is distinct from `Nullable` on purpose — the driver didn't answer the question. Some drivers genuinely don't know, particularly for computed or joined columns. Treating "unknown" as "nullable" is a reasonable default, but the library surfaces the distinction so you don't have to guess what the driver meant.

`ColumnMeta.string()` renders all three as `"name: Type (NOT NULL)"` or similar.

## A describe round-trip

The sample prepares an INSERT and a SELECT, then prints the parameter and column metadata for each:

```pony
--8<-- "13-metadata/main.pony"
```

```shell
./build/13-metadata
```

```text
parameter_types() on INSERT:
  $1: Integer
  $2: Text
  $3: Timestamp

parameter_types() on SELECT:
  $1: Integer

column_types() on SELECT:
  id: Integer (NOT NULL)
  name: Text (NULLABLE)
  created: Timestamp (NULLABLE)
```

The two `parameter_types()` calls hit the same underlying ODBC call (`SQLDescribeParam`); the `column_types()` call on the SELECT hits `SQLDescribeCol` once per result column.

## Partial variants

As elsewhere, `_p` variants raise on error:

```pony
fun ref parameter_types_p(): Array[SqlTypeTag] val ?
fun ref column_types_p():    Array[ColumnMeta]  val ?
```

Convenient for tooling where any failure aborts the pass.

## MetadataError kinds

| Kind | Meaning |
|------|---------|
| `MetadataStatementClosed` | Statement has been `close()`d |
| `MetadataConnectionClosed` | Owning connection has been `close()`d |
| `DriverDoesNotSupportDescribeParam` | Driver does not implement `SQLDescribeParam` (SQLSTATE `IM001` or `HYC00`) |
| `DriverMetadataError` | Any other driver-reported metadata failure |

Same shape as the other error classes: `e.kind()` for the primitive, `e.string()` for a redacted one-liner, `e.unsafe_diag()` for the raw `DiagChain`.

!!! note "Driver support for `SQLDescribeParam`"
    Not all drivers implement `SQLDescribeParam`. `psqlODBC` does.
    **SQLite's ODBC driver does not** — `parameter_types()` against it returns
    `MetadataError(DriverDoesNotSupportDescribeParam)`, classified from
    SQLSTATE `IM001` / `HYC00`. `column_types()` uses `SQLDescribeCol`, which
    is far more universally supported.

## What's next

That closes the Prepared Statements section. [Transactions](../transactions/index.md) is next.
