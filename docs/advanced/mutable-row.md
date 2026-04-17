# Zero-Allocation Fetch

Every `fetch()` allocates a fresh `Row`. That's the right default — `Row` is `val`, safe to hold across fetches, safe to send across actors — but a hot loop over a million rows allocates a million rows.

`MutableRow` is the same container, reusable. Allocate one, hand it to `fetch_into()` on each iteration, and the column values are overwritten in place.

```pony
class ref MutableRow
  new ref create(num_cols: USize = 0)
  fun column(i: ColIndex):     SqlValue ?
  fun int(i: ColIndex):        (I64 | SqlNull) ?
  fun float(i: ColIndex):      (F64 | SqlNull) ?
  fun text(i: ColIndex):       (String val | SqlNull) ?
  fun bool(i: ColIndex):       (Bool | SqlNull) ?
  fun date(i: ColIndex):       (SqlDate | SqlNull) ?
  fun time(i: ColIndex):       (SqlTime | SqlNull) ?
  fun timestamp(i: ColIndex):  (SqlTimestamp | SqlNull) ?
  fun decimal(i: ColIndex):    (SqlDecimal | SqlNull) ?
  fun is_null(i: ColIndex):    Bool ?
  fun size():                  USize
```

Same accessor API as `Row`. The differences are the capability and the fetch method.

## `fetch_into` instead of `fetch`

Both `Statement` and `Cursor` have `fetch_into`:

```pony
fun ref fetch_into(row: MutableRow): (MutableRow | EndOfRows | FetchError)
```

Same three branches as `fetch()`. On success you get *the same `MutableRow`* back — conceptually unchanged, actually overwritten.

## A reuse loop

```pony
--8<-- "10-mutable-row/main.pony"
```

```shell
./build/10-mutable-row
```

```text
1 alpha
2 bravo
3 charlie
```

## What you save

Each iteration reuses the row container. `SqlText` and `SqlDecimal` columns still allocate fresh `String val`s, but the `Array[SqlValue]` and the `SqlInteger`/`SqlBool`/etc. boxes inside are reused.

For tiny rows (a few integer columns) over millions of rows this is measurable. For rows dominated by large text columns it's marginal — most of the allocation is the strings.

Rule of thumb: default to `fetch()` and `Row`. Switch to `MutableRow` when a profile shows row-container allocation at the top.

## Capability: `ref`, not `val`

`Row` is `val` — sendable, multiply-aliasable, stable across `close()`.

`MutableRow` is `ref` — not sendable, single-reference, and its values are invalidated by the next `fetch_into()`.

The capability difference is what makes reuse safe. `ref` promises no aliasing, which is what lets the library mutate the internal array without breaking Pony's concurrency guarantees.

## Don't mix `fetch()` and `fetch_into()` on the same cursor

The two methods aren't designed to interleave on one open cursor. Pick one per result set. Using both against different result sets on the same connection is fine — just don't switch mid-iteration.
