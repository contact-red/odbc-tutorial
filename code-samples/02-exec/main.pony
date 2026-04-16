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
      // DDL: exec returns RowCount | NoRowCount | ExecError.
      match conn.exec("DROP TABLE IF EXISTS tut_exec")
      | let e: ExecError => env.err.print("drop: " + e.string())
      end

      let ct =
        "CREATE TABLE tut_exec ("
          + "id INTEGER, name VARCHAR(32))"
      match \exhaustive\ conn.exec(ct)
      | let _: USize => env.out.print("created")
      | NoRowCount => env.out.print("created (no row count)")
      | let e: ExecError =>
        env.err.print("create: " + e.string())
        conn.close()
        return
      end

      // DML: USize branch reports affected row count.
      let ins =
        "INSERT INTO tut_exec VALUES (1, 'widget'), (2, 'gadget')"
      match \exhaustive\ conn.exec(ins)
      | let n: USize => env.out.print("inserted " + n.string() + " rows")
      | NoRowCount => env.out.print("inserted (no row count)")
      | let e: ExecError => env.err.print("insert: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_exec")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
