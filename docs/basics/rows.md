# Reading Rows

A `Row` is an immutable (`val`) snapshot of one result row, returned from `Cursor.fetch()`, the `Cursor.values()` iterator, or `Statement.fetch()`.

`Row` is `val` and therefore sendable: fetch in one actor, send to another, keep fetching. Each `fetch()` allocates a fresh `Row`.

## Typed accessors

Each accessor takes a 1-based `ColIndex` and returns the column value *or* `SqlNull`. Each `?`-raises on two conditions: out-of-range index, or type mismatch.

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

Also `column(i)?` for the polymorphic `SqlValue` and `is_null(i)?` / `size()` for meta-inspection.

### `int()` widens

`int()` accepts any of `SqlTinyInt`, `SqlSmallInt`, `SqlInteger`, `SqlBigInt` and widens to `I64`. Most callers don't care about the original width. When you do (bit-width preservation, range checks), use `column(i)?` and match on the concrete variant.

### `bool()` is forgiving

Drivers disagree about how boolean columns come back. `row.bool()` accepts:

- `SqlBool`
- any integer (non-zero → true)
- `SqlText` containing `"1"`, `"0"`, `"t"`, `"f"`, `"true"`, `"false"` (case-insensitive)

Anything else raises the partial function's error.

## A worked example

```pony
--8<-- "04-rows/main.pony"
```

```shell
./build/04-rows
```

```text
1 | widget | 9.99
2 | (null) | 14.5
3 | gadget | (null)
```

## The `SqlNull` primitive

`SqlNull` is a singleton primitive, part of the `SqlValue` union and of every typed accessor's return union. There's no implicit nullable value and no `None` — a column is either its declared type or `SqlNull`, and the match forces you to say which.

```pony
let id =
  match \exhaustive\ row.int(ColIndex(1))?
  | let v: I64 => v.string()
  | SqlNull => "NULL"
  end
```

The library leans hard on the type system here: you can't accidentally read a nullable column as if it weren't.

## Error handling

Accessors wrap in a `try`:

```pony
try
  let id = ...
  let name = ...
  env.out.print(id + " | " + name)
else
  env.err.print("column read error")
end
```

That catches out-of-range or wrong-type `?` errors. Indices and types should match the SELECT's column list, so hitting `else` means schema drift or a bug. Wrap the whole row read, not each accessor — distinguishing "column 1" from "column 3" at runtime is rarely useful.

## What's next

[SQL Types](sqltypes.md) covers the full `SqlValue` union and the edge cases around `SqlDecimal`, `SqlTimestamp`, and text encoding.
