# Zero-Allocation Fetch

Every call to `fetch()` allocates a fresh `Row`. That's the right default — `Row` is `val`, safe to hold across fetches, safe to send across actors — but it means the hot loop through a million-row result set also allocates a million rows.

`MutableRow` is the same row-shaped container, but reusable. You allocate one, then hand it to `fetch_into()` on each iteration. The row's column values get overwritten in place.

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

Same accessor API as `Row`. The difference is in the capability and the fetch method.

## `fetch_into` instead of `fetch`

Both `Statement` and `Cursor` have a `fetch_into(row: MutableRow)` companion to `fetch()`:

```pony
fun ref fetch_into(row: MutableRow): (MutableRow | EndOfRows | FetchError)
```

Same three branches as `fetch()`. On success you get *the same `MutableRow`* back — conceptually unchanged, actually overwritten.

## A reuse loop

```pony
--8<-- "10-mutable-row/main.pony"
```

Running it:

```shell
./build/10-mutable-row
```

Output:

```text
1 alpha
2 bravo
3 charlie
```

## What you save

Each iteration reuses the row container. You still allocate strings for `SqlText` and `SqlDecimal` columns — those are immutable `String val` values — but the `Array[SqlValue]` and the `SqlInteger`/`SqlBool`/etc. boxes that live inside it are reused.

For result sets where rows are tiny (a few integer columns, say) and rows are many (millions), this is a measurable improvement. For result sets with large text columns the savings are minor; most of the allocation is the strings themselves.

Rule of thumb: default to `fetch()` and `Row`. Switch to `MutableRow` when a profile shows row-container allocation at the top of your allocation trace.

## Capability: `ref`, not `val`

`Row` is `val`. You can send it to another actor, hold references from multiple places, keep it after calling `close()` on the cursor. It's a stable immutable snapshot.

`MutableRow` is `ref`. You can't send it across actors. You can only hold one reference to it at a time. You can't keep reading values from it after a subsequent `fetch_into()` — those values have been overwritten.

The capability difference is what makes the reuse safe. `ref` promises no aliasing, which is what lets the library mutate the internal array without breaking Pony's concurrency guarantees.

## Don't mix fetch() and fetch_into() on the same cursor

The two methods write to different places, but they're not designed to interleave on the same open cursor. Pick one per result set. If you need both behaviours for different result sets on the same connection, that's fine — just don't switch mid-iteration.
