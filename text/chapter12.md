# Веб-разработка с Wisp

> REST API, типобезопасные маршруты и PostgreSQL — всё в одном проекте.

<!-- toc -->

## Цели главы

В этой главе мы:

- Познакомимся с Wisp — практичным веб-фреймворком для Gleam
- Научимся строить маршруты через pattern matching (без DSL)
- Разберём middleware-цепочки через `use`-выражения
- Изучим работу с JSON в HTTP-запросах и ответах
- Поймём, как подключить PostgreSQL через `pog`
- Познакомимся со Squirrel — type-safe codegen для SQL
- Построим полноценный TODO API с CRUD-операциями

## Стек: Wisp + Mist + pog

Веб-стек Gleam строится из трёх независимых слоёв:

| Слой | Библиотека | Роль |
| ------ | ----------- | ------ |
| HTTP-сервер | `mist` | TCP/HTTP-транспорт |
| Веб-фреймворк | `wisp` | Маршруты, middleware, запросы/ответы |
| База данных | `pog` | PostgreSQL-клиент |
| SQL codegen | `squirrel` | Type-safe SQL из `.sql` файлов |

Такое разделение обязанностей позволяет использовать каждый компонент независимо. Wisp работает с любым HTTP-сервером, совместимым с интерфейсом `gleam_http`.

Добавьте зависимости в `gleam.toml`:

```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_erlang = ">= 0.34.0 and < 2.0.0"
gleam_http = ">= 3.0.0 and < 5.0.0"
gleam_json = ">= 2.0.0 and < 4.0.0"
wisp = ">= 1.0.0 and < 4.0.0"
mist = ">= 4.0.0 and < 6.0.0"
pog = ">= 1.0.0 and < 2.0.0"
```

`wisp` — фреймворк, `mist` — HTTP-сервер, `pog` — PostgreSQL-драйвер, `gleam_http` и `gleam_json` — работа с HTTP-типами и JSON.

## Первый обработчик

Wisp строится вокруг функции-обработчика с сигнатурой `fn(Request) -> Response`:

```gleam
import wisp

pub fn hello_handler(req: wisp.Request) -> wisp.Response {
  wisp.ok()
  |> wisp.string_body("Hello, Gleam!")
}
```

Запустим сервер через Mist:

```gleam
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let assert Ok(_) =
    wisp_mist.handler(hello_handler, "secret_key_base_here")
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http

  process.sleep_forever()
}
```

`wisp.configure_logger()` настраивает структурированный логгер — рекомендуется вызывать в начале программы.

## Маршрутизация через pattern matching

В Wisp нет DSL для маршрутов — используется обычный `case` по результату `wisp.path_segments`:

```gleam
pub fn router(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    // GET /
    [] -> home_page(req)

    // /api/todos (GET или POST)
    ["api", "todos"] -> todos_resource(req)

    // /api/todos/:id (GET, PUT, DELETE)
    ["api", "todos", id] -> todo_resource(req, id)

    // /health
    ["health"] -> health_check(req)

    // всё остальное — 404
    _ -> wisp.not_found()
  }
}
```

Для разделения методов используется `req.method`:

```gleam
import gleam/http

pub fn todos_resource(req: wisp.Request) -> wisp.Response {
  case req.method {
    http.Get -> list_todos(req)
    http.Post -> create_todo(req)
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}
```

Это стандартный Gleam: никакой магии, никакого отражения — только pattern matching.

## Middleware через use-выражения

Wisp middleware — это функции вида `fn(handler) -> Response`. Они отлично сочетаются с `use`:

```gleam
pub fn handle_request(req: wisp.Request) -> wisp.Response {
  // Логирует запрос
  use <- wisp.log_request(req)
  // Оборачивает крэш в 500-ответ
  use <- wisp.rescue_crashes
  // Обрабатывает HEAD как GET (стандартное поведение HTTP)
  use req <- wisp.handle_head(req)

  router(req)
}
```

Каждый `use <-` добавляет слой обработки. Выполнение идёт сверху вниз при входящем запросе и снизу вверх при формировании ответа — ровно как в традиционных middleware-стеках.

### Статические файлы

```gleam
use <- wisp.serve_static(req, under: "/static", from: priv_directory)
```

Wisp проверяет, соответствует ли путь запроса `under` — и если да, возвращает файл из `from`-директории, не доходя до роутера. Если нет — выполнение продолжается дальше.

### Ограничение размера тела

```gleam
use <- wisp.require_content_type(req, "application/json")
```

