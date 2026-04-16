# Executing Statements

`Connection.exec()` runs a SQL statement that has no parameters and no result set you want to fetch. It's the right tool for DDL (`CREATE`, `DROP`, `ALTER`) and for the ad-hoc DML where you just need to know *how many rows* the statement touched.

The signature:

```pony
fun ref exec(sql: String val): (RowCount | ExecError)
```

Three things in the return type:

- `RowCount` is itself a union: `type RowCount is (USize | NoRowCount)`.
- `USize` is the affected row count when the driver reports one.
- `NoRowCount` is a primitive meaning "the driver returned `SQL_NO_ROW_COUNT` (-1)". Most DDL comes back this way.
- `ExecError` is the error branch.

So a full match has three arms, and the `\exhaustive\` annotation makes the compiler enforce that you cover all of them.

## Creating a table and inserting rows

```pony
--8<-- "02-exec/main.pony"
```

Running it:

```shell
./build/02-exec
```

Output:

```text
created
inserted 2 rows
```

A couple of details worth calling out.

### Matching on the three arms

```pony
match \exhaustive\ conn.exec(ct)
| let _: USize => env.out.print("created")
| NoRowCount => env.out.print("created (no row count)")
| let e: ExecError =>
  env.err.print("create: " + e.string())
  conn.close()
  return
end
```

On Postgres, `CREATE TABLE` comes back as `NoRowCount`. On other drivers it might come back as `USize 0`. The branch structure makes that difference explicit rather than something you have to remember.

### Non-exhaustive match when you don't care about the error

Look at the first `DROP TABLE IF EXISTS` in the sample. It's a non-exhaustive match:

```pony
match conn.exec("DROP TABLE IF EXISTS tut_exec")
| let e: ExecError => env.err.print("drop: " + e.string())
end
```

No `\exhaustive\`, no handling of the success branches. That's legal Pony — an ordinary `match` is allowed to be partial — and it's a good fit here: we don't care whether the drop succeeded or not, only if it erred in some surprising way.

## `exec` is for statements without a result set

What about `SELECT`? `exec` can technically run a `SELECT` but the rows get thrown away — you'd just get back the driver's row count (which is often `NoRowCount` for SELECTs). For anything where you want the rows back, use [`query()`](querying.md).

## Partial variant for chaining

If you have a sequence of statements where any failure should abort the whole block, the partial variant `exec_p` is convenient:

```pony
try
  conn.exec_p("CREATE TABLE t (id INTEGER)")?
  conn.exec_p("INSERT INTO t VALUES (1)")?
  conn.exec_p("INSERT INTO t VALUES (2)")?
else
  env.err.print("setup failed")
end
```

Every non-trivial method on `Connection` has a `_p` partial variant that raises on error — use whichever style fits the situation. The partial style loses kind/diagnostic detail in the `else` block, so reach for it when you only need to know *whether* something failed, not *how*.
