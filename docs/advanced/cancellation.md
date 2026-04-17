# Cancellation

A long-running query blocks the actor that issued it. If another actor — a timer, supervisor, user-facing controller — decides the query has run long enough, it needs a way to say so.

`CancelToken` is a sendable handle that fires `SQLCancel` on a statement from outside the owning actor.

```pony
class val CancelToken
  fun cancel()
```

`val`, so sendable. It holds a copy of the `SQLHSTMT` pointer and nothing else.

## Where tokens come from

Both `Statement` and `Cursor` expose:

```pony
fun cancel_token(): CancelToken
```

Call it, send the token to a supervisor, continue with your operation.

## The pattern

```pony
--8<-- "12-cancellation/main.pony"
```

Postgres-specific (uses `pg_sleep`):

```shell
./build/12-cancellation
```

```text
main: starting long query
canceller: firing cancel
main: execute returned: ExecError: query error [57014]
  SQLSTATE 57014 (Postgres reports 57014; ODBC defines HY008)
```

`HY008` is the ODBC-standard SQLSTATE for "operation canceled". Postgres reports its own `57014` ("query_canceled") which the library surfaces as-is — check for either for portable recognition.

## Lifetime contract

One sharp edge: the token holds a **raw copy** of the `SQLHSTMT`. It doesn't know whether the owning `Statement`/`Cursor` has closed. If the token outlives the statement and someone calls `token.cancel()` after `stmt.close()`, you're calling `SQLCancel` on a freed handle — undefined behaviour, typically a crash.

Contract: **the caller ensures no outstanding token is used after `close()`**.

Practical patterns:

- Close the statement *after* every token-holding actor has been told to drop it
- Treat the token as one-shot: fire it and forget it
- Use a supervising actor that explicitly discards the token before the query completes

There's no lifetime guard in the API. Guarding would require either actor-coordinated refcounting (expensive and awkward) or actively invalidating the token pointer (which defeats the thread-safety of `SQLCancel`). The trade: cheap and fast normally, fragile if you misuse it.

## When cancellation doesn't land

Cancellation is driver+database cooperation. `SQLCancel` sends an asynchronous request; the database notices and aborts.

Some databases don't cancel mid-statement — a `SELECT` without blocking I/O can run to completion before the database checks. Some drivers have quirks. If the cancel fires but the query completes normally, that's the reason; the sample handles it in the `| Executed` branch.

## Not a timeout primitive

`CancelToken` is an *action*, not a policy. For a statement timeout, build one out of `CancelToken` plus `time.Timer` (sample 12 does exactly that). The library doesn't provide a timeout method because the policy choices (behaviour on ambiguous commits, retry semantics, cleanup of partial work) vary too much for a single built-in to stay out of the way.