Если заголовок `Content-Type` не совпадает с ожидаемым, Wisp автоматически вернёт `415 Unsupported Media Type`. Это защищает обработчики от неожиданных форматов до того, как они начнут читать тело запроса.

## Разбор тела запроса

### JSON

```gleam
import gleam/dynamic/decode
import gleam/json

pub type CreateTodoInput {
  CreateTodoInput(title: String, completed: Bool)
}

fn create_todo_input_decoder() {
  use title <- decode.field("title", decode.string)
  use completed <- decode.field("completed", decode.bool)
  decode.success(CreateTodoInput(title:, completed:))
}

pub fn create_todo(req: wisp.Request) -> wisp.Response {
  use json_body <- wisp.require_json(req)

  case json.parse_bits(json_body, create_todo_input_decoder()) {
    Error(_) -> wisp.unprocessable_entity()
    Ok(input) -> {
      // ... сохранить в БД и вернуть ответ
      let response_json = json.object([
        #("title", json.string(input.title)),
        #("completed", json.bool(input.completed)),
      ])
      wisp.created()
      |> wisp.json_response(json.to_string(response_json), 201)
    }
  }
}
```

`wisp.require_json` читает тело и проверяет Content-Type. Если тело не JSON — автоматически возвращает 415 Unsupported Media Type.

### Query-параметры

```gleam
import gleam/uri

pub fn list_todos(req: wisp.Request) -> wisp.Response {
  let params = wisp.get_query(req)
  // params: List(#(String, String))

  let page =
    params
    |> list.key_find("page")
    |> result.try(int.parse)
    |> result.unwrap(1)

  // ... получить данные с пагинацией
  todo
}
```

`wisp.get_query` возвращает список пар `#(key, value)`. Цепочка `list.key_find` → `result.try(int.parse)` → `result.unwrap(1)` безопасно извлекает числовой параметр с дефолтным значением, не роняя запрос при невалидных данных.

### Формы

```gleam
pub fn handle_form(req: wisp.Request) -> wisp.Response {
  use form <- wisp.require_form(req)
  // form.values: List(#(String, String))
  // form.files: List(#(String, wisp.UploadedFile))

  case list.key_find(form.values, "title") {
    Ok(title) -> save_todo(title)
    Error(_) -> wisp.bad_request()
  }
}
```

`wisp.require_form` декодирует как `application/x-www-form-urlencoded`, так и `multipart/form-data`. Загруженные файлы доступны через `form.files` с типом `wisp.UploadedFile`.

## Формирование ответов

Wisp предоставляет функции для всех стандартных HTTP-статусов:

```gleam
// 2xx
wisp.ok()               // 200
wisp.created()          // 201
wisp.no_content()       // 204

// 3xx
wisp.redirect(to: "/login")  // 302

// 4xx
wisp.bad_request()           // 400
wisp.not_found()             // 404
wisp.method_not_allowed([http.Get, http.Post])  // 405
wisp.unprocessable_entity()  // 422
wisp.too_many_requests()     // 429

// 5xx
wisp.internal_server_error() // 500
```

Тело ответа задаётся через pipe:

```gleam
wisp.ok()
|> wisp.string_body("Hello!")

wisp.ok()
|> wisp.html_body("<h1>Hello!</h1>")

// JSON с явным статусом
wisp.response(200)
|> wisp.set_header("content-type", "application/json")
|> wisp.string_body("{\"ok\":true}")

// Удобный помощник для JSON
wisp.json_response(json_string, 200)
```

`wisp.json_response` — сокращение, которое одновременно устанавливает статус, заголовок `content-type: application/json` и тело. Все остальные методы можно комбинировать через pipe: сначала выбрать статус (`wisp.ok()`, `wisp.response(200)`), затем добавить тело.

## Контекст приложения

В реальных приложениях обработчикам нужны общие ресурсы: подключение к БД, настройки, кэши. Стандартный паттерн в Wisp — передавать контекст явно:

```gleam
pub type Context {
  Context(db: pog.Connection)
}

pub fn router(req: wisp.Request, ctx: Context) -> wisp.Response {
  case wisp.path_segments(req) {
    ["api", "todos"] -> todos_resource(req, ctx)
    _ -> wisp.not_found()
  }
}
```

А при запуске сервера используем замыкание:

```gleam
pub fn main() {
  let db = connect_db()
  let ctx = Context(db:)

  let assert Ok(_) =
    fn(req) { handle_request(req, ctx) }
    |> wisp_mist.handler("secret_key_base")
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http

  process.sleep_forever()
}
```

