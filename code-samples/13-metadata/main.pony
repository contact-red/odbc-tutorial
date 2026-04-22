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
      conn.exec("DROP TABLE IF EXISTS tut_meta")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_meta"
          + " (id INTEGER NOT NULL,"
          + " name VARCHAR(32),"
          + " created TIMESTAMP)")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end

      // Parameter metadata on an INSERT. No bind, no execute — just describe.
      match \exhaustive\ conn.prepare(
        "INSERT INTO tut_meta VALUES (?, ?, ?)")
      | let stmt: Statement =>
        env.out.print("parameter_types() on INSERT:")
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          var i: USize = 1
          for t in tags.values() do
            env.out.print("  $" + i.string() + ": " + t.string())
            i = i + 1
          end
        | let e: MetadataError => env.err.print("  " + e.string())
        end
        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare insert: " + e.string())
      end

      // Parameter and column metadata on a SELECT.
      match \exhaustive\ conn.prepare(
        "SELECT id, name, created FROM tut_meta WHERE id > ?")
      | let stmt: Statement =>
        env.out.print("\nparameter_types() on SELECT:")
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          var i: USize = 1
          for t in tags.values() do
            env.out.print("  $" + i.string() + ": " + t.string())
            i = i + 1
          end
        | let e: MetadataError => env.err.print("  " + e.string())
        end

        env.out.print("\ncolumn_types() on SELECT:")
        match \exhaustive\ stmt.column_types()
        | let cols: Array[ColumnMeta] val =>
          for col in cols.values() do
            env.out.print("  " + col.string())
          end
        | let e: MetadataError => env.err.print("  " + e.string())
        end

        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare select: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_meta")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
