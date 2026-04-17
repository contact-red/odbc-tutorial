# Begin / Commit / Rollback

By default an ODBC connection is in **autocommit** mode: every statement is its own transaction, committed immediately. Safe-ish for ad-hoc queries, wrong for anything involving multiple related writes where the whole set must succeed or roll back together.

`Connection.begin()` turns autocommit off. Until `commit()` or `rollback()`, every statement is part of one transaction.

## The three methods

```pony
fun ref begin():    (TxBegun      | TxBeginError)
fun ref commit():   (TxCommitted  | TxCommitError)
fun ref rollback(): (TxRolledBack | TxRollbackError)
```

Each has a success primitive and an error branch. Matching on the primitive makes intent visible — `| TxCommitted =>` is hard to misread.

After `commit()` or `rollback()` the connection returns to autocommit. Call `begin()` again for the next transaction.

## A happy path, and a rollback

The sample commits two rows, then starts a second transaction that hits a constraint violation and rolls back cleanly.

```pony
--8<-- "07-transactions/main.pony"
```

```shell
./build/07-transactions
```

```text
committed 2 rows
insert failed: ExecError: constraint violation [23505]
rolled back cleanly
rows committed: 2
```

`23505` is Postgres's "unique constraint violation". The library classifies that into the `ConstraintViolation` kind automatically.

## Rollback-on-error is the idiom

```pony
conn.begin()
conn.exec(first_statement)
match conn.exec(second_statement)
| let e: ExecError =>
  conn.rollback()  // server may have already rolled back
  return
end
conn.commit()
```

Once any statement in a transaction errors, assume the transaction is dead and roll back explicitly. Most drivers put the session into an "aborted" state where every subsequent statement errors until rollback — the library surfaces this rather than silently clearing state.

## Close auto-rolls-back

`Connection.close()` fires a rollback before freeing handles. You don't *have* to remember rollback in cleanup — but an explicit rollback when you know you're aborting is still good practice.

## What's next

The three error unions carry more detail than "it failed" — especially `TxCommitError`, which distinguishes "the server rolled it back" from "we don't know what happened". [Transaction Errors](errors.md) covers that.