Замыкание `fn(req) { handle_request(req, ctx) }` — ключевой паттерн: Mist требует функцию `fn(Request) -> Response`, а Wisp-обработчик принимает дополнительный аргумент `ctx`. Замыкание захватывает `ctx` и превращает двуаргументную функцию в одноаргументную. `process.sleep_forever()` не даёт процессу завершиться — сервер работает, пока запущены порождённые им акторы.

## ETS — встроенная in-memory база данных BEAM

До того как подключать PostgreSQL, стоит познакомиться с ETS (Erlang Term Storage) — таблицами, встроенными прямо в BEAM. Это классическая точка входа в экосистему Erlang.

| Свойство | ETS | PostgreSQL (pog) |
| ---------- | ----- | ----------------- |
| Хранение | Оперативная память | Диск |
| Скорость чтения по ключу | O(1) | ~1–5 мс |
| Выживает после рестарта | Нет | Да |
| SQL, транзакции | Нет | Да |
| Сложность запуска | Нулевая | Нужен сервер БД |

ETS идеален для: кэша, хранилища сессий, счётчиков, rate limiting, временных данных.

### ETS через @external FFI

Gleam вызывает Erlang-функции через `@external`. ETS хранит **кортежи** — в Gleam они записываются как `#(a, b, c)` и компилируются в Erlang tuples `{a, b, c}`. Первый элемент — ключ.

```gleam
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}

// ets:new(Name, Options) — создаёт таблицу, возвращает имя-атом
@external(erlang, "ets", "new")
fn ets_new(name: Atom, options: List(Dynamic)) -> Atom

// ets:insert(Table, {Key, Field1, Field2}) — вставляет/обновляет запись
@external(erlang, "ets", "insert")
fn ets_insert(table: Atom, record: #(String, String, Bool)) -> Bool

// ets:lookup(Table, Key) — O(1) поиск по ключу
@external(erlang, "ets", "lookup")
fn ets_lookup(table: Atom, key: String) -> List(#(String, String, Bool))

// ets:tab2list(Table) — все записи
@external(erlang, "ets", "tab2list")
fn ets_tab2list(table: Atom) -> List(#(String, String, Bool))

// ets:delete(Table, Key) — удалить по ключу
@external(erlang, "ets", "delete")
fn ets_delete_key(table: Atom, key: String) -> Bool
```

### Атомы как идентификаторы

Опции `ets:new` — атомы Erlang. В Gleam атомы создаются через `atom.create/1`:

```gleam
pub fn create_store(name: String) -> Atom {
  let table_name = atom.create(name)
  // set         — один ключ = одна запись
  // public      — чтение/запись из любого процесса
  // named_table — доступна по имени без ссылки
  let options = [
    atom.to_dynamic(atom.create("set")),
    atom.to_dynamic(atom.create("public")),
    atom.to_dynamic(atom.create("named_table")),
  ]
  ets_new(table_name, options)
}
```

> Атомы в BEAM никогда не уничтожаются GC. Лимит ~1 миллион. Создавайте
> только константы, никогда — из пользовательского ввода.

### CRUD поверх ETS

```gleam
pub type Todo {
  Todo(id: String, title: String, completed: Bool)
}

pub fn insert_todo(table: Atom, title: String) -> Todo {
  let id = wisp.random_string(8)
  // Кортеж #(id, title, False) сохраняется как Erlang tuple {id, title, false}
  ets_insert(table, #(id, title, False))
  Todo(id:, title:, completed: False)
}

pub fn find_todo(table: Atom, id: String) -> option.Option(Todo) {
  case ets_lookup(table, id) {
    [#(i, title, completed)] -> option.Some(Todo(id: i, title:, completed:))
    _ -> option.None
  }
}

pub fn list_all(table: Atom) -> List(Todo) {
  ets_tab2list(table)
  |> list.map(fn(row) { Todo(id: row.0, title: row.1, completed: row.2) })
}
```

ETS-таблица создаётся один раз при старте и передаётся в контексте:

```gleam
pub type Context {
  Context(table: Atom)
}

pub fn main() {
  let table = create_store("todos")
  let ctx = Context(table:)

  let assert Ok(_) =
    fn(req) { middleware(req, router(_, ctx)) }
    |> wisp_mist.handler(wisp.random_string(64))
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
```

Полная рабочая реализация — в `exercises/chapter10/src/chapter10.gleam`.

