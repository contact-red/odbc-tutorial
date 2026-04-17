# Error Philosophy

Every error class has two string representations: a safe, redacted one and a raw, unsafe one. The distinction matters.

## Redacted by default

Every `.string()` returns a fixed-vocabulary description — the kind and, where available, the SQLSTATE. No driver-supplied message text, no SQL fragment, no DSN content.

```text
ConnectError: driver connect failed [IM002]
ExecError: syntax error [42601]
BindError: index out of range (param 0)
TxCommitError: commit failed (rolled back by server) [40001]
```

Safe to emit anywhere — logs, HTTP responses, user-facing pages.

### Why redact?

**Driver messages can contain credentials.** Some drivers put the connection string into `SQLDriverConnect` error text ("could not connect using DSN=foo UID=admin PWD=secret"). Others echo query text, which might embed user input. Raw messages in `.string()` mean every error log risks leaking a password or PII.

**Driver messages differ wildly between drivers.** A constraint violation reads differently on Postgres vs. MariaDB. Substring-matching driver text is a fragile integration. Kind + SQLSTATE is stable.

## The unsafe escape hatch

When you need the raw chain — debugging, developer-only logs, protocol-level handling — call `.unsafe_diag()`:

```pony
let diag: DiagChain = e.unsafe_diag()
for rec in diag.values() do
  env.out.print("[" + rec.sqlstate + "] " + rec.message())
end
```

The `unsafe_` prefix is the point — a speed bump. Grepping for `unsafe_diag` is grepping for "places that might leak credentials". Audit them.

`ExecError` and `PrepareError` also carry `.unsafe_sql()` — the SQL that was executing. Same audit applies.

## The three lenses

| Lens | Method | Safe to log? | What you get |
|------|--------|--------------|--------------|
| Class | `e` itself, matched | Yes | Which branch of the error union |
| Kind | `e.kind()` / `e.verdict()` | Yes | Specific kind within the class |
| SQLSTATE | `.string()` or walk `.unsafe_diag()` | SQLSTATE only | Five-character code |
| Raw | `.unsafe_diag()`, `.unsafe_sql()` | No | Everything the driver told us |

The redacted `.string()` gives you the first three at once.

## What's next

[Reading Diagnostics](diagnostics.md) walks a `DiagChain`. [Warnings](warnings.md) covers `SQL_SUCCESS_WITH_INFO` — diagnostics on successful operations.
