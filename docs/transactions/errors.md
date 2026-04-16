# Transaction Errors

The three transaction methods each have their own error type. They're short, but one of them — `TxCommitError` — has a subtlety that's worth understanding.

## TxBeginError

```pony
type TxBeginErrorKind is
  ( AlreadyInTransaction
  | TxBeginConnectionClosed
  | DriverTxError
  )
```

- `AlreadyInTransaction` — You called `begin()` twice without a `commit()` or `rollback()` in between. Nested transactions aren't supported at the connection level; use `SAVEPOINT` SQL if you need them.
- `TxBeginConnectionClosed` — The connection has been closed.
- `DriverTxError` — The driver rejected the autocommit-off call. Check `unsafe_diag()` for specifics.

## TxRollbackError

```pony
type TxRollbackErrorKind is
  ( RollbackNotInTransaction
  | DriverRollbackError
  )
```

- `RollbackNotInTransaction` — You called `rollback()` when no transaction was active. Either you never called `begin()`, or the transaction was already committed or rolled back.
- `DriverRollbackError` — The driver returned an error during rollback. This is rare and usually means something is very wrong — a lost connection, a driver bug, a corrupt handle.

## TxCommitError is special

```pony
class val TxCommitError
  fun verdict(): TxCommitVerdict
  fun string(): String iso^
  fun unsafe_diag(): DiagChain

type TxCommitVerdict is
  ( CommitFailed
  | CommitAmbiguous
  | NotInTransaction
  )
```

A commit can fail in three meaningfully different ways:

- **`CommitFailed`** — The server refused the commit and rolled back the transaction. The data you tried to write is not there. This is a clean failure; you can retry or give up.
- **`CommitAmbiguous`** — The server returned a SQLSTATE in the `08` class (connection exception) during commit. The network dropped, or the session died. You *don't know* whether the server committed your transaction before it lost contact. Most of the time the answer is "no", but you can't be sure without reconnecting and checking. The library surfaces this distinction so you can handle it correctly — for example, by making operations idempotent so a retry-after-ambiguous is safe.
- **`NotInTransaction`** — You called `commit()` with no active transaction.

The `.verdict()` method returns the variant; `.string()` renders a short description.

### The auto-rollback after CommitFailed

One detail worth knowing: on `CommitFailed`, the library automatically re-enables autocommit and clears its in-transaction flag. That's because the server has already rolled back — staying in "in transaction" mode would be a lie. After a `CommitFailed` you don't need to (and shouldn't) call `rollback()`; you're already out of the transaction.

On `CommitAmbiguous` the library leaves the connection in "in transaction" state, because no one knows what happened. Most recovery paths are: close the connection, reconnect, and check.

## Match on the verdict, not just the type

```pony
match conn.commit()
| TxCommitted =>
  // Data is durably written.
| let e: TxCommitError =>
  match e.verdict()
  | CommitFailed =>
    // Server rolled back. Retry or abort.
  | CommitAmbiguous =>
    // Connection died mid-commit. Reconnect and check.
  | NotInTransaction =>
    // Logic bug in the caller.
  end
end
```

Three outcomes, three different responses. The library won't let you ignore the distinction.
