# Transaction Errors

Each transaction method has its own error type. They're short, but `TxCommitError` has a subtlety worth understanding.

## TxBeginError

```pony
type TxBeginErrorKind is
  ( AlreadyInTransaction
  | TxBeginConnectionClosed
  | DriverTxError
  )
```

- `AlreadyInTransaction` — `begin()` called twice without `commit()` / `rollback()` in between. Nested transactions aren't supported at the connection level; use `SAVEPOINT` SQL if you need them.
- `TxBeginConnectionClosed` — connection is closed.
- `DriverTxError` — the driver rejected the autocommit-off call. See `unsafe_diag()`.

## TxRollbackError

```pony
type TxRollbackErrorKind is
  ( RollbackNotInTransaction
  | DriverRollbackError
  )
```

- `RollbackNotInTransaction` — no transaction active. Either `begin()` was never called, or the transaction was already resolved.
- `DriverRollbackError` — the driver errored during rollback. Rare; usually means something is very wrong (lost connection, driver bug, corrupt handle).

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

- **`CommitFailed`** — the server refused and rolled back. Data isn't there. Clean failure; retry or give up.
- **`CommitAmbiguous`** — a `08` SQLSTATE (connection exception) during commit. The network dropped or the session died. You *don't know* whether the commit landed before the server lost contact. Usually the answer is "no", but you can't be sure without reconnecting. Handle it by making operations idempotent so a retry-after-ambiguous is safe.
- **`NotInTransaction`** — `commit()` with no active transaction.

`.verdict()` returns the variant; `.string()` renders a short description.

### Auto-rollback after CommitFailed

On `CommitFailed`, the library re-enables autocommit and clears its in-transaction flag — the server has already rolled back, so staying "in transaction" would be a lie. You don't need (or want) to call `rollback()`.

On `CommitAmbiguous` the library leaves the connection "in transaction" because nobody knows what happened. Typical recovery: close, reconnect, check.

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
