//// Здесь вы можете писать свои решения упражнений.
////
//// Запуск тестов: gleam test
//// После каждого упражнения запускайте тесты и смотрите, что проходит.

import wisp

// ── Упражнение 1 ─────────────────────────────────────────────────────────
// Реализуйте обработчик health check.
//
// GET /health должен вернуть:
//   статус 200
//   тело:  {"status":"ok"}
//
// Подсказка: wisp.ok(), wisp.json_response(body, status)
//            json.object([#("key", json.string("value"))]) |> json.to_string

pub fn health_handler(_req: wisp.Request) -> wisp.Response {
  todo
}

// ── Упражнение 2 ─────────────────────────────────────────────────────────
// Реализуйте эхо-обработчик.
//
// POST /echo с телом {"text":"..."} → 200 {"echo":"..."}
// GET /echo                          → 405 Method Not Allowed
// POST с отсутствующим полем "text"  → 422 Unprocessable Content
//
// Подсказка:
//   use <- wisp.require_method(req, http.Post)   — для проверки метода
//   use body <- wisp.require_json(req)           — для чтения JSON тела
//   decode.run(body, decoder)                    — для декодирования

pub fn echo_handler(req: wisp.Request) -> wisp.Response {
  todo
}

// ── Упражнение 3 ─────────────────────────────────────────────────────────
// Реализуйте обработчик списка задач.
//
// GET /todos → 200 {"todos":["title1","title2",...]}
// Другие методы → 405
//
// Подсказка: json.array(list, json.string) — кодирует список строк

pub fn list_todos_handler(
  req: wisp.Request,
  todos: List(String),
) -> wisp.Response {
  todo
}

// ── Упражнение 4 ─────────────────────────────────────────────────────────
// Реализуйте обработчик создания задачи.
//
// POST /todos с телом {"title":"..."} → 201 {"title":"..."}
// POST с отсутствующим полем          → 422
// GET/PUT/DELETE                      → 405
//
// Подсказка: wisp.created() возвращает ответ со статусом 201

pub fn create_todo_handler(req: wisp.Request) -> wisp.Response {
  todo
}

// ── Упражнение 5 ─────────────────────────────────────────────────────────
// Реализуйте маршрутизатор.
//
// GET  /health      → 200 {"status":"ok"}
// GET  /todos       → 200 {"todos":[]}       (передайте пустой список)
// POST /todos       → делегировать create_todo_handler
// GET  /todos/:id   → 200 {"id":"<id>"}
// всё остальное     → 404
//
// Подсказка:
//   wisp.path_segments(req) — возвращает List(String) сегментов пути
//   case wisp.path_segments(req) { ["health"] -> ... ["todos", id] -> ... }

pub fn router(req: wisp.Request) -> wisp.Response {
  todo
}
