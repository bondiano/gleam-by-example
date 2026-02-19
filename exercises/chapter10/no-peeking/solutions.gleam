//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/dynamic/decode
import gleam/json

pub type Todo {
  Todo(title: String, completed: Bool)
}

pub fn health_check_body() -> String {
  json.object([#("status", json.string("ok"))])
  |> json.to_string
}

pub fn parse_todo(s: String) -> Result(Todo, Nil) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use completed <- decode.field("completed", decode.bool)
    decode.success(Todo(title:, completed:))
  }
  case json.parse(s, decoder) {
    Ok(t) -> Ok(t)
    Error(_) -> Error(Nil)
  }
}

pub fn todo_to_json_string(t: Todo) -> String {
  json.object([
    #("title", json.string(t.title)),
    #("completed", json.bool(t.completed)),
  ])
  |> json.to_string
}
