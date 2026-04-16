# Error Philosophy

Every error class in this library has two string representations: a safe, redacted one and a raw, unsafe one. The distinction matters more than it might look at first.

## Redacted by default

Every error's `.string()` method returns a fixed-vocabulary description — the error kind and, when available, the SQLSTATE code. No driver-supplied message text. No SQL fragment. No DSN content.

```text
ConnectError: driver connect failed [IM002]
ExecError: syntax error [42601]
BindError: index out of range (param 0)
TxCommitError: commit failed (rolled back by server) [40001]
```

That's what `.string()` gives you, and it's safe to emit anywhere — logs, HTTP responses, user-facing error pages.

### Why redact?

Two reasons.

**Driver messages can contain credentials.** When `SQLDriverConnect` fails, some drivers include the connection string in the error message — "could not connect using DSN=foo UID=admin PWD=supersecret". Or they echo back query text, which might embed user input. If `.string()` included the raw text, every log line capturing an error risks leaking a password or PII.

**Driver messages differ wildly between drivers.** A constraint violation on Postgres looks different from the same violation on MariaDB. If your code handles errors by substring-matching driver messages, you've built a fragile integration. The kind + SQLSTATE representation is stable; the raw message is not.

## The unsafe escape hatch

When you need the raw driver chain — for debugging, for developer-only logs, for protocol-level error handling — call `.unsafe_diag()`:

```pony
let diag: DiagChain = e.unsafe_diag()
for rec in diag.values() do
  env.out.print("[" + rec.sqlstate + "] " + rec.message())
end
```

The `unsafe_` prefix is the whole point. It's a deliberate speed bump: grepping your codebase for `unsafe_diag` is grepping for "places that might leak credentials". Audit those on every change.

Similarly `ExecError` and `PrepareError` carry an `.unsafe_sql()` accessor that returns the SQL text that was executing when the error happened. Useful for debugging, and the same audit applies.

## The three lenses

So for any error you've caught, you have three levels of detail:

| Lens | Method | Safe to log? | What you get |
|------|--------|--------------|--------------|
| Class | `e` itself, matched | Yes | Which branch of the error union |
| Kind | `e.kind()` or `e.verdict()` | Yes | The specific kind within that class |
| SQLSTATE | `.string()` or walk `.unsafe_diag()` | SQLSTATE only is safe | The five-character code from the driver |
| Raw | `.unsafe_diag()`, `.unsafe_sql()` | No | Everything the driver told us |

The redacted `.string()` gives you the first three at once. Reach for `unsafe_diag()` when you need more.

## What's next

[Reading Diagnostics](diagnostics.md) shows how to walk a `DiagChain` and what you'll find in a `DiagRecord`. [Warnings](warnings.md) covers `SQL_SUCCESS_WITH_INFO` — diagnostics on operations that succeeded.