## pog — PostgreSQL-клиент

`pog` — идиоматический PostgreSQL-клиент для Gleam:

```gleam
import pog

pub fn connect() -> pog.Connection {
  pog.default_config()
  |> pog.host("localhost")
  |> pog.port(5432)
  |> pog.database("gleam_todos")
  |> pog.user("postgres")
  |> pog.password(option.Some("password"))
  |> pog.connect
}
```

`pog` использует builder-паттерн: `pog.default_config()` создаёт конфиг с разумными значениями по умолчанию (localhost:5432), а pipe-цепочка переопределяет нужные параметры. `pog.connect` запускает пул соединений — возвращаемый `pog.Connection` потокобезопасен и предназначен для переиспользования.

### Запросы вручную

```gleam
pub fn get_todo(db: pog.Connection, id: Int) -> Result(Todo, pog.QueryError) {
  let sql = "SELECT id, title, completed FROM todos WHERE id = $1"

  use response <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(id))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      use title <- decode.field(1, decode.string)
      use completed <- decode.field(2, decode.bool)
      decode.success(Todo(id:, title:, completed:))
    })
    |> pog.execute(db),
  )

  case response.rows {
    [todo] -> Ok(todo)
    [] -> Error(pog.UnexpectedResultCount(expected: 1, got: 0))
    _ -> Error(pog.UnexpectedResultCount(expected: 1, got: list.length(response.rows)))
  }
}
```

Запрос строится через pipe: `pog.query(sql)` задаёт SQL, `pog.parameter` добавляет типизированные параметры (защита от SQL-инъекций), `pog.returning` задаёт декодер для строк результата, `pog.execute(db)` выполняет запрос. Результат `response.rows` — список декодированных строк; мы ожидаем ровно одну.

### Вставка

```gleam
pub fn create_todo(
  db: pog.Connection,
  title: String,
) -> Result(Todo, pog.QueryError) {
  let sql =
    "INSERT INTO todos (title, completed) VALUES ($1, false) RETURNING id, title, completed"

  use response <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.text(title))
    |> pog.returning(todo_decoder())
    |> pog.execute(db),
  )

  case response.rows {
    [todo] -> Ok(todo)
    _ -> Error(pog.UnexpectedResultCount(expected: 1, got: 0))
  }
}
```

`RETURNING` в SQL позволяет сразу получить вставленную строку — не нужен отдельный `SELECT`. Тот же паттерн используется для `UPDATE ... RETURNING`: вместо двух запросов один возвращает изменённые данные.

## Squirrel — type-safe SQL

Писать SQL в строках — источник ошибок: опечатки не проверяются компилятором, типы колонок нужно указывать вручную. Squirrel решает это.

### Как работает Squirrel

1. Создаёте `.sql` файлы в `src/<module>/sql/`
2. Запускаете `gleam run -m squirrel`
3. Squirrel подключается к БД, проверяет запросы и генерирует типизированные функции

```text
src/
└── app/
    ├── sql/
    │   ├── list_todos.sql
    │   ├── get_todo.sql
    │   ├── create_todo.sql
    │   └── delete_todo.sql
    └── sql.gleam        ← сгенерированный файл
```

SQL-файлы — единственное место, где пишется SQL вручную. Squirrel читает схему БД, проверяет типы параметров и колонок, после чего генерирует `sql.gleam` с типизированными функциями.

### Пример SQL-файла

```sql
-- src/app/sql/list_todos.sql
SELECT id, title, completed
FROM todos
ORDER BY id ASC
```

После генерации получаем:

```gleam
// src/app/sql.gleam (сгенерировано автоматически)
import gleam/dynamic/decode
import pog

pub type ListTodosRow {
  ListTodosRow(id: Int, title: String, completed: Bool)
}

pub fn list_todos(db: pog.Connection) -> Result(List(ListTodosRow), pog.QueryError) {
  let sql = "SELECT id, title, completed FROM todos ORDER BY id ASC"
  // ... генерированный код
}
```

Squirrel генерирует строго типизированный тип строки (`ListTodosRow`) и функцию с декодером — ошибки маппинга столбцов выявляются при регенерации, а не в рантайме.

### Параметризованные запросы

```sql
-- src/app/sql/get_todo.sql
SELECT id, title, completed
FROM todos
WHERE id = $1
```

Squirrel видит тип `$1` из схемы БД и генерирует:

```gleam
pub fn get_todo(
  db: pog.Connection,
  id: Int,
) -> Result(List(GetTodoRow), pog.QueryError)
```

