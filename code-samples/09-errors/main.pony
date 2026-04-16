use "lib:odbc"
use "odbc"

actor Main
  new create(env: Env) =>
    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    // A bad DSN: the redacted .string() tells us the kind + SQLSTATE
    // but no driver-supplied message (which could contain credentials).
    match Odbc.connect(Dsn("DSN=definitely_not_a_real_dsn"))
    | let conn: Connection => conn.close()
    | let e: ConnectError =>
      env.out.print("redacted: " + e.string())
      env.out.print("  kind:   " + e.kind().string())
      // unsafe_diag() gives the raw driver-supplied chain. In real code
      // route this to a developer log, not a user-facing surface.
      let diag = e.unsafe_diag()
      env.out.print("  diag records: " + diag.size().string())
      try
        let rec = diag(0)?
        env.out.print(
          "  first: [" + rec.sqlstate + "] " + rec.message())
      end
    end

    // Connect for real, then trigger a syntax error to show ExecError.
    match Odbc.connect(Dsn("DSN=" + dsn_name))
    | let conn: Connection =>
      match \exhaustive\ conn.exec("SELCT 1")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.out.print("\nredacted: " + e.string())
        env.out.print("  kind:   " + e.kind().string())
        match e.unsafe_sql()
        | let sql: String val =>
          env.out.print("  sql:    " + sql)
        | None => None
        end
        let diag = e.unsafe_diag()
        try
          let rec = diag(0)?
          env.out.print(
            "  driver: [" + rec.sqlstate + "] " + rec.message())
        end
      end

      // A DROP IF EXISTS on some drivers yields SQL_SUCCESS_WITH_INFO.
      // last_warnings() surfaces that chain.
      conn.exec("DROP TABLE IF EXISTS tut_never_existed")
      match conn.last_warnings()
      | let w: Warnings =>
        env.out.print("\nwarnings present: " + w.string())
      | None =>
        env.out.print("\nno warnings")
      end

      conn.close()
    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
