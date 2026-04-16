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
      conn.exec("DROP TABLE IF EXISTS tut_prep")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_prep (id INTEGER, label VARCHAR(32))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end

      // Prepare an INSERT with two parameter markers.
      match \exhaustive\ conn.prepare(
        "INSERT INTO tut_prep (id, label) VALUES (?, ?)")
      | let stmt: Statement =>
        // Bind each parameter by 1-based index.
        match \exhaustive\ stmt.bind(ParamIndex(1), SqlInteger(42))
        | Bound => None
        | let e: BindError =>
          env.err.print("bind id: " + e.string())
          stmt.close(); conn.close(); return
        end
        match \exhaustive\ stmt.bind(ParamIndex(2), SqlText("hello"))
        | Bound => None
        | let e: BindError =>
          env.err.print("bind label: " + e.string())
          stmt.close(); conn.close(); return
        end

        // execute_update for DML: returns affected row count.
        match \exhaustive\ stmt.execute_update()
        | let n: USize => env.out.print("inserted " + n.string() + " row")
        | NoRowCount => env.out.print("inserted (no row count)")
        | let e: ExecError => env.err.print("execute: " + e.string())
        end

        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_prep")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
