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
      conn.exec("DROP TABLE IF EXISTS tut_types")
      match \exhaustive\ conn.exec(
        "CREATE TABLE tut_types ("
          + "flag BOOLEAN, "
          + "big BIGINT, "
          + "ratio DOUBLE PRECISION, "
          + "label TEXT, "
          + "born DATE, "
          + "at TIME, "
          + "ts TIMESTAMP, "
          + "amount NUMERIC(20, 4))")
      | let _: (USize | NoRowCount) => None
      | let e: ExecError =>
        env.err.print("create: " + e.string()); conn.close(); return
      end

      match \exhaustive\ conn.prepare(
        "INSERT INTO tut_types VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      | let stmt: Statement =>
        try
          stmt.bind_p(ParamIndex(1), SqlBool(true))?
          stmt.bind_p(ParamIndex(2), SqlBigInt(9_000_000_000))?
          stmt.bind_p(ParamIndex(3), SqlFloat(3.14159))?
          stmt.bind_p(ParamIndex(4), SqlText("hello"))?
          stmt.bind_p(ParamIndex(5), SqlDate(2026, 4, 16))?
          stmt.bind_p(ParamIndex(6), SqlTime(9, 30, 0))?
          stmt.bind_p(ParamIndex(7),
            SqlTimestamp(2026, 4, 16, 9, 30, 0))?
          stmt.bind_p(ParamIndex(8), SqlDecimal("1234.5678"))?
          stmt.execute_update_p()?
        else
          env.err.print("bind/execute failed")
        end
        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare: " + e.string())
      end

      match \exhaustive\ conn.query(
        "SELECT flag, big, ratio, label, born, at, ts, amount "
          + "FROM tut_types")
      | let cursor: Cursor =>
        match cursor.fetch()
        | let row: Row =>
          try
            let flag =
              match \exhaustive\ row.bool(ColIndex(1))?
              | let v: Bool => v.string()
              | SqlNull => "(null)"
              end
            let big =
              match \exhaustive\ row.int(ColIndex(2))?
              | let v: I64 => v.string()
              | SqlNull => "(null)"
              end
            let ratio =
              match \exhaustive\ row.float(ColIndex(3))?
              | let v: F64 => v.string()
              | SqlNull => "(null)"
              end
            let label =
              match \exhaustive\ row.text(ColIndex(4))?
              | let v: String val => v
              | SqlNull => "(null)"
              end
            let born =
              match \exhaustive\ row.date(ColIndex(5))?
              | let v: SqlDate => v.string()
              | SqlNull => "(null)"
              end
            let at =
              match \exhaustive\ row.time(ColIndex(6))?
              | let v: SqlTime => v.string()
              | SqlNull => "(null)"
              end
            let ts =
              match \exhaustive\ row.timestamp(ColIndex(7))?
              | let v: SqlTimestamp => v.string()
              | SqlNull => "(null)"
              end
            let amount =
              match \exhaustive\ row.decimal(ColIndex(8))?
              | let v: SqlDecimal => v.string()
              | SqlNull => "(null)"
              end
            env.out.print("flag:   " + flag)
            env.out.print("big:    " + big)
            env.out.print("ratio:  " + ratio)
            env.out.print("label:  " + label)
            env.out.print("born:   " + born)
            env.out.print("at:     " + at)
            env.out.print("ts:     " + ts)
            env.out.print("amount: " + amount)
          else
            env.err.print("  read error")
          end
        end
        cursor.close()
      | let e: ExecError =>
        env.err.print("query: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS tut_types")
      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
