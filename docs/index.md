# ODBC Tutorial

Welcome to the tutorial for [contact-red/odbc](https://github.com/contact-red/odbc), a Pony wrapper around unixODBC.

The goal of this tutorial is to take you from "I have `corral` and a working DSN" to "I am comfortable using every major piece of the public API" — connections, cursors, prepared statements, transactions, the full set of SQL value types, zero-allocation fetch loops, the async `DbSession` actor, and cross-actor cancellation.

Every code sample on these pages is backed by a runnable program in the [`code-samples/`](https://github.com/contact-red/odbc-tutorial/tree/main/code-samples) directory. You can compile each one with `corral` and `ponyc` and follow along as you read.

## Who this tutorial is for

You've written at least one Pony program and you have some idea of what it means to talk to a database — concepts like tables, rows, transactions, and SQL. You don't need prior ODBC experience; we cover the pieces you need as they come up.

## Why ODBC and why this library

ODBC (Open Database Connectivity) is a venerable, vendor-neutral database access standard. A single ODBC client works — in theory — against any database that ships an ODBC driver: PostgreSQL, MariaDB, SQLite, SQL Server, Oracle, and many others. In practice drivers vary in what they accept and how they report errors, but ODBC gets you a lot closer to vendor independence than a driver-specific client library.

`contact-red/odbc` is a typed, safe Pony wrapper over [unixODBC](https://www.unixodbc.org/). It focuses on:

- **Type safety** — SQL values are a closed union (`SqlValue`) with typed accessors that validate shape at compile time where possible and at runtime where necessary.
- **Redacted error diagnostics** — the default string form of an error never includes raw driver messages (which can leak credentials). The raw chain is still available through `unsafe_diag()` when you need it for debugging.
- **Immutable row snapshots** — fetched rows are `val`, so they are safe to hold across subsequent fetches and safe to send across actors.
- **Actor-friendly async API** — `DbSession` wraps a connection in an actor with promise-returning behaviors, so callers don't block a scheduler thread on database I/O.

!!! warning "Alpha status"
    The library is labelled alpha by its author and breaking changes are expected.
    The tutorial targets version `0.0.2`. If you're on a later release, check the API docs at [odbc.contact.red](https://odbc.contact.red/) for any changes.

## How the tutorial is organised

- **Getting Started** — a primer on ODBC's architecture, what you need to install, and how to add the library to a project.
- **The Basics** — the smallest useful programs: connect, execute, query, iterate, read typed values.
- **Prepared Statements** — parameter binding, statement reuse, and safe parameterised SQL.
- **Transactions** — begin / commit / rollback, and the three transaction error unions.
- **Errors and Diagnostics** — the redacted-vs-unsafe error model and how to walk a `DiagChain`.
- **Advanced** — `MutableRow` for zero-allocation fetch loops, `DbSession` for async access, and `CancelToken` for cross-actor cancellation.
- **Reference** — a short cheat sheet of call sequences.

If you're in a hurry, start with [Getting Started](start/overview.md) and work forward — the pages build on each other.
