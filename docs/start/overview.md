# Overview

Before we look at any code, a quick tour of how ODBC is structured. This context makes the shape of the Pony API — environments, connections, statements, cursors, rows — feel inevitable rather than arbitrary.

## ODBC architecture

ODBC is an abstraction over database connectivity. Four layers are involved.

### Application

What you write. Your program is a *client* of ODBC.

### Driver Manager

An intermediary between your application and the database-specific driver. The driver manager presents the programmatic API that this library binds to. Because that API is standardised, any driver manager implementation works.

Inside the driver manager you configure individual **Data Source Names (DSNs)**. A DSN names a configuration entry: which driver to use, the hostname, the database, username and password, and so on.

A single driver manager can juggle connections to different databases, different instances, different users, and even different vendors simultaneously.

The two common driver managers on Linux are **unixODBC** and **iODBC**. They're functionally equivalent; this tutorial uses unixODBC. The only difference at the Pony level is the `use "lib:..."` line — `use "lib:odbc"` for unixODBC, `use "lib:iodbc"` for iODBC.

Configuration for both lives in `/etc/odbc.ini` (system-wide) and `~/.odbc.ini` (per user).

### Driver

A shared library that translates ODBC calls into commands a specific database understands. Typically shipped by the database vendor.

Drivers *should* be consistent in behaviour. They are not. Expect differences in:

- Which SQLSTATE code is returned for a given invalid operation
- Whether operations like `DROP TABLE IF EXISTS foo` raise a warning
- Whether a bad SQL statement errors at prepare time or at execute time
- Which ODBC layer (environment / connection / statement) reports an error

The library papers over some of these; others leak through, and we call them out as they come up.

### Database

Your actual database.

## Handle types

ODBC's C API is built on three handle types. The Pony library wraps each one as a distinct Pony type.

| ODBC handle | What it represents | Pony type |
|-------------|--------------------|-----------|
| `SQLHENV` | Global ODBC context | Owned internally by `Connection` |
| `SQLHDBC` | A single database connection | `Connection` |
| `SQLHSTMT` | A SQL statement and its result set | `Statement`, `Cursor` |

- **Environment handle** — global context. This library allocates one per `Connection`; you never touch it directly.
- **Connection handle** — a single authenticated session against one database. `Connection` holds this, and it's what most operations hang off.
- **Statement handle** — tracks one SQL statement through prepare, execute, and fetch. You see it as either a `Cursor` (from `Connection.query()`) or a `Statement` (from `Connection.prepare()`).

Most operations take a statement handle. A single connection can own several statement handles at once, although most drivers serialise their execution in practice.

## The shape of the Pony API

The library's public surface is small. These are the names you'll meet in the next few chapters:

- [`Odbc`](../basics/connecting.md) — the connect entry point
- [`Dsn`](../basics/connecting.md) — a wrapper for a connection string (separates credential-bearing text from ordinary `String`)
- [`Connection`](../basics/connecting.md) — the main object; has `exec`, `query`, `prepare`, `begin`, `commit`, `rollback`, `close`
- [`Cursor`](../basics/querying.md) — a forward-only result set from `Connection.query()`
- [`Statement`](../prepared/index.md) — a prepared, reusable statement from `Connection.prepare()`
- [`Row`](../basics/rows.md) and [`MutableRow`](../advanced/mutable-row.md) — one fetched row, in two flavours (immutable val, reusable ref)
- [`SqlValue`](../basics/sqltypes.md) — the closed union of all supported column types
- [`DbSession`](../advanced/dbsession.md) — actor wrapper around `Connection`, for async use
- [`CancelToken`](../advanced/cancellation.md) — sendable cancellation handle

And the error classes: `ConnectError`, `ExecError`, `PrepareError`, `BindError`, `FetchError`, `TxBeginError`, `TxCommitError`, `TxRollbackError`. Each has a redacted `.string()` representation and an `.unsafe_diag()` escape hatch for detailed debugging.

That's all the nouns. The next chapter covers what you need to install locally to follow along.