Теперь передать строку вместо Int — ошибка компиляции.

## Проект: TODO API

Соберём всё вместе в полноценный REST API.

### Структура проекта

```text
src/
├── app.gleam          ← точка входа
├── router.gleam       ← маршрутизация
├── context.gleam      ← тип Context
├── handlers/
│   └── todos.gleam    ← обработчики /api/todos
└── sql/
    ├── list_todos.sql
    ├── get_todo.sql
    ├── create_todo.sql
    ├── update_todo.sql
    └── delete_todo.sql
```

Разделение по слоям: `context.gleam` управляет зависимостями, `router.gleam` — маршрутизацией, `handlers/` — бизнес-логикой, `sql/` — запросами к БД. Каждый слой знает только о нижележащем.

### context.gleam

```gleam
import pog

pub type Context {
  Context(db: pog.Connection)
}

pub fn new() -> Context {
  let db =
    pog.default_config()
    |> pog.host("localhost")
    |> pog.database("gleam_todos")
    |> pog.connect

  Context(db:)
}
```

`context.new()` инициализирует пул соединений с БД при старте приложения. `Context` как тип позволяет передавать зависимости явно в каждый обработчик — без глобального состояния.

### router.gleam

```gleam
import gleam/http
import wisp
import app/context.{type Context}
import app/handlers/todos

pub fn handle_request(req: wisp.Request, ctx: Context) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  case wisp.path_segments(req) {
    ["health"] -> wisp.json_response("{\"status\":\"ok\"}", 200)
    ["api", "todos"] ->
      case req.method {
        http.Get -> todos.list(req, ctx)
        http.Post -> todos.create(req, ctx)
        _ -> wisp.method_not_allowed([http.Get, http.Post])
      }
    ["api", "todos", id] ->
      case req.method {
        http.Get -> todos.get(req, ctx, id)
        http.Put -> todos.update(req, ctx, id)
        http.Delete -> todos.delete(req, ctx, id)
        _ -> wisp.method_not_allowed([http.Get, http.Put, http.Delete])
      }
    _ -> wisp.not_found()
  }
}
```

`wisp.log_request` и `wisp.rescue_crashes` — middleware, которые добавляются через `use <-`. `wisp.handle_head` автоматически обрабатывает HEAD-запросы как GET без тела ответа. Маршрутизация строится через `wisp.path_segments` и pattern matching.

### handlers/todos.gleam

```gleam
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import wisp
import app/context.{type Context}

pub type Todo {
  Todo(id: Int, title: String, completed: Bool)
}

fn todo_to_json(todo: Todo) -> json.Json {
  json.object([
    #("id", json.int(todo.id)),
    #("title", json.string(todo.title)),
    #("completed", json.bool(todo.completed)),
  ])
}

pub fn list(_req: wisp.Request, ctx: Context) -> wisp.Response {
  // Squirrel-генерированная функция
  case sql.list_todos(ctx.db) {
    Error(_) -> wisp.internal_server_error()
    Ok(rows) -> {
      let todos_json =
        rows
        |> list.map(fn(row) {
          json.object([
            #("id", json.int(row.id)),
            #("title", json.string(row.title)),
            #("completed", json.bool(row.completed)),
          ])
        })
        |> json.array
        |> json.to_string

      wisp.json_response(todos_json, 200)
    }
  }
}

pub fn create(req: wisp.Request, ctx: Context) -> wisp.Response {
  use body <- wisp.require_json(req)

  let decoder = {
    use title <- decode.field("title", decode.string)
    decode.success(title)
  }

  case json.parse_bits(body, decoder) {
    Error(_) -> wisp.unprocessable_entity()
    Ok(title) ->
      case sql.create_todo(ctx.db, title) {
        Error(_) -> wisp.internal_server_error()
        Ok([row]) -> {
          let response =
            json.object([
              #("id", json.int(row.id)),
              #("title", json.string(row.title)),
              #("completed", json.bool(row.completed)),
            ])
            |> json.to_string
          wisp.json_response(response, 201)
        }
        Ok(_) -> wisp.internal_server_error()
      }
  }
}
```

`list` возвращает массив JSON с кодом 200. `create` требует JSON-тело, декодирует поле `title` и возвращает созданный объект с кодом 201. При любой ошибке парсинга Wisp автоматически отвечает 422 Unprocessable Entity.

### app.gleam — точка входа

