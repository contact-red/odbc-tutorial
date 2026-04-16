# Reading Diagnostics

A `DiagChain` is an array of `DiagRecord` values, each representing one entry from ODBC's diagnostic-record stack. Drivers often return multiple records for a single failure — the first is typically the primary error, the rest are context.

```pony
type DiagChain is Array[DiagRecord] val

class val DiagRecord
  let sqlstate:    String val  // "42601", "23505", "08001", ...
  let native_code: I32          // driver-specific error code
  fun message():   String val   // human-readable text
  fun string():    String iso^  // "[SQLSTATE] message"
```

- **`sqlstate`** — the five-character SQLSTATE code. Standardised where possible; the library's error-kind classifier uses the first two characters.
- **`native_code`** — a driver-specific integer. Postgres returns its internal error code here; MariaDB returns a MySQL error number. Useful when you need to distinguish errors the ODBC standard collapses together.
- **`message()`** — the driver's message. May contain credentials. May contain query text. Audit accordingly.

## A demonstration

The sample below forces two errors (a bad DSN and a SQL syntax error), then peeks under the hood at both:

```pony
--8<-- "09-errors/main.pony"
```

Running it:

```shell
./build/09-errors
```

Output:

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

Every `ExecError` gets a kind derived from the SQLSTATE's first two characters:

| Class prefix | Library kind | Meaning |
|--------------|--------------|---------|
| `08` | `ConnectionLost` | Connection exception |
| `23` | `ConstraintViolation` | Integrity constraint |
| `42` | `SyntaxError` | Syntax error or access rule violation |
| anything else | `QueryError` | Generic driver-reported failure |

If you want to dispatch on a different class (`40` for transaction rollback, say, or `57014` for query canceled), walk the diagnostic chain yourself:

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

Two safety limits on the diagnostic reader:

- Messages are capped at **4096 bytes**. Longer messages get truncated with a `...[truncated]` suffix.
- Chains are capped at **16 records**. If the driver produced more, the last element is synthetic — SQLSTATE `00000` with a "diagnostic chain truncated" message.

These are defence-in-depth against malicious or misbehaving drivers. In normal use you'll never hit them.

## What's next

Errors are one kind of diagnostic output. [Warnings](warnings.md) are the other — diagnostics that the driver returned on a *successful* operation via `SQL_SUCCESS_WITH_INFO`.
