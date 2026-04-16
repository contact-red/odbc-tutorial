use "lib:odbc"
use "odbc"

actor Main
  new create(env: Env) =>
    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    match Odbc.connect(Dsn("DSN=" + dsn_name))
    | let conn: Connection =>
      conn.exec("DROP TABLE IF EXISTS tut_reuse")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_reuse (id INTEGER, label VARCHAR(32))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end

      // Batch insert: prepare once, re-bind each row.
      let items: Array[(I32, String val)] val =
        [(1, "alpha"); (2, "bravo"); (3, "charlie")]

      match \exhaustive\ conn.prepare(
        "INSERT INTO tut_reuse (id, label) VALUES (?, ?)")
      | let stmt: Statement =>
        for (id, label) in items.values() do
          try
            stmt.bind_p(ParamIndex(1), SqlInteger(id))?
            stmt.bind_p(ParamIndex(2), SqlText(label))?
            stmt.execute_update_p()?
          else
            env.err.print("insert " + id.string() + " failed")
          end
        end

        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare: " + e.string())
      end

      // Now prepare a SELECT and fetch rows back using the same pattern:
      // execute() opens a cursor, values() iterates, close_cursor() resets.
      match \exhaustive\ conn.prepare(
        "SELECT id, label FROM tut_reuse ORDER BY id")
      | let stmt: Statement =>
        match \exhaustive\ stmt.execute()
        | Executed =>
          for result in stmt.values() do
            match \exhaustive\ result
            | let row: Row =>
              try
                let id =
                  match \exhaustive\ row.int(ColIndex(1))?
                  | let v: I64 => v.string()
                  | SqlNull => "NULL"
                  end
                let label =
                  match \exhaustive\ row.text(ColIndex(2))?
                  | let v: String val => v
                  | SqlNull => "NULL"
                  end
                env.out.print(id + " " + label)
              end
            | let e: FetchError =>
              env.err.print("fetch: " + e.string())
            end
          end
          stmt.close_cursor()
        | let e: ExecError =>
          env.err.print("execute: " + e.string())
        end
        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_reuse")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
