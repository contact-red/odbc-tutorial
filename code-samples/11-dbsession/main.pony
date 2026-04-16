use "lib:odbc"
use "odbc"
use "promises"

actor Main
  let _env: Env
  let _db: DbSession

  new create(env: Env) =>
    _env = env

    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    _db = DbSession(Dsn("DSN=" + dsn_name))

    // Chain: CREATE -> INSERT -> SELECT -> DROP -> close.
    let create_p = Promise[(RowCount | ExecError)]
    _db.exec("DROP TABLE IF EXISTS tut_session", create_p)

    let ct_p = Promise[(RowCount | ExecError)]
    create_p.next[None](recover this~_after_drop(ct_p) end)

    let ins_p = Promise[(RowCount | ExecError)]
    ct_p.next[None](recover this~_after_create(ins_p) end)

    let sel_p = Promise[(Array[Row val] val | ExecError)]
    ins_p.next[None](recover this~_after_insert(sel_p) end)

    sel_p.next[None](recover this~_after_select() end)

  be _after_drop(next_p: Promise[(RowCount | ExecError)],
    result: (RowCount | ExecError))
  =>
    _log_exec("drop", result)
    _db.exec(
      "CREATE TABLE tut_session (id INTEGER, label VARCHAR(32))",
      next_p)

  be _after_create(next_p: Promise[(RowCount | ExecError)],
    result: (RowCount | ExecError))
  =>
    _log_exec("create", result)
    _db.exec(
      "INSERT INTO tut_session VALUES (1, 'alpha'), (2, 'bravo')",
      next_p)

  be _after_insert(
    next_p: Promise[(Array[Row val] val | ExecError)],
    result: (RowCount | ExecError))
  =>
    _log_exec("insert", result)
    _db.query(
      "SELECT id, label FROM tut_session ORDER BY id", next_p)

  be _after_select(result: (Array[Row val] val | ExecError)) =>
    match result
    | let rows: Array[Row val] val =>
      for row in rows.values() do
        try
          let id =
            match \exhaustive\ row.int(ColIndex(1))?
            | let v: I64 => v.string()
            | SqlNull => "NULL"
            end
          let label =
            match \exhaustive\ row.text(ColIndex(2))?
            | let v: String val => v
            | SqlNull => "NULL"
            end
          _env.out.print(id + " " + label)
        end
      end
    | let e: ExecError =>
      _env.err.print("select: " + e.string())
    end

    // Fire-and-forget cleanup; then shut the session.
    let cleanup = Promise[(RowCount | ExecError)]
    _db.exec("DROP TABLE IF EXISTS tut_session", cleanup)
    cleanup.next[None](recover this~_after_cleanup() end)

  be _after_cleanup(result: (RowCount | ExecError)) =>
    _log_exec("cleanup", result)
    _db.close()

  fun _log_exec(label: String val, result: (RowCount | ExecError)) =>
    match result
    | let n: USize =>
      _env.out.print(label + ": " + n.string() + " rows")
    | NoRowCount =>
      _env.out.print(label + ": (no row count)")
    | let e: ExecError =>
      _env.err.print(label + ": " + e.string())
    end