```gleam
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist
import app/context
import app/router

pub fn main() {
  wisp.configure_logger()

  let ctx = context.new()

  let secret_key_base = "your_64_char_secret_key_here"

  let assert Ok(_) =
    fn(req) { router.handle_request(req, ctx) }
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http

  process.sleep_forever()
}
```

`context.new()` инициализирует зависимости, затем сервер монтируется через замыкание. `process.sleep_forever()` удерживает главный процесс — без него BEAM завершится сразу после старта сервера.

### Создание схемы БД

```sql
CREATE TABLE todos (
  id        SERIAL PRIMARY KEY,
  title     TEXT    NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE
);
```

`SERIAL PRIMARY KEY` автоматически генерирует уникальный `id` для каждой строки. `NOT NULL` гарантирует, что приложение не сохранит задачу без названия. `DEFAULT FALSE` позволяет не указывать `completed` при вставке.

## Переменные окружения

В продакшене настройки берут из окружения:

```gleam
import gleam/erlang/os

fn db_config() -> pog.Config {
  let host = os.get_env("DB_HOST") |> result.unwrap("localhost")
  let port =
    os.get_env("DB_PORT")
    |> result.try(int.parse)
    |> result.unwrap(5432)
  let name = os.get_env("DB_NAME") |> result.unwrap("todos")

  pog.default_config()
  |> pog.host(host)
  |> pog.port(port)
  |> pog.database(name)
}
```

`os.get_env` возвращает `Result(String, Nil)` — если переменная не задана, `result.unwrap` подставляет дефолт. В продакшене следует использовать `result.try` или `let assert Ok(...)` для обязательных переменных.

## Упражнения

Код упражнений находится в `exercises/chapter10/`.

### Структура

Файл `test/my_solutions.gleam` содержит шаблоны функций с `todo`. Запустите тесты:

```bash
cd exercises/chapter10
gleam test
```

Тесты завершатся с ошибкой — заполните функции в `test/my_solutions.gleam`.

---

**Упражнение 10.1** (Лёгкое): Health-check body

Функция `health_check_body() -> String` должна вернуть JSON-строку `{"status":"ok"}`.

```gleam
pub fn health_check_body() -> String {
  todo
}
```

*Подсказка*: используйте `json.object` и `json.to_string` из `gleam_json`.

---

**Упражнение 10.2** (Лёгкое): Парсинг JSON в тип

```gleam
pub type Todo {
  Todo(title: String, completed: Bool)
}

pub fn parse_todo(s: String) -> Result(Todo, Nil) {
  todo
}
```

*Подсказка*: `json.parse` + `decode.field`.

---

**Упражнение 10.3** (Лёгкое): Сериализация в JSON

```gleam
pub fn todo_to_json_string(t: Todo) -> String {
  todo
}
```

*Подсказка*: `json.object` с полями `title` и `completed`.

---

**Упражнение 10.4** (Среднее, для самостоятельного изучения): Middleware для замера времени

Реализуйте middleware, который добавляет заголовок `X-Response-Time` с временем обработки в миллисекундах. Интеграция с Wisp требует системного времени через FFI.

---

**Упражнение 10.5** (Сложное, для самостоятельного изучения): Auth middleware

Реализуйте middleware `require_auth`, который проверяет наличие Bearer-токена в заголовке `Authorization`. Без корректного токена — 401 Unauthorized.

## Итоги

Мы построили REST API с:

- **Wisp** для маршрутизации и middleware
- **pog** для PostgreSQL
- **Squirrel** для type-safe SQL (codegen из `.sql` файлов)
- **gleam_json** + **gleam/dynamic/decode** для сериализации

Ключевые паттерны Gleam в веб-разработке:

- Маршруты — это `case` по `wisp.path_segments(req)`, никакого DSL
- Middleware — это `use <- middleware(req)`, использование `use`-выражений
- Контекст — явный параметр `ctx: Context`, никакого глобального состояния
- Ошибки — `Result`, никаких исключений

## Ресурсы

- [Wisp — официальная документация](https://gleam-wisp.github.io/wisp/)
- [HexDocs — wisp](https://hexdocs.pm/wisp/)
- [HexDocs — pog](https://hexdocs.pm/pog/)
- [Squirrel — GitHub](https://github.com/giacomocavalieri/squirrel)
- [HexDocs — gleam_json](https://hexdocs.pm/gleam_json/)
- [Gleam web app tutorial](https://blog.andreyfadeev.com/p/gleam-web-application-development-tutorial)
