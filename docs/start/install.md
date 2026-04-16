# Installing the Library

From the driver manager's point of view you're ready to go — `isql psqlred` connects. Now we hook the library into a Pony project.

## Create a project

```shell
mkdir odbc-hello
cd odbc-hello
corral init
```

`corral init` creates a `corral.json` with empty `deps` and `packages` arrays.

## Add the dependency

```shell
corral add github.com/contact-red/odbc.git --version 0.0.2
```

This adds an entry to `deps` in `corral.json`:

```json
{
  "deps": [
    {
      "locator": "github.com/contact-red/odbc.git",
      "version": "0.0.2"
    }
  ]
}
```

Then fetch:

```shell
corral fetch
```

`corral` clones the repo into `_repos/` and checks out the `0.0.2` tag into `_corral/github_com_contact_red_odbc/`. That's the path `ponyc` will find when we `use "odbc"`.

## A minimal program

Create `main.pony`:

```pony
use "lib:odbc"
use "odbc"

actor Main
  new create(env: Env) =>
    env.out.print("library loaded")
```

- `use "lib:odbc"` — link against `libodbc.so.2` (unixODBC). Switch to `use "lib:iodbc"` if you use iODBC instead.
- `use "odbc"` — import the Pony package. This is what `corral fetch` made available.

## Compile and run

```shell
corral run -- ponyc
./odbc-hello
```

`corral run --` sets up the `PONYPATH` so `use "odbc"` resolves to the fetched dependency, then runs `ponyc`. If everything linked correctly you'll see `library loaded`.

Check that `libodbc.so.2` actually got linked in:

```shell
ldd ./odbc-hello
```

You should see `libodbc.so.2 => /lib/x86_64-linux-gnu/libodbc.so.2` somewhere in the output.

!!! tip "Tutorial samples are set up for you"
    The [`code-samples/`](https://github.com/contact-red/odbc-tutorial/tree/main/code-samples)
    directory in this tutorial's repository is already wired up — one shared
    `corral.json` at the root, twelve numbered subdirectories, and a `Makefile`
    that compiles each one. Clone the tutorial repo, run `corral fetch` inside
    `code-samples/`, and you can follow along by running the samples directly.

With the library installed and the DSN working, we're ready to [make an actual connection](../basics/connecting.md).
