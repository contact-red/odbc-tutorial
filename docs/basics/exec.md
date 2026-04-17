# Executing Statements

`Connection.exec()` runs a SQL statement with no parameters and no result set you want to fetch — DDL (`CREATE`, `DROP`, `ALTER`) and ad-hoc DML where you only care about the affected row count.

```pony
fun ref exec(sql: String val): (RowCount | ExecError)
```

- `RowCount` is `(USize | NoRowCount)`.
- `USize` is the affected row count when the driver reports one.
- `NoRowCount` means the driver returned `SQL_NO_ROW_COUNT` (-1). Most DDL lands here.
- `ExecError` is the error branch.

So a full match has three arms. `\exhaustive\` makes the compiler enforce them.

## Creating a table and inserting rows

```pony
--8<-- "02-exec/main.pony"
```

```shell
./build/02-exec
```

```text
created
inserted 2 rows
```

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

On Postgres, `CREATE TABLE` returns `NoRowCount`. Other drivers might return `USize 0`. The branch structure makes that difference explicit.

### Partial match when you don't care

The sample's first `DROP TABLE IF EXISTS` uses a non-exhaustive match:

```pony
match conn.exec("DROP TABLE IF EXISTS tut_exec")
| let e: ExecError => env.err.print("drop: " + e.string())
end
```

An ordinary `match` is allowed to be partial. A good fit when you only want to know about surprising failures.

## `exec` is for statements without a result set

`exec` can run a `SELECT`, but the rows are discarded. For anything where you want them back, use [`query()`](querying.md).

## Partial variant for chaining

Every non-trivial `Connection` method has a `_p` variant that raises on error:

```pony
try
  conn.exec_p("CREATE TABLE t (id INTEGER)")?
  conn.exec_p("INSERT INTO t VALUES (1)")?
  conn.exec_p("INSERT INTO t VALUES (2)")?
else
  env.err.print("setup failed")
end
```

Convenient when any failure should abort a block. The `else` loses kind/diagnostic detail — reach for `_p` when you only need *whether*, not *how*.
