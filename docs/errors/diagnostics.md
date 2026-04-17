# Reading Diagnostics

A `DiagChain` is an array of `DiagRecord` values — one per entry in ODBC's diagnostic-record stack. Drivers often return several records per failure; the first is usually the primary error, the rest are context.

```pony
type DiagChain is Array[DiagRecord] val

class val DiagRecord
  let sqlstate:    String val  // "42601", "23505", "08001", ...
  let native_code: I32          // driver-specific error code
  fun message():   String val   // human-readable text
  fun string():    String iso^  // "[SQLSTATE] message"
```

- **`sqlstate`** — five-character SQLSTATE. The library's kind classifier uses the first two characters.
- **`native_code`** — driver-specific integer. Postgres returns its internal code; MariaDB returns a MySQL error number. Useful when ODBC's standard collapses errors the driver distinguishes.
- **`message()`** — the driver's message. May contain credentials or query text. Audit accordingly.

## A demonstration

The sample forces two errors (bad DSN, SQL syntax error), then peeks at both:

```pony
--8<-- "09-errors/main.pony"
```

```shell
./build/09-errors
```

```text
redacted: ConnectError: driver connect failed [IM002]
  kind:   driver connect failed
  diag records: 1
  first: [IM002] [unixODBC][Driver Manager]Data source name not found and no default driver specified

redacted: ExecError: syntax error [42601]
  kind:   syntax error
  sql:    SELCT 1
  driver: [42601] ERROR: syntax error at or near "SELCT";
Error while executing the query

warnings present: Warnings: 1 diagnostic record(s)
```

## SQLSTATE classes the library classifies

Every `ExecError` gets a kind from the SQLSTATE's first two characters:

| Prefix | Library kind | Meaning |
|--------|--------------|---------|
| `08` | `ConnectionLost` | Connection exception |
| `23` | `ConstraintViolation` | Integrity constraint |
| `42` | `SyntaxError` | Syntax error or access rule violation |
| anything else | `QueryError` | Generic driver-reported failure |

To dispatch on another class (`40` for transaction rollback, `57014` for query canceled), walk the chain:

```pony
match \exhaustive\ conn.exec(sql)
| let _: (USize | NoRowCount) => // ok
| let e: ExecError =>
  let diag = e.unsafe_diag()
  try
    let rec = diag(0)?
    if rec.sqlstate == "57014" then
      env.err.print("canceled")
    elseif rec.sqlstate.compare_sub("40", 2) is Equal then
      env.err.print("transient; retry")
    else
      env.err.print("other: " + e.string())
    end
  end
end
```

## Size caps

Two safety limits on the reader:

- Messages capped at **4096 bytes**; longer ones get a `...[truncated]` suffix.
- Chains capped at **16 records**; overflow is replaced with a synthetic record (SQLSTATE `00000`, "diagnostic chain truncated").

Defence-in-depth against malicious or misbehaving drivers. You won't hit these in normal use.

## What's next

[Warnings](warnings.md) covers diagnostics on *successful* operations — `SQL_SUCCESS_WITH_INFO`.
