// Тесты используют wisp/simulate — запуск реального HTTP-сервера не нужен.
// Обработчики вызываются напрямую со сконструированными запросами.

import gleam/http
import gleam/json
import gleeunit
import gleeunit/should
import wisp/simulate as sim
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ── Упражнение 1: health_handler ────────────────────────────────────────
// health_handler(req) должен:
//   - возвращать статус 200
//   - возвращать тело {"status":"ok"}

pub fn health_handler_status_test() {
  sim.request(http.Get, "/health")
  |> my_solutions.health_handler
  |> fn(resp) { resp.status |> should.equal(200) }
}

pub fn health_handler_body_test() {
  sim.request(http.Get, "/health")
  |> my_solutions.health_handler
  |> sim.read_body
  |> should.equal("{\"status\":\"ok\"}")
}

// ── Упражнение 2: echo_handler ───────────────────────────────────────────
// echo_handler(req) должен:
//   - POST с {"text":"..."} → 200 {"echo":"..."}
//   - POST с неверным телом → 422
//   - GET/PUT/DELETE → 405

pub fn echo_handler_post_ok_test() {
  sim.request(http.Post, "/echo")
  |> sim.json_body(json.object([#("text", json.string("hello"))]))
  |> my_solutions.echo_handler
  |> fn(resp) {
    resp.status |> should.equal(200)
    sim.read_body(resp) |> should.equal("{\"echo\":\"hello\"}")
  }
}

pub fn echo_handler_post_unicode_test() {
  sim.request(http.Post, "/echo")
  |> sim.json_body(json.object([#("text", json.string("Привет, Gleam!"))]))
  |> my_solutions.echo_handler
  |> fn(resp) {
    resp.status |> should.equal(200)
    sim.read_body(resp) |> should.equal("{\"echo\":\"Привет, Gleam!\"}")
  }
}

pub fn echo_handler_get_405_test() {
  sim.request(http.Get, "/echo")
  |> my_solutions.echo_handler
  |> fn(resp) { resp.status |> should.equal(405) }
}

pub fn echo_handler_missing_field_422_test() {
  sim.request(http.Post, "/echo")
  |> sim.json_body(json.object([#("wrong_key", json.string("value"))]))
  |> my_solutions.echo_handler
  |> fn(resp) { resp.status |> should.equal(422) }
}

// ── Упражнение 3: list_todos_handler ────────────────────────────────────
// list_todos_handler(req, todos) должен:
//   - GET → 200 {"todos":["title1","title2",...]}
//   - GET с пустым списком → 200 {"todos":[]}
//   - POST/DELETE → 405

pub fn list_todos_handler_two_items_test() {
  sim.request(http.Get, "/todos")
  |> my_solutions.list_todos_handler(["Buy milk", "Write code"])
  |> fn(resp) {
    resp.status |> should.equal(200)
    sim.read_body(resp)
    |> should.equal("{\"todos\":[\"Buy milk\",\"Write code\"]}")
  }
}

pub fn list_todos_handler_empty_test() {
  sim.request(http.Get, "/todos")
  |> my_solutions.list_todos_handler([])
  |> fn(resp) {
    resp.status |> should.equal(200)
    sim.read_body(resp) |> should.equal("{\"todos\":[]}")
  }
}

pub fn list_todos_handler_post_405_test() {
  sim.request(http.Post, "/todos")
  |> my_solutions.list_todos_handler(["Buy milk"])
  |> fn(resp) { resp.status |> should.equal(405) }
}

// ── Упражнение 4: create_todo_handler ───────────────────────────────────
// create_todo_handler(req) должен:
//   - POST с {"title":"..."} → 201 {"title":"..."}
//   - POST с отсутствующим полем "title" → 422
//   - GET/PUT → 405

pub fn create_todo_created_test() {
  sim.request(http.Post, "/todos")
  |> sim.json_body(json.object([#("title", json.string("Buy milk"))]))
  |> my_solutions.create_todo_handler
  |> fn(resp) {
    resp.status |> should.equal(201)
    sim.read_body(resp) |> should.equal("{\"title\":\"Buy milk\"}")
  }
}

pub fn create_todo_missing_title_422_test() {
  sim.request(http.Post, "/todos")
  |> sim.json_body(json.object([#("x", json.string("y"))]))
  |> my_solutions.create_todo_handler
  |> fn(resp) { resp.status |> should.equal(422) }
}

pub fn create_todo_get_405_test() {
  sim.request(http.Get, "/todos")
  |> my_solutions.create_todo_handler
  |> fn(resp) { resp.status |> should.equal(405) }
}

// ── Упражнение 5: router ─────────────────────────────────────────────────
// router(req) должен маршрутизировать запросы:
//   GET /health      → 200
//   GET /todos       → 200
//   POST /todos      → 201 (тело берётся из запроса)
//   GET /todos/:id   → 200 {"id":"<id>"}
//   всё остальное    → 404

pub fn router_health_test() {
  sim.request(http.Get, "/health")
  |> my_solutions.router
  |> fn(resp) { resp.status |> should.equal(200) }
}

pub fn router_todos_list_test() {
  sim.request(http.Get, "/todos")
  |> my_solutions.router
  |> fn(resp) { resp.status |> should.equal(200) }
}

pub fn router_create_todo_test() {
  sim.request(http.Post, "/todos")
  |> sim.json_body(json.object([#("title", json.string("Learn Gleam"))]))
  |> my_solutions.router
  |> fn(resp) { resp.status |> should.equal(201) }
}

pub fn router_todo_by_id_test() {
  sim.request(http.Get, "/todos/42")
  |> my_solutions.router
  |> fn(resp) {
    resp.status |> should.equal(200)
    sim.read_body(resp) |> should.equal("{\"id\":\"42\"}")
  }
}

pub fn router_not_found_test() {
  sim.request(http.Get, "/unknown")
  |> my_solutions.router
  |> fn(resp) { resp.status |> should.equal(404) }
}

pub fn router_delete_not_found_test() {
  sim.request(http.Delete, "/unknown/path/here")
  |> my_solutions.router
  |> fn(resp) { resp.status |> should.equal(404) }
}
