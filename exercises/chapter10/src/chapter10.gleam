// Пример: TODO API с ETS-хранилищем
//
// Запуск: gleam run
// Сервер слушает на http://localhost:8080
//
// ETS (Erlang Term Storage) — встроенная in-memory база данных BEAM.
// Ключевые свойства:
//   - O(1) чтение/запись по ключу
//   - Параллельные чтения без блокировок
//   - Named tables — доступны по имени-атому из любого процесса
//   - Данные живут независимо от жизненного цикла создавшего их процесса
//
// Маршруты:
//   GET    /health       → {"status":"ok"}
//   GET    /todos        → {"todos":[...]}
//   POST   /todos        → {"title":"..."} → 201
//   GET    /todos/:id    → {"id":"...","title":"...","completed":false}
//   DELETE /todos/:id    → 204

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import mist
import wisp
import wisp/wisp_mist

// ── ETS FFI ─────────────────────────────────────────────────────────────────
//
// @external позволяет вызывать Erlang-функции напрямую из Gleam.
// Формат: @external(erlang, "модуль", "функция")
//
// ETS хранит Erlang-кортежи. Первый элемент — ключ (key position = 1 по умолчанию).
// В Gleam кортеж #(a, b, c) компилируется в Erlang tuple {a, b, c} — совместимо с ETS.

// Создаёт именованную ETS-таблицу.
// Возвращает имя-атом — по нему обращаются к таблице из любого процесса.
@external(erlang, "ets", "new")
fn ets_new(name: Atom, options: List(Dynamic)) -> Atom

