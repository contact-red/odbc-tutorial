# Warnings

Some ODBC operations succeed but still return diagnostic information — `SQL_SUCCESS_WITH_INFO` in the C API. Typical examples:

- `DROP TABLE IF EXISTS` on a table that doesn't exist (Postgres returns a NOTICE)
- Column data truncated to fit a target type
- Connection succeeded against a fallback driver
- A commit that worked but raised a platform-specific advisory

These aren't errors — the operation succeeded — but they're diagnostic signal you might want to surface.

## The `Warnings` class

After any operation, the `Connection` (or `Statement`) keeps a reference to the most recent warnings. Ask for them:

```pony
fun ref last_warnings(): (Warnings | None)
```

`None` means "no warnings on the last operation". A `Warnings` value means "there were some". You can inspect it:

```pony
class val Warnings
  fun string():      String iso^  // redacted: "Warnings: N diagnostic record(s)"
  fun unsafe_diag(): DiagChain    // raw chain
```

Same safe/unsafe split as the error classes.

## A DROP IF EXISTS example

Look again at the last section of [sample 09](diagnostics.md):

```pony
conn.exec("DROP TABLE IF EXISTS tut_never_existed")
match conn.last_warnings()
| let w: Warnings =>
  env.out.print("warnings present: " + w.string())
| None =>
  env.out.print("no warnings")
end
```

On Postgres the `DROP TABLE IF EXISTS` on a nonexistent table comes back as success with a warning:

```text
NOTICE:  table "tut_never_existed" does not exist, skipping
```

`last_warnings()` returns a `Warnings` containing that notice. On some drivers the same operation returns no warning at all — that's one of the cross-driver differences you discover by running against each target you support.

## Warnings get overwritten

There's only *one* "last warnings" slot per `Connection` (and per `Statement`). The next successful operation either replaces the slot with its own warnings or clears it to `None`. If you care about the warnings from a specific call, inspect them immediately after the call, not later.

```pony
conn.exec(a_thing)
let warnings_from_a = conn.last_warnings()  // snapshot now

conn.exec(another_thing)
// Too late — last_warnings() now reflects another_thing.
```

`Warnings` itself is `val`, so the snapshot you captured is stable — it's the *slot* that's transient.

## Warnings vs. errors

The split:

- **Error** — the operation failed. You get an error value from the return; `last_warnings()` is unaffected. The error's `unsafe_diag()` gives you the driver chain.
- **Warning** — the operation succeeded. You get the normal success value from the return. `last_warnings()` gives you a `Warnings` to inspect.

They don't overlap. An operation is either a success (possibly with warnings) or a failure (with an error).
