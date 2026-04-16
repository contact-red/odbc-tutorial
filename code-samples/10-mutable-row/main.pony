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
      conn.exec("DROP TABLE IF EXISTS tut_mutable")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_mutable (id INTEGER, label VARCHAR(32))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end
      match \exhaustive\ conn.exec(
        "INSERT INTO tut_mutable VALUES "
          + "(1, 'alpha'), (2, 'bravo'), (3, 'charlie')")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("insert: " + e.string()); conn.close(); return
      end

      match \exhaustive\ conn.prepare(
        "SELECT id, label FROM tut_mutable ORDER BY id")
      | let stmt: Statement =>
        match \exhaustive\ stmt.execute()
        | Executed =>
          // Reuse one MutableRow across every fetch — no per-row
          // container allocation.
          let row = MutableRow
          var done: Bool = false
          while not done do
            match \exhaustive\ stmt.fetch_into(row)
            | let r: MutableRow =>
              try
                let id =
                  match \exhaustive\ r.int(ColIndex(1))?
                  | let v: I64 => v.string()
                  | SqlNull => "NULL"
                  end
                let label =
                  match \exhaustive\ r.text(ColIndex(2))?
                  | let v: String val => v
                  | SqlNull => "NULL"
                  end
                env.out.print(id + " " + label)
              end
            | EndOfRows => done = true
            | let e: FetchError =>
              env.err.print("fetch: " + e.string()); done = true
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

      conn.exec("DROP TABLE IF EXISTS tut_mutable")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