// Вставляет кортеж в таблицу. Ключ = первый элемент кортежа.
// При совпадении ключа перезаписывает запись (тип set).
@external(erlang, "ets", "insert")
fn ets_insert(table: Atom, record: #(String, String, Bool)) -> Bool

// Ищет по ключу: возвращает список кортежей (0 или 1 для set).
@external(erlang, "ets", "lookup")
fn ets_lookup(table: Atom, key: String) -> List(#(String, String, Bool))

// Возвращает все записи таблицы.
@external(erlang, "ets", "tab2list")
fn ets_tab2list(table: Atom) -> List(#(String, String, Bool))

// Удаляет запись по ключу. Возвращает true даже если ключ не существовал.
@external(erlang, "ets", "delete")
fn ets_delete_key(table: Atom, key: String) -> Bool

// ── Инициализация хранилища ──────────────────────────────────────────────────

/// Создаёт ETS-таблицу для хранения задач.
///
/// Опции:
///   set         — один ключ = одна запись (без дубликатов)
///   public      — любой процесс может читать и писать
///   named_table — таблица доступна по имени-атому, не только по ссылке
///
/// Атомы в Erlang/Gleam — интернированные константы. atom.create/1
/// создаёт атом в таблице атомов BEAM (никогда не GC), поэтому
/// используем статические имена, а не user input.
pub fn create_store(name: String) -> Atom {
  let table_name = atom.create(name)
  let options = [
    atom.to_dynamic(atom.create("set")),
    atom.to_dynamic(atom.create("public")),
    atom.to_dynamic(atom.create("named_table")),
  ]
  ets_new(table_name, options)
}

// ── CRUD поверх ETS ──────────────────────────────────────────────────────────

pub type Todo {
  Todo(id: String, title: String, completed: Bool)
}

/// Создаёт задачу и сохраняет в ETS.
/// Кортеж #(id, title, completed) — ETS-запись с ключом id.
pub fn insert_todo(table: Atom, title: String) -> Todo {
  let id = wisp.random_string(8)
  let item = Todo(id: id, title: title, completed: False)
  ets_insert(table, #(id, title, False))
  item
}

/// Читает все задачи из ETS.
/// ets:tab2list возвращает все кортежи; row.0/row.1/row.2 — поля кортежа.
pub fn list_all(table: Atom) -> List(Todo) {
  ets_tab2list(table)
  |> list.map(fn(row) { Todo(id: row.0, title: row.1, completed: row.2) })
}

/// Ищет задачу по id через ets:lookup (O(1) по хэшу).
pub fn find_todo(table: Atom, id: String) -> Option(Todo) {
  case ets_lookup(table, id) {
    [#(i, title, completed)] -> Some(Todo(id: i, title: title, completed:))
    _ -> None
  }
}

/// Обновляет поле completed. ETS insert перезаписывает запись целиком.
pub fn complete_todo(table: Atom, id: String) -> Option(Todo) {
  case find_todo(table, id) {
    None -> None
    Some(item) -> {
      ets_insert(table, #(item.id, item.title, True))
      Some(Todo(..item, completed: True))
    }
  }
}

/// Удаляет задачу из ETS.
pub fn remove_todo(table: Atom, id: String) -> Bool {
  ets_delete_key(table, id)
}

// ── Контекст приложения ──────────────────────────────────────────────────────

/// Контекст хранит имя ETS-таблицы.
/// Named table — атом-константа, поэтому Context можно передавать
/// через замыкания без накладных расходов.
pub type Context {
  Context(table: Atom)
}

// ── JSON-сериализация ────────────────────────────────────────────────────────

fn todo_to_json(t: Todo) -> json.Json {
  json.object([
    #("id", json.string(t.id)),
    #("title", json.string(t.title)),
    #("completed", json.bool(t.completed)),
  ])
}

// ── HTTP-обработчики ─────────────────────────────────────────────────────────

/// Health check: GET /health → 200 {"status":"ok"}
pub fn health_handler(_req: wisp.Request) -> wisp.Response {
  json.object([#("status", json.string("ok"))])
  |> json.to_string
  |> wisp.json_response(200)
}

/// GET /todos → 200 {"todos":[...]}
/// Читает все записи из ETS — O(n), параллельно с другими читателями.
pub fn list_todos_handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  let items = list_all(ctx.table)
  json.object([#("todos", json.array(items, todo_to_json))])
  |> json.to_string
  |> wisp.json_response(200)
}

/// POST /todos {"title":"..."} → 201 {"id":"...","title":"...","completed":false}
/// Вставка в ETS — O(1).
pub fn create_todo_handler(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  let title_decoder = {
    use title <- decode.field("title", decode.string)
    decode.success(title)
  }

  case decode.run(body, title_decoder) {
    Error(_) -> wisp.unprocessable_content()
    Ok(title) ->
      case string.trim(title) {
        "" -> wisp.unprocessable_content()
        t -> {
          let item = insert_todo(ctx.table, t)
          todo_to_json(item)
          |> json.to_string
          |> wisp.json_response(201)
        }
      }
  }
}

/// GET /todos/:id → 200 или 404
/// Lookup по ключу — O(1) в ETS.
pub fn get_todo_handler(
  req: wisp.Request,
  ctx: Context,
  id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)
  case find_todo(ctx.table, id) {
    None -> wisp.not_found()
    Some(item) ->
      todo_to_json(item)
      |> json.to_string
      |> wisp.json_response(200)
  }
}

/// DELETE /todos/:id → 204 или 404
pub fn delete_todo_handler(
  req: wisp.Request,
  ctx: Context,
  id: String,
) -> wisp.Response {
  use <- wisp.require_method(req, http.Delete)
  case find_todo(ctx.table, id) {
    None -> wisp.not_found()
    Some(_) -> {
      remove_todo(ctx.table, id)
      wisp.response(204)
    }
  }
}

// ── Middleware ────────────────────────────────────────────────────────────────

pub fn middleware(
  req: wisp.Request,
  handler: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  handler(req)
}

// ── Маршрутизатор ─────────────────────────────────────────────────────────────

pub fn router(req: wisp.Request, ctx: Context) -> wisp.Response {
  case wisp.path_segments(req) {
    ["health"] -> health_handler(req)
    ["todos"] ->
      case req.method {
        http.Get -> list_todos_handler(req, ctx)
        http.Post -> create_todo_handler(req, ctx)
        _ -> wisp.method_not_allowed([http.Get, http.Post])
      }
    ["todos", id] ->
      case req.method {
        http.Get -> get_todo_handler(req, ctx, id)
        http.Delete -> delete_todo_handler(req, ctx, id)
        _ -> wisp.method_not_allowed([http.Get, http.Delete])
      }
    _ -> wisp.not_found()
  }
}

// ── Точка входа ───────────────────────────────────────────────────────────────

pub fn main() {
  wisp.configure_logger()

  // Создаём ETS-таблицу при старте.
  // Named table "todos" доступна из любого процесса по имени-атому.
  let table = create_store("todos")
  let ctx = Context(table:)

  // Заполняем начальными данными.
  insert_todo(table, "Изучить Gleam")
  insert_todo(table, "Написать TODO API с ETS")
  insert_todo(table, "Почитать про BEAM")

  let secret = wisp.random_string(64)

  let assert Ok(_) =
    fn(req) { middleware(req, router(_, ctx)) }
    |> wisp_mist.handler(secret)
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
