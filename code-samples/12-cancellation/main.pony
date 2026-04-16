use "lib:odbc"
use "odbc"
use "time"

// A supervisor actor that holds a CancelToken and fires SQLCancel on
// demand. The token is val, so it can safely cross actor boundaries.
actor Canceller
  let _token: CancelToken
  let _env: Env

  new create(env: Env, token: CancelToken) =>
    _env = env
    _token = token

  be fire() =>
    _env.out.print("canceller: firing cancel")
    _token.cancel()

// A Notify that wakes the canceller after a short delay.
class iso _TimerNotify is TimerNotify
  let _canceller: Canceller

  new iso create(canceller: Canceller) =>
    _canceller = canceller

  fun ref apply(timer: Timer, count: U64): Bool =>
    _canceller.fire()
    false

actor Main
  new create(env: Env) =>
    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    match Odbc.connect(Dsn("DSN=" + dsn_name))
    | let conn: Connection =>
      // A query that sleeps for 10 seconds server-side (Postgres).
      // Other backends: substitute the equivalent long-running statement.
      match \exhaustive\ conn.prepare("SELECT pg_sleep(10)")
      | let stmt: Statement =>
        // Hand the supervisor a token. Token is val — safe to send.
        let canceller = Canceller(env, stmt.cancel_token())

        // Schedule cancellation for 1 second from now.
        let timers = Timers
        let timer =
          Timer(_TimerNotify(canceller), 1_000_000_000)
        timers(consume timer)

        env.out.print("main: starting long query")
        match \exhaustive\ stmt.execute()
        | Executed =>
          // In practice a cancelled execute returns an ExecError
          // with SQLSTATE HY008. If we got Executed, the cancel
          // didn't land in time.
          env.out.print("main: query completed before cancel")
          stmt.close_cursor()
        | let e: ExecError =>
          env.out.print("main: execute returned: " + e.string())
          let diag = e.unsafe_diag()
          try
            let rec = diag(0)?
            env.out.print(
              "  SQLSTATE " + rec.sqlstate
                + " (Postgres reports 57014; ODBC defines HY008)")
          end
        end
        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare: " + e.string())
      end

      conn.close()

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
