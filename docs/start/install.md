# Installing the Library

With `isql psqlred` working, hook the library into a Pony project.

## Create a project

```shell
mkdir odbc-hello
cd odbc-hello
corral init
```

## Add the dependency

```shell
corral add github.com/contact-red/odbc.git --version 0.0.3
corral fetch
```

`corral` clones into `_repos/` and checks out `0.0.3` into `_corral/github_com_contact_red_odbc/` — the path `ponyc` finds when we `use "odbc"`.

## A minimal program

`main.pony`:

```pony
use "lib:odbc"
use "odbc"

actor Main
  new create(env: Env) =>
    env.out.print("library loaded")
```

- `use "lib:odbc"` — links `libodbc.so.2` (unixODBC). Switch to `"lib:iodbc"` for iODBC.
- `use "odbc"` — imports the Pony package fetched above.

## Compile and run

```shell
corral run -- ponyc
./odbc-hello
```

`corral run --` sets `PONYPATH` so the import resolves, then runs `ponyc`. You should see `library loaded`.

Verify the link:

```shell
ldd ./odbc-hello
```

Look for `libodbc.so.2 => /lib/x86_64-linux-gnu/libodbc.so.2`.

!!! tip "Tutorial samples are ready to run"
    [`code-samples/`](https://github.com/contact-red/odbc-tutorial/tree/main/code-samples)
    has one `corral.json`, numbered subdirectories, and a `Makefile`. Clone the
    repo, run `corral fetch` inside `code-samples/`, and run the samples directly.

On to [making an actual connection](../basics/connecting.md).
