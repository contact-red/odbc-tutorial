# ODBC Tutorial

A tour of [contact-red/odbc](https://github.com/contact-red/odbc), a Pony wrapper around unixODBC. By the end you'll have used every major piece of the public API: connections, cursors, prepared statements, prepare-time metadata, transactions, the `SqlValue` union, zero-allocation fetch loops, the async `DbSession` actor, and cross-actor cancellation.

Every code sample is a runnable program in [`code-samples/`](https://github.com/contact-red/odbc-tutorial/tree/main/code-samples). Compile with `corral` and `ponyc` to follow along.

## Why ODBC and why this library

ODBC is a vendor-neutral database access standard — one client can talk to PostgreSQL, MariaDB, SQLite, SQL Server, Oracle, and more. Drivers vary in the details, but ODBC gets you much closer to vendor independence than a driver-specific library.

`contact-red/odbc` is a typed, safe wrapper over [unixODBC](https://www.unixodbc.org/). Values are a closed `SqlValue` union; errors are redacted by default (raw driver text stays behind `unsafe_diag()`); fetched rows are `val` and safe to send across actors; and `DbSession` wraps a connection in an actor so database I/O doesn't block a scheduler thread.

!!! warning "Alpha status"
    The library is alpha and breaking changes are expected. This tutorial targets `0.0.3`; for later releases check [odbc.contact.red](https://odbc.contact.red/).

## A note on verbosity

The library prioritises *correct* over *brief*: every call site checks every outcome. If you don't care *why* something failed — only *that* it did — see [examples/partial/main.pony](https://github.com/contact-red/odbc/blob/main/examples/partials/main.pony). Use that shortcut deliberately.

## How the tutorial is organised

- **Getting Started** — ODBC's architecture, what to install, how to add the library to a project.
- **The Basics** — connect, execute, query, iterate, read typed values.
- **Prepared Statements** — parameter binding, statement reuse, parameterised SQL, prepare-time metadata.
- **Transactions** — begin / commit / rollback and the three transaction error unions.
- **Errors and Diagnostics** — the redacted-vs-unsafe error model and walking a `DiagChain`.
- **Advanced** — `MutableRow`, `DbSession`, `CancelToken`.
- **Reference** — a short cheat sheet.

Start with [Getting Started](start/overview.md) and work forward — the pages build on each other.
