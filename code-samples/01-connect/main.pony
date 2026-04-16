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
      env.out.print("Connected to " + dsn_name)
      conn.close()
      env.out.print("Closed.")
    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
