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
      conn.exec("DROP TABLE IF EXISTS tut_tx")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_tx "
          + "(id INTEGER PRIMARY KEY, label VARCHAR(32))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end

      // Happy path: begin, exec, commit.
      match \exhaustive\ conn.begin()
      | TxBegun => None
      | let e: TxBeginError =>
        env.err.print("begin: " + e.string()); conn.close(); return
      end

      conn.exec("INSERT INTO tut_tx VALUES (1, 'alpha')")
      conn.exec("INSERT INTO tut_tx VALUES (2, 'bravo')")

      match \exhaustive\ conn.commit()
      | TxCommitted => env.out.print("committed 2 rows")
      | let e: TxCommitError =>
        env.err.print("commit: " + e.string())
      end

      // Rollback path: a constraint violation should leave no trace.
      match \exhaustive\ conn.begin()
      | TxBegun => None
      | let e: TxBeginError =>
        env.err.print("begin2: " + e.string()); conn.close(); return
      end

      conn.exec("INSERT INTO tut_tx VALUES (3, 'charlie')")
      match \exhaustive\ conn.exec(
        "INSERT INTO tut_tx VALUES (1, 'duplicate')")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("insert failed: " + e.string())
        match \exhaustive\ conn.rollback()
        | TxRolledBack => env.out.print("rolled back cleanly")
        | let r: TxRollbackError =>
          env.err.print("rollback: " + r.string())
        end
      end

      // Confirm: table has only the two committed rows.
      match \exhaustive\ conn.query(
        "SELECT COUNT(*) FROM tut_tx")
      | let cursor: Cursor =>
        match cursor.fetch()
        | let row: Row =>
          try
            match \exhaustive\ row.int(ColIndex(1))?
            | let n: I64 =>
              env.out.print("rows committed: " + n.string())
            | SqlNull => None
            end
          end
        end
        cursor.close()
      | let e: ExecError =>
        env.err.print("count: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_tx")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
