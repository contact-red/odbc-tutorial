# Cancellation

A long-running query blocks the actor that issued it. If another actor — a timer, a supervisor, a user-facing controller — decides the query has run long enough, it needs a way to say so.

`CancelToken` is a sendable handle that can fire `SQLCancel` on a statement from outside the actor that owns it.

```pony
class val CancelToken
  fun cancel()
```

`val`, so it's safe to send across actors. It holds a copy of the `SQLHSTMT` pointer and nothing else.

## Where tokens come from

Both `Statement` and `Cursor` have a `cancel_token()` method:

```pony
fun cancel_token(): CancelToken
```

You call it to obtain the token, send the token to your supervisor, and continue with whatever operation you intended.

## The pattern

```pony
--8<-- "12-cancellation/main.pony"
```

Running it (postgres-specific, uses `pg_sleep`):

```shell
./build/12-cancellation
```

Expected output:

```text
main: starting long query
canceller: firing cancel
main: execute returned: ExecError: query error [57014]
  SQLSTATE 57014 (Postgres reports 57014; ODBC defines HY008)
```

`HY008` is the ODBC standard SQLSTATE for "operation canceled". Postgres reports its own code `57014` ("query_canceled") which the library surfaces as-is — if you want to recognise cancellations portably, check for either.

## Lifetime contract

There's one sharp edge. The token holds a **raw copy** of the `SQLHSTMT` pointer. It does not know whether the owning `Statement`/`Cursor` has been closed. If the token outlives the statement and someone calls `token.cancel()` after `stmt.close()`, you're calling `SQLCancel` on a freed handle — undefined behaviour, typically a crash.

The library's contract: **the caller is responsible for ensuring no outstanding token is used after `close()`**.

Practical implementations:

- Close the statement *after* every actor that holds a token has been told to drop it
- Treat the token as a one-shot: fire it and forget it
- Use a supervising actor that explicitly discards the token before the query completes

There's no lifetime guard in the API because guarding it would require either actor-coordinated refcounting (expensive and awkward) or actively invalidating the token pointer (which defeats the "thread-safe SQLCancel" property). The trade-off is: cheap and fast normally, fragile if you misuse it.

## When cancellation doesn't land

Cancellation is a cooperation between driver and database. The driver's `SQLCancel` sends the database an asynchronous request; the database notices and aborts the in-flight statement.

Some databases don't cancel mid-statement — a `SELECT` with no blocking I/O might run to completion before the database checks for cancellation. Some drivers have their own quirks. If your cancel fires but the query completes normally, that's the reason; the sample handles this case with the `| Executed` branch.

## Not a timeout primitive

`CancelToken` is an *action*, not a policy. If you want a statement timeout, you build one out of `CancelToken` plus `time.Timer` (which is what sample 12 does). The library deliberately doesn't provide a timeout method directly — the policy choices around timeouts (behaviour on ambiguous commits, retry semantics, cleanup of partial work) vary enough that a single built-in would just get in the way.
