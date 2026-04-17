# Querying

`Connection.query()` runs a SELECT and returns a `Cursor` — a forward-only iterator over the result rows.

```pony
fun ref query(sql: String val): (Cursor | ExecError)
```

A `Cursor` has three operations:

- `fetch()` — next `Row`, `EndOfRows`, or `FetchError`
- `values()` — iterator adapter for Pony's `for` loop
- `close()` — releases the `SQLHSTMT`

## Iterating a result set

```pony
--8<-- "03-query/main.pony"
```

```shell
./build/03-query
```

```text
  1 widget
  2 gadget
```

## What's happening

### `values()` and the iterator contract

`Cursor.values()` returns a `CursorIterator` yielding `(Row val | FetchError)`.

```pony
for result in cursor.values() do
  match \exhaustive\ result
  | let row: Row => ...
  | let e: FetchError => ...
  end
end
```

`EndOfRows` is what stops the iterator — it's never yielded — so the match inside has just two arms.

!!! note "Why fetch errors are values"
    A previous version terminated iteration silently on fetch errors, hiding
    real problems. The current iterator surfaces the `FetchError` on the
    iteration where it happens, then stops. You always find out.

### `fetch()` directly

For a single-row lookup (e.g. `SELECT COUNT(*)`), skip the iterator:

```pony
match cursor.fetch()
| let row: Row => ...      // got a row
| EndOfRows => ...         // empty result set
| let e: FetchError => ... // driver reported an error
end
```

The [Transactions](../transactions/index.md) sample uses this pattern.

### Close your cursors

`cursor.close()` is idempotent, but unlike `Connection.close()` it doesn't auto-close as reliably on finalization — drivers hold per-statement resources (cursors, temp tables, work buffers) that you want released promptly.

## What's next

[Reading Rows](rows.md) covers the typed accessors and `SqlNull`.
