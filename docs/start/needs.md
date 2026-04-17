# What You Need

This tutorial assumes Ubuntu (or close) and a local PostgreSQL. Other platforms and databases work — the Pony code doesn't change.

End state: a DSN named **`psqlred`**. Every sample defaults to that name and accepts an override as `argv[1]`.

## Install the driver manager

```shell
sudo apt install unixodbc unixodbc-dev
```

`unixodbc-dev` provides the `libodbc.so.2` that `use "lib:odbc"` links against.

## Install the PostgreSQL driver

```shell
sudo apt install odbc-postgresql
```

On Ubuntu 24.04 this installs `psqlodbca.so` at `/usr/lib/x86_64-linux-gnu/odbc/` — confirm with `dpkg -L odbc-postgresql`.

## Create a user and database

We'll use role `red` and database `red`. Adjust to taste, but keep them consistent with the DSN below.

```shell
sudo -u postgres createuser -h 127.0.0.1 --interactive -P red
sudo -u postgres createdb -h 127.0.0.1 -O red red
```

Confirm with the native client:

```shell
psql -h 127.0.0.1 -U red red
```

A `red=>` prompt means you're set.

## Configure the DSN

Add to `~/.odbc.ini`:

```ini
[psqlred]
Description = ODBC tutorial database
Driver      = /usr/lib/x86_64-linux-gnu/odbc/psqlodbca.so
Servername  = 127.0.0.1
Database    = red
UserName    = red
Password    = your-password-here
```

Test with `isql`:

```shell
isql psqlred
```

If it prints `Connected!` and `select 1;` runs, your driver manager, driver, database, user, and DSN are all wired up.

!!! note "Different databases, same shape"
    For MariaDB: `odbc-mariadb` and point `Driver` at its `.so`. For SQLite:
    `libsqliteodbc` (zero-server). The Pony API is identical across drivers;
    only SQL dialect and some error messages differ.

Now [install the library](install.md).
