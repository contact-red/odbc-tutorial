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
      conn.exec("DROP TABLE IF EXISTS tut_rows")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_rows "
          + "(id INTEGER, name VARCHAR(32), price DOUBLE PRECISION)")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end
      match \exhaustive\ conn.exec(
        "INSERT INTO tut_rows VALUES "
          + "(1, 'widget', 9.99), "
          + "(2, NULL, 14.50), "
          + "(3, 'gadget', NULL)")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("insert: " + e.string()); conn.close(); return
      end

      match \exhaustive\ conn.query(
        "SELECT id, name, price FROM tut_rows ORDER BY id")
      | let cursor: Cursor =>
        for result in cursor.values() do
          match \exhaustive\ result
          | let row: Row =>
            try
              // row.int() widens any SQL integer to I64.
              let id =
                match \exhaustive\ row.int(ColIndex(1))?
                | let v: I64 => v.string()
                | SqlNull => "NULL"
                end
              // row.text() returns String val or SqlNull.
              let name =
                match \exhaustive\ row.text(ColIndex(2))?
                | let v: String val => v
                | SqlNull => "(null)"
                end
              // row.float() returns F64 or SqlNull.
              let price =
                match \exhaustive\ row.float(ColIndex(3))?
                | let v: F64 => v.string()
                | SqlNull => "(null)"
                end
              env.out.print(
                id + " | " + name + " | " + price)
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

      conn.exec("DROP TABLE IF EXISTS tut_rows")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
