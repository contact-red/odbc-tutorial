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
      conn.exec("DROP TABLE IF EXISTS tut_query")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_query (id INTEGER, name VARCHAR(32))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end
      match \exhaustive\ conn.exec(
        "INSERT INTO tut_query VALUES (1, 'widget'), (2, 'gadget')")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("insert: " + e.string()); conn.close(); return
      end

      match \exhaustive\ conn.query(
        "SELECT id, name FROM tut_query ORDER BY id")
      | let cursor: Cursor =>
        for result in cursor.values() do
          match \exhaustive\ result
          | let row: Row =>
            try
              let id =
                match \exhaustive\ row.int(ColIndex(1))?
                | let v: I64 => v.string()
                | SqlNull => "NULL"
                end
              let name =
                match \exhaustive\ row.text(ColIndex(2))?
                | let v: String val => v
                | SqlNull => "NULL"
                end
              env.out.print("  " + id + " " + name)
            else
              env.err.print("  column read error")
            end
          | let e: FetchError =>
            env.err.print("  fetch: " + e.string())
          end
        end
        cursor.close()
      | let e: ExecError =>
        env.err.print("query: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_query")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
