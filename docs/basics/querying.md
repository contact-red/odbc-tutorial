# Querying

`Connection.query()` runs a SELECT and hands you back a `Cursor` — a forward-only iterator over the result rows.

The signature:

```pony
fun ref query(sql: String val): (Cursor | ExecError)
```

A `Cursor` supports three operations:

- `fetch()` — returns the next `Row`, or `EndOfRows`, or a `FetchError`
- `values()` — returns an iterator adapter so you can use Pony's `for` loop
- `close()` — releases the underlying `SQLHSTMT`

## Iterating a result set

```pony
--8<-- "03-query/main.pony"
```

Running it:

```shell
./build/03-query
```

Output:

```text
  1 widget
  2 gadget
```

## What's happening

### `values()` and the iterator contract

`Cursor.values()` returns a `CursorIterator` — a Pony iterator that yields `(Row val | FetchError)` on each iteration.

```pony
for result in cursor.values() do
  match \exhaustive\ result
  | let row: Row => ...
  | let e: FetchError => ...
  end
end
```

`EndOfRows` isn't one of the iterator's yielded values; it's what causes the iterator to stop. So the match inside the loop only has two arms: row or fetch-error. That's the shape to get used to.

!!! note "Why fetch errors are values, not exceptions"
    A previous version of the library terminated iteration silently on fetch
    errors, which hid real problems. The current iterator surfaces the
    `FetchError` on the iteration where it happens, then stops. You always
    find out when a fetch failed.

### `fetch()` directly, without the iterator

Sometimes you only want one row — for a `SELECT COUNT(*)` or a known-to-be-single-row lookup. Call `fetch()` directly:

```pony
match cursor.fetch()
| let row: Row => ...      // got a row
| EndOfRows => ...         // empty result set
| let e: FetchError => ... // driver reported an error
end
```

We'll use this pattern in the [Transactions](../transactions/index.md) sample when we verify row counts.

### Close your cursors

Call `cursor.close()` when you're done. It's idempotent, but unlike `Connection.close()` it doesn't auto-close on finalization as reliably — drivers hold per-statement resources (cursors, temp tables, work buffers) that you want released promptly.

## What's next

Reading rows is where things get interesting. The next page [Reading Rows](rows.md) introduces the typed accessors and `SqlNull` handling.
