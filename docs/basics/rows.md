# Reading Rows

A `Row` is an immutable (`val`) snapshot of one result row. You get one from `Cursor.fetch()`, from the `Cursor.values()` iterator, or from `Statement.fetch()` once we get to prepared statements.

`Row` values are sendable across actors — that's why they're `val`. You can fetch a row into one actor, send it to another, and keep fetching. Each `fetch()` allocates a fresh `Row`.

## Typed accessors

Every accessor takes a `ColIndex` (1-based) and returns the column value *or* `SqlNull`. Every accessor also `?`-raises on two conditions: the index is out of range, or the column's actual type doesn't match what you asked for.

```pony
fun int(i: ColIndex):       (I64       | SqlNull) ?
fun float(i: ColIndex):     (F64       | SqlNull) ?
fun text(i: ColIndex):      (String val | SqlNull) ?
fun bool(i: ColIndex):      (Bool      | SqlNull) ?
fun date(i: ColIndex):      (SqlDate   | SqlNull) ?
fun time(i: ColIndex):      (SqlTime   | SqlNull) ?
fun timestamp(i: ColIndex): (SqlTimestamp | SqlNull) ?
fun decimal(i: ColIndex):   (SqlDecimal | SqlNull) ?
```

There's also `column(i)?` which returns the polymorphic `SqlValue` if you want to do your own matching, and `is_null(i)?` / `size()` for meta-inspection.

### `int()` widens

The `int()` accessor accepts any of the four integer types (`SqlTinyInt`, `SqlSmallInt`, `SqlInteger`, `SqlBigInt`) and widens to `I64`. That's deliberate: most callers don't care whether a value came back as `SMALLINT` or `BIGINT`, they just want an integer. When you do care (for bit-width preservation or range checks), use `row.column(i)?` and match on the concrete variant.

### `bool()` is forgiving

Drivers disagree about how to return boolean columns. Postgres might return a `SMALLINT` or a `CHAR` depending on configuration. psqlODBC has a `BoolsAsChar=Yes` setting that makes it return `"1"` / `"0"`. `row.bool()` accepts all of:

- `SqlBool`
- any integer type (non-zero → true)
- `SqlText` containing `"1"`, `"0"`, `"t"`, `"f"`, `"true"`, or `"false"` (case-insensitive)

A `SqlText` that's none of those raises the partial function's error.

## A worked example

```pony
--8<-- "04-rows/main.pony"
```

Running it:

```shell
./build/04-rows
```

Output:

```text
1 | widget | 9.99
2 | (null) | 14.5
3 | gadget | (null)
```

## The `SqlNull` primitive

`SqlNull` is a primitive (singleton). It's part of the `SqlValue` union and of every typed accessor's return union. There is no implicit nullable value and no `None` — a column is either its declared type or `SqlNull`, and the match forces you to say which.

```pony
let id =
  match \exhaustive\ row.int(ColIndex(1))?
  | let v: I64 => v.string()
  | SqlNull => "NULL"
  end
```

This is a place where the library leans hard on Pony's type system. You can't accidentally read a nullable column as if it weren't — the union makes sure.

## One more thing: error handling

You'll notice the code wraps accessors in a `try`:

```pony
try
  let id = ...
  let name = ...
  env.out.print(id + " | " + name)
else
  env.err.print("column read error")
end
```

That catches the `?` errors — out-of-range index or wrong type. In practice the indices and types in your code should match the SELECT's column list, so hitting the `else` branch means a schema drift or a bug. Keep the `try` around the whole row read rather than per-accessor — it's rarely useful to distinguish "column 1 went wrong" from "column 3 went wrong" at runtime.

## What's next

[SQL Types](sqltypes.md) covers the full `SqlValue` union and the edge cases around `SqlDecimal`, `SqlTimestamp`, and text encoding.
