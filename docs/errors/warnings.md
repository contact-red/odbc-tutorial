# Warnings

Some operations succeed but still return diagnostic information — `SQL_SUCCESS_WITH_INFO` in the C API. Typical cases:

- `DROP TABLE IF EXISTS` on a nonexistent table (Postgres returns a NOTICE)
- Column data truncated to fit a target type
- Connection succeeded against a fallback driver
- A commit that worked but raised a platform advisory

Not errors — just diagnostic signal you might want to surface.

## The `Warnings` class

After any operation, the `Connection` (or `Statement`) keeps the most recent warnings:

```pony
fun ref last_warnings(): (Warnings | None)
```

`None` means no warnings on the last operation. A `Warnings` value has the same safe/unsafe split as errors:

```pony
class val Warnings
  fun string():      String iso^  // redacted: "Warnings: N diagnostic record(s)"
  fun unsafe_diag(): DiagChain    // raw chain
```

## A DROP IF EXISTS example

From the last section of [sample 09](diagnostics.md):

```pony
conn.exec("DROP TABLE IF EXISTS tut_never_existed")
match conn.last_warnings()
| let w: Warnings =>
  env.out.print("warnings present: " + w.string())
| None =>
  env.out.print("no warnings")
end
```

On Postgres, DROP of a nonexistent table succeeds with a warning:

```text
NOTICE:  table "tut_never_existed" does not exist, skipping
```

Other drivers may return no warning — a cross-driver difference you find by running against each target.

## Warnings get overwritten

There's one "last warnings" slot per `Connection` (and per `Statement`). The next successful operation replaces it or clears it. Inspect warnings *immediately* after the call that produced them.

```pony
conn.exec(a_thing)
let warnings_from_a = conn.last_warnings()  // snapshot now

conn.exec(another_thing)
// Too late — last_warnings() now reflects another_thing.
```

`Warnings` is `val`, so the captured snapshot is stable — it's the slot that's transient.

## Warnings vs. errors

- **Error** — operation failed. Error value in the return; `last_warnings()` untouched. `unsafe_diag()` gives the chain.
- **Warning** — operation succeeded. Normal success value in the return; `last_warnings()` gives a `Warnings`.

They don't overlap. An operation is either a success (maybe with warnings) or a failure (with an error).
