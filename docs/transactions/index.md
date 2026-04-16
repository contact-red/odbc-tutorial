# Begin / Commit / Rollback

By default an ODBC connection is in **autocommit** mode: every statement is its own transaction, committed the moment it finishes. That's safe-ish for ad-hoc queries but wrong for anything involving multiple related writes — you need the whole set to succeed or the whole set to roll back.

`Connection.begin()` turns autocommit off. From then until you `commit()` or `rollback()`, every statement is part of one transaction.

## The three methods

```pony
fun ref begin():    (TxBegun      | TxBeginError)
fun ref commit():   (TxCommitted  | TxCommitError)
fun ref rollback(): (TxRolledBack | TxRollbackError)
```

Each has a success primitive (`TxBegun`, `TxCommitted`, `TxRolledBack`) and an error branch. Matching on the success primitive makes intent visible — it's hard to misread `| TxCommitted =>` as anything other than "commit succeeded".

After `commit()` or `rollback()` the connection goes back to autocommit mode. You call `begin()` again to start the next transaction.

## A happy path, and a rollback

The sample below does both: it commits two rows, then starts a second transaction that hits a constraint violation and rolls back cleanly.

```pony
--8<-- "07-transactions/main.pony"
```

Running it:

```shell
./build/07-transactions
```

Output:

```text
committed 2 rows
insert failed: ExecError: constraint violation [23505]
rolled back cleanly
rows committed: 2
```

The `23505` SQLSTATE is Postgres's "unique constraint violation" — we tried to insert a duplicate primary key. The library classifies that into the `ConstraintViolation` kind automatically.

## Rollback-on-error is the idiom

The pattern in the sample is worth calling out:

```pony
conn.begin()
conn.exec(first_statement)
match conn.exec(second_statement)
| let e: ExecError =>
  conn.rollback()  // don't lose track; server may have already rolled back
  return
end
conn.commit()
```

If any statement in a transaction errors, you should assume the transaction is dead and roll back explicitly. Most drivers will put the session into an "aborted" state where every subsequent statement errors until you roll back — and the library makes this explicit rather than silently clearing state for you.

## Close auto-rolls-back

If you call `Connection.close()` while a transaction is in flight, the library fires a rollback before freeing handles. You don't have to remember to roll back in your cleanup path — but it's still good practice to do it explicitly when you know you want to abort.

## What's next

The three transaction error unions have more detail than "it failed" — in particular `TxCommitError` distinguishes between "the server rolled it back" and "we have no idea what happened". [Transaction Errors](errors.md) covers that.
