import gleam/dynamic
import gleam/erlang/os
import gleam/option
import gleam/result
import pog

pub type Todo {
  Todo(id: Int, user_id: Int, title: String, completed: Bool)
}

pub fn connect() -> pog.Connection {
  let host = os.get_env("DB_HOST") |> result.unwrap("localhost")
  let database = os.get_env("DB_NAME") |> result.unwrap("todos_bot")
  let user = os.get_env("DB_USER") |> result.unwrap("postgres")
  let password = os.get_env("DB_PASSWORD") |> option.from_result

  pog.default_config()
  |> pog.host(host)
  |> pog.database(database)
  |> pog.user(user)
  |> pog.password(password)
  |> pog.pool_size(5)
  |> pog.connect
}

pub fn create_schema(db: pog.Connection) -> Result(Nil, pog.QueryError) {
  let sql =
    "
    CREATE TABLE IF NOT EXISTS todos (
      id SERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL,
      title TEXT NOT NULL,
      completed BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT NOW()
    )
    "

  pog.execute(sql, db, [], dynamic.dynamic)
  |> result.map(fn(_) { Nil })
}

pub fn list_user_todos(
  db: pog.Connection,
  user_id: Int,
) -> Result(List(Todo), pog.QueryError) {
  let sql =
    "SELECT id, user_id, title, completed FROM todos WHERE user_id = $1 ORDER BY id"

  pog.execute(sql, db, [pog.int(user_id)], decode_todo)
  |> result.map(fn(response) { response.rows })
}

pub fn create_todo(
  db: pog.Connection,
  user_id: Int,
  title: String,
) -> Result(Nil, pog.QueryError) {
  let sql = "INSERT INTO todos (user_id, title) VALUES ($1, $2)"

  pog.execute(sql, db, [pog.int(user_id), pog.text(title)], dynamic.dynamic)
  |> result.map(fn(_) { Nil })
}

pub fn mark_todo_done(
  db: pog.Connection,
  user_id: Int,
  index: Int,
) -> Result(Nil, pog.QueryError) {
  // Находим задачу по порядковому номеру
  let sql =
    "
    UPDATE todos
    SET completed = TRUE
    WHERE id = (
      SELECT id FROM todos
      WHERE user_id = $1
      ORDER BY id
      LIMIT 1 OFFSET $2
    )
    "

  pog.execute(sql, db, [pog.int(user_id), pog.int(index)], dynamic.dynamic)
  |> result.map(fn(_) { Nil })
}

pub fn delete_completed_todos(
  db: pog.Connection,
  user_id: Int,
) -> Result(Int, pog.QueryError) {
  let sql = "DELETE FROM todos WHERE user_id = $1 AND completed = TRUE"

  pog.execute(sql, db, [pog.int(user_id)], dynamic.dynamic)
  |> result.map(fn(response) { response.count })
}

fn decode_todo(dyn: dynamic.Dynamic) -> Result(Todo, List(dynamic.DecodeError)) {
  dynamic.decode4(
    Todo,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.int),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.bool),
  )(dyn)
}
