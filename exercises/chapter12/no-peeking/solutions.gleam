//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/dynamic/decode
import gleam/http
import gleam/json
import wisp

// Упражнение 1
pub fn health_handler(_req: wisp.Request) -> wisp.Response {
  json.object([#("status", json.string("ok"))])
  |> json.to_string
  |> wisp.json_response(200)
}

// Упражнение 2
pub fn echo_handler(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  let decoder = {
    use text <- decode.field("text", decode.string)
    decode.success(text)
  }

  case decode.run(body, decoder) {
    Error(_) -> wisp.unprocessable_content()
    Ok(text) ->
      json.object([#("echo", json.string(text))])
      |> json.to_string
      |> wisp.json_response(200)
  }
}

// Упражнение 3
pub fn list_todos_handler(
  req: wisp.Request,
  todos: List(String),
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  json.object([#("todos", json.array(todos, json.string))])
  |> json.to_string
  |> wisp.json_response(200)
}

// Упражнение 4
pub fn create_todo_handler(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  let decoder = {
    use title <- decode.field("title", decode.string)
    decode.success(title)
  }

  case decode.run(body, decoder) {
    Error(_) -> wisp.unprocessable_content()
    Ok(title) ->
      json.object([#("title", json.string(title))])
      |> json.to_string
      |> wisp.json_response(201)
  }
}

// Упражнение 5
pub fn router(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    ["health"] -> health_handler(req)
    ["todos"] ->
      case req.method {
        http.Get -> list_todos_handler(req, [])
        http.Post -> create_todo_handler(req)
        _ -> wisp.method_not_allowed([http.Get, http.Post])
      }
    ["todos", id] ->
      json.object([#("id", json.string(id))])
      |> json.to_string
      |> wisp.json_response(200)
    _ -> wisp.not_found()
  }
}
