# What You Need

This tutorial assumes you're on Ubuntu (or a close relative) and connecting to a local PostgreSQL. Substitute your preferred platform or database as needed — the shape of the Pony code won't change.

The end state of this page: a DSN named **`psqlred`** that lets you talk to PostgreSQL. Every tutorial sample defaults to that DSN name (and accepts an override as `argv[1]`).

## Install the driver manager

```shell
sudo apt install unixodbc unixodbc-dev
```

`unixodbc-dev` is the development package — it provides the `libodbc.so.2` that Pony's `use "lib:odbc"` links against.

## Install the PostgreSQL driver

```shell
sudo apt install odbc-postgresql
```

This installs the psqlODBC driver at `/usr/lib/x86_64-linux-gnu/odbc/psqlodbca.so` (Ubuntu 24.04 — confirm the path with `dpkg -L odbc-postgresql`).

## Create a user and database

We'll use the role `red` and the database `red`. Adjust the names to taste — just keep them consistent with the DSN below.

```shell
sudo -u postgres createuser -h 127.0.0.1 --interactive -P red
# Answer the prompts; pick a password you'll remember.

sudo -u postgres createdb -h 127.0.0.1 -O red red
```

Confirm you can log in with the native client:

```shell
psql -h 127.0.0.1 -U red red
```

If that prompts for your password and drops you into a `red=>` shell, you're set.

## Configure the DSN

Create `~/.odbc.ini` with the following entry:

```ini
[psqlred]
Description = ODBC tutorial database
Driver      = /usr/lib/x86_64-linux-gnu/odbc/psqlodbca.so
Servername  = 127.0.0.1
Database    = red
UserName    = red
Password    = your-password-here
```

Test it with `isql`:

```shell
isql psqlred
```

If `isql` prints `Connected!` and you can run `select 1;`, your driver manager, driver, database, user, and DSN are all talking to each other.

!!! note "Different databases, same shape"
    The steps above are Postgres-specific. For MariaDB, install `odbc-mariadb`
    and point the DSN `Driver` at its `.so`. For SQLite, `libsqliteodbc` gives
    you a zero-server option. The library's API is identical across drivers;
    only the SQL dialect and some error messages differ.

Now you're ready to [install the library](install.md).
