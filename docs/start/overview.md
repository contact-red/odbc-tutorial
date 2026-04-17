# Overview

A quick tour of ODBC's structure, so the shape of the Pony API — environments, connections, statements, cursors, rows — feels inevitable rather than arbitrary.

## ODBC architecture

ODBC has four layers.

### Application

Your program. A *client* of ODBC.

### Driver Manager

The intermediary between your application and the database-specific driver, and the layer this library binds to. Since the API is standardised, any driver manager works.

A driver manager hosts **Data Source Names (DSNs)** — named configuration entries for driver, host, database, credentials, and so on. One driver manager can juggle connections to different databases, instances, users, and vendors at once.

On Linux the two common driver managers are **unixODBC** and **iODBC**. They're functionally equivalent; this tutorial uses unixODBC. The only Pony-level difference is the link line: `use "lib:odbc"` for unixODBC, `use "lib:iodbc"` for iODBC. Configuration lives in `/etc/odbc.ini` (system-wide) and `~/.odbc.ini` (per user).

### Driver

A shared library that translates ODBC calls for a specific database, usually shipped by the vendor.

Drivers *should* be consistent. They aren't. Expect differences in:

- Which SQLSTATE maps to a given invalid operation
- Whether `DROP TABLE IF EXISTS foo` raises a warning
- Whether bad SQL errors at prepare or at execute
- Which layer (env / connection / statement) reports an error

The library papers over some of this; the rest leaks through, and we call it out as it appears.

### Database

Your actual database.

## Handle types

ODBC's C API has three handle types. The Pony library wraps each as a distinct type.

| ODBC handle | Represents | Pony type |
|-------------|------------|-----------|
| `SQLHENV` | Global ODBC context | Owned internally by `Connection` |
| `SQLHDBC` | A single database connection | `Connection` |
| `SQLHSTMT` | A SQL statement and its result set | `Statement`, `Cursor` |

You never touch the environment handle directly. A `Connection` holds one `SQLHDBC`; most operations hang off it. A statement handle tracks one SQL statement through prepare, execute, and fetch — you see it as a `Cursor` (from `Connection.query()`) or a `Statement` (from `Connection.prepare()`). A single connection can own several statement handles, though most drivers serialise execution.

## The shape of the Pony API

The public surface is small:

- [`Odbc`](../basics/connecting.md) — connect entry point
- [`Dsn`](../basics/connecting.md) — wraps a connection string (separates credential-bearing text from plain `String`)
- [`Connection`](../basics/connecting.md) — the main object; `exec`, `query`, `prepare`, `begin`, `commit`, `rollback`, `close`
- [`Cursor`](../basics/querying.md) — forward-only result set from `query()`
- [`Statement`](../prepared/index.md) — prepared, reusable statement from `prepare()`
- [`Row`](../basics/rows.md) / [`MutableRow`](../advanced/mutable-row.md) — one fetched row (immutable val, or reusable ref)
- [`SqlValue`](../basics/sqltypes.md) — the closed union of supported column types
- [`DbSession`](../advanced/dbsession.md) — actor wrapper around `Connection`
- [`CancelToken`](../advanced/cancellation.md) — sendable cancellation handle

Plus the error classes: `ConnectError`, `ExecError`, `PrepareError`, `BindError`, `FetchError`, `TxBeginError`, `TxCommitError`, `TxRollbackError`. Each has a redacted `.string()` and an `.unsafe_diag()` escape hatch.

Next: [what you need to install](needs.md).
