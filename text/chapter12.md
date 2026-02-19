# Telegram-бот с Telega

> Полноценный Telegram-бот: команды, роутер, middleware, интеграция с Wisp и PostgreSQL.

## Цели главы

В этой главе мы:

- Познакомимся с Telega — библиотекой для Telegram-ботов на Gleam
- Научимся строить роутер для обработки команд и сообщений
- Разберём middleware для логирования, rate-limiting и авторизации
- Поймём, как интегрировать бота с Wisp через webhook
- Рассмотрим inline-клавиатуры и callback queries
- Построим TODO-бота с хранением данных в PostgreSQL

## Как работают Telegram-боты

Telegram предоставляет два способа получения обновлений:

| Метод | Описание | Когда использовать |
|-------|----------|-------------------|
| **Long polling** | Бот периодически спрашивает Telegram: «есть новые сообщения?» | Разработка, локальное тестирование |
| **Webhook** | Telegram отправляет POST-запросы на ваш сервер | Продакшен |

Telega поддерживает оба режима. Для webhook используется Wisp-адаптер.

## Первый бот

Установите зависимость:

```toml
[dependencies]
telega = ">= 0.1.0 and < 1.0.0"
wisp = ">= 1.0.0 and < 4.0.0"
mist = ">= 4.0.0 and < 6.0.0"
```

Простейший эхо-бот:

```gleam
import gleam/erlang/process
import gleam/option.{None}
import mist
import telega
import telega/adapters/wisp as telega_wisp
import telega/reply
import telega/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // Роутер с одним обработчиком — любой текст эхом
  let bot_router =
    router.new("echo_bot")
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx, text)
      Ok(ctx)
    })

  // Создаём бота с токеном и роутером
  let assert Ok(bot) =
    telega.new(token: "YOUR_BOT_TOKEN", url: "https://your-server.com", webhook_path: "/bot", secret_token: None)
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init()

  let assert Ok(_) =
    wisp_mist.handler(handle_request(bot, _), "secret_key_base")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(bot: telega.Telega(Nil, Nil), req: wisp.Request) -> wisp.Response {
  // Телега перехватывает запросы на webhook-путь
  use <- telega_wisp.handle_bot(bot, req)
  // Всё остальное — обычный Wisp
  wisp.not_found()
}
```

Бот отвечает эхом на любое текстовое сообщение — добавим обработку команд через роутер.

## Router — маршрутизация обновлений

`telega/router` — основной модуль для создания роутера. Роутер регистрирует обработчики для разных типов обновлений, а `telega.with_router` подключает его к боту:

```gleam
import telega
import telega/reply
import telega/router

pub fn build_bot(token: String, url: String) {
  // Строим роутер через цепочку пайпов
  let bot_router =
    router.new("my_bot")
    |> router.on_command("start", fn(ctx, _command) {
      let assert Ok(_) = reply.with_text(ctx, "Привет! Я готов к работе. /help для помощи.")
      Ok(ctx)
    })

  let assert Ok(bot) =
    telega.new(
      token: token,
      url: url,
      webhook_path: "/bot",
      secret_token: None,
    )
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init()

  bot
}
```

`router.new("name")` создаёт именованный роутер. Каждый `|> router.on_command(...)` добавляет обработчик и возвращает обновлённый роутер — чистая цепочка без мутаций.

### Команды

```gleam
import telega/reply
import telega/router

fn build_router() {
  router.new("my_bot")
  // /start
  |> router.on_command("start", fn(ctx, _command) {
    let assert Ok(_) = reply.with_text(ctx, "Добро пожаловать!")
    Ok(ctx)
  })
  // /help
  |> router.on_command("help", fn(ctx, _command) {
    let assert Ok(_) = reply.with_text(
      ctx,
      "Доступные команды:\n/start — начало\n/help — помощь\n/echo — повторить текст",
    )
    Ok(ctx)
  })
}
```

Каждый обработчик — обычная функция `fn(ctx, command) -> Result(ctx, error)`. `_command` — параметр с данными команды (`command.command`, `command.payload`), здесь он не нужен. Все хендлеры регистрируются цепочкой через `|>`.

### Обработка текстовых сообщений

```gleam
// Любой текст — text передаётся как аргумент обработчика
|> router.on_any_text(fn(ctx, text) {
  let assert Ok(_) = reply.with_text(ctx, "Вы написали: " <> text)
  Ok(ctx)
})

// Только если текст точно совпадает с "ping"
|> router.on_text(router.Exact("ping"), fn(ctx, _text) {
  let assert Ok(_) = reply.with_text(ctx, "pong!")
  Ok(ctx)
})
```

Текст сообщения передаётся вторым аргументом обработчика — не нужно обращаться к `ctx` чтобы его получить. `router.on_text` принимает паттерн: `Exact`, `Prefix`, `Contains` или `Suffix`.

### Pattern matching на сообщения

Внутри `on_any_text` можно делать `case` по тексту, если нужна своя диспетчеризация:

```gleam
import telega/bot.{type Context}
import telega/update.{type Command}

fn handle_any_text(ctx: Context(Nil, Nil), text: String) -> Result(Context(Nil, Nil), Nil) {
  case text {
    "ping" -> {
      let assert Ok(_) = reply.with_text(ctx, "pong!")
      Ok(ctx)
    }
    _ -> {
      let assert Ok(_) = reply.with_text(ctx, "Не понимаю: " <> text)
      Ok(ctx)
    }
  }
}

fn handle_command(ctx: Context(Nil, Nil), command: Command) -> Result(Context(Nil, Nil), Nil) {
  case command.command {
    "start" -> {
      let assert Ok(_) = reply.with_text(ctx, "Привет!")
      Ok(ctx)
    }
    _ -> {
      let assert Ok(_) = reply.with_text(ctx, "Неизвестная команда")
      Ok(ctx)
    }
  }
}
```

Pattern matching на `text` внутри одного обработчика — альтернатива нескольким `on_command`. Подходит для простых ботов; для сложных роутеров удобнее регистрировать обработчики по отдельности через `router.on_command`.

## Reply — отправка ответов

Модуль `telega/reply` предоставляет функции для отправки различных типов сообщений:

```gleam
import telega/reply

// Текстовое сообщение
let assert Ok(_) = reply.with_text(ctx, "Привет!")

// Текст с HTML-форматированием
let assert Ok(_) = reply.with_html(ctx, "<b>Жирный</b> текст")

// Текст с Markdown
let assert Ok(_) = reply.with_markdown(ctx, "*Жирный* текст")
```

Все функции `reply.*` возвращают `Result` — нужно обработать или `assert Ok`. Они отправляют ответ в тот же чат, из которого пришло обновление: `ctx` содержит идентификатор чата и клиент бота.

### Форматирование через fmt

Для сложного форматирования используйте `telega/format`:

```gleam
import telega/format as fmt
import telega/reply

fn send_welcome(ctx) {
  let message =
    fmt.build()
    |> fmt.bold_text("Привет! ")
    |> fmt.text("Я TODO-бот.")
    |> fmt.line_break()
    |> fmt.text("Используйте /list для просмотра задач.")
    |> fmt.to_formatted()

  let assert Ok(_) = reply.with_formatted(ctx, message)
  Ok(ctx)
}
```

`fmt.build()` создаёт билдер, каждый `|>` добавляет элемент. `to_formatted()` собирает итоговое сообщение с нужной разметкой.

### Inline-клавиатуры

```gleam
import telega/keyboard
import telega/reply

fn send_menu(ctx) {
  let kb =
    keyboard.inline_builder()
    |> keyboard.inline_button("Список задач", keyboard.string_callback_data("list"))
    |> keyboard.inline_button("Добавить", keyboard.string_callback_data("add"))
    |> keyboard.inline_build()

  let assert Ok(_) = reply.with_markup(ctx, "Выберите действие:", keyboard.inline_to_markup(kb))
  Ok(ctx)
}
```

`keyboard.inline_builder()` создаёт билдер для inline-клавиатуры. `string_callback_data` создаёт типобезопасные данные обратного вызова. `inline_to_markup` преобразует в формат Telegram.

### Обработка callback queries

```gleam
import gleam/option.{None, Some}
import telega
import telega/keyboard
import telega/model/types.{AnswerCallbackQueryParameters}
import telega/reply

fn show_menu_and_wait(ctx) {
  let callback_data = keyboard.string_callback_data("menu_action")
  let kb =
    keyboard.inline_builder()
    |> keyboard.inline_button("Список", keyboard.pack_callback(callback_data, "list"))
    |> keyboard.inline_build()

  use message <- try(reply.with_markup(ctx, "Меню:", keyboard.inline_to_markup(kb)))

  let assert Ok(filter) = keyboard.filter_inline_keyboard_query(kb)

  // Ожидаем нажатия кнопки
  use ctx, _payload, query_id <- telega.wait_callback_query(
    ctx:,
    filter: Some(filter),
    or: None,
    timeout: Some(30_000),
  )

  // Обязательно закрываем «часики» на кнопке
  let assert Ok(_) = reply.answer_callback_query(
    ctx,
    AnswerCallbackQueryParameters(
      callback_query_id: query_id,
      text: Some("Загружаю список..."),
      show_alert: None,
      url: None,
      cache_time: None,
    ),
  )
  Ok(ctx)
}
```

`telega.wait_callback_query` приостанавливает обработчик до нажатия кнопки — это «conversation flow». `reply.answer_callback_query` — обязательный ответ: Telegram ждёт его в течение нескольких секунд, иначе показывает значок загрузки.

## Middleware

Middleware в Telega — функции Wisp, которые выполняются до или после обработчика бота:

```gleam
fn middleware(bot, req, handle_request) {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use <- telega_wisp.handle_bot(bot, req)
  use req <- wisp.handle_head(req)
  handle_request(req)
}

fn handle_request(bot, req) {
  use req <- middleware(bot, req)
  case wisp.path_segments(req) {
    ["health"] -> wisp.ok()
    _ -> wisp.not_found()
  }
}
```

Middleware — функция высшего порядка через `use`-синтаксис. `telega_wisp.handle_bot` перехватывает webhook-запросы и передаёт их роутеру; всё, что не попало в бота, идёт дальше по цепочке Wisp.

### Фильтрация по пользователю

Фильтры на уровне роутера используйте через `router` API:

```gleam
import telega/router

// Пример: обработчик только для конкретных пользователей
let admin_router =
  router.new("admin")
  |> router.on_command("stats", fn(ctx, _command) {
    // Проверяем, является ли пользователь администратором
    let user_id = ctx.update.message
      |> option.map(fn(m) { m.from })
      |> option.flatten
      |> option.map(fn(u) { u.id })
    case user_id {
      option.Some(id) if list.contains(admin_ids, id) -> {
        let assert Ok(_) = reply.with_text(ctx, "Статистика: ...")
        Ok(ctx)
      }
      _ -> {
        let assert Ok(_) = reply.with_text(ctx, "Недостаточно прав.")
        Ok(ctx)
      }
    }
  })
```

### Rate limiting

```gleam
import gleam/dict

fn with_rate_limit(max_per_minute: Int) {
  // Состояние хранится в Dict user_id → счётчик
  // (упрощённый пример — в реальном боте используйте актора)
  fn(handler) {
    fn(ctx) {
      // Проверяем счётчик, вызываем handler или отклоняем
      handler(ctx)
    }
  }
}
```

Счётчик запросов нельзя хранить в замыкании — каждый вызов создаёт новый `dict`. Для корректного rate-limiting нужно общее мутабельное состояние, поэтому в реальных ботах используют актора (следующий раздел).

## Состояние бота через OTP

Для хранения состояния (сессий пользователей, данных в памяти) используем актора из главы 8:

```gleam
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

type SessionStore =
  dict.Dict(Int, UserSession)

type SessionMsg {
  GetSession(user_id: Int, reply: Subject(option.Option(UserSession)))
  SetSession(user_id: Int, session: UserSession)
  DeleteSession(user_id: Int)
}

pub type UserSession {
  UserSession(state: ConversationState, data: dict.Dict(String, String))
}

pub type ConversationState {
  Idle
  AwaitingTodoTitle
  AwaitingTodoId
}

fn handle_session_message(
  msg: SessionMsg,
  store: SessionStore,
) -> actor.Next(SessionMsg, SessionStore) {
  case msg {
    GetSession(user_id:, reply:) -> {
      process.send(reply, dict.get(store, user_id) |> result.to_option)
      actor.continue(store)
    }
    SetSession(user_id:, session:) ->
      actor.continue(dict.insert(store, user_id, session))
    DeleteSession(user_id:) ->
      actor.continue(dict.delete(store, user_id))
  }
}

pub fn start_session_store() -> Result(Subject(SessionMsg), actor.StartError) {
  actor.new(dict.new())
  |> actor.on_message(handle_session_message)
  |> actor.start
}
```

Бот хранит ссылку на актора в контексте:

```gleam
pub type AppContext {
  AppContext(
    bot: telega.Telega(Nil, Nil),
    sessions: Subject(SessionMsg),
    db: pog.Connection,
  )
}
```

`AppContext` передаётся в каждый обработчик через замыкание. Все три зависимости — бот, хранилище сессий и база данных — инициализируются в `main` и живут всё время работы сервера.

## Многошаговые диалоги

Часто бот должен собрать несколько ответов подряд (форма):

```gleam
fn handle_todo_command(ctx, sessions) {
  let user_id = get_user_id(ctx)

  // Устанавливаем состояние ожидания ввода
  actor.call(sessions, SetSession(user_id, UserSession(
    state: AwaitingTodoTitle,
    data: dict.new(),
  )), 1000)

  let assert Ok(_) = reply.with_text(ctx, "Введите название задачи:")
  Ok(ctx)
}

fn handle_text(ctx, sessions, db) {
  let user_id = get_user_id(ctx)
  let session = actor.call(sessions, GetSession(user_id, _), 1000)

  case session {
    option.Some(UserSession(state: AwaitingTodoTitle, ..)) -> {
      let title = get_text_from_ctx(ctx)
      // Сохранить задачу в БД
      let _ = sql.create_todo(db, title)
      actor.call(sessions, DeleteSession(user_id), 1000)
      let assert Ok(_) = reply.with_text(ctx, "Задача «" <> title <> "» добавлена!")
      Ok(ctx)
    }
    _ -> {
      // Обычный текст вне диалога
      let assert Ok(_) = reply.with_text(ctx, "Используйте /todo чтобы добавить задачу")
      Ok(ctx)
    }
  }
}
```

Состояние диалога (`AwaitingTodoTitle`) хранится в акторе сессий. Когда пользователь отправляет следующий текст, обработчик проверяет текущее состояние: это ответ в диалоге или обычный текст. После завершения диалога сессия удаляется, чтобы не занимать память.

## Проект: TODO-бот

Соберём полноценного бота с командами и хранением данных.

### Команды бота

| Команда | Действие |
|---------|----------|
| `/start` | Приветствие |
| `/help` | Список команд |
| `/list` | Показать задачи |
| `/add <задача>` | Добавить задачу |
| `/done <номер>` | Отметить как выполненную |
| `/clear` | Очистить выполненные |

### Структура проекта

```
src/
├── app.gleam          ← точка входа
├── bot.gleam          ← настройка бота и роутера
├── context.gleam      ← AppContext (db, sessions)
├── handlers/
│   ├── start.gleam    ← /start, /help
│   └── todos.gleam    ← /list, /add, /done, /clear
└── sessions.gleam     ← актор для сессий
```

Разделение на модули делает каждый слой независимым: `handlers/` содержат только бизнес-логику, `sessions.gleam` — хранилище состояния, `bot.gleam` — маршрутизацию. Чистая логика в `handlers/` легко тестируется без Telegram-соединения.

### bot.gleam

```gleam
import gleam/option.{None}
import telega
import telega/reply
import telega/router
import app/context.{type AppContext}
import app/handlers/todos

pub fn build(app_ctx: AppContext) -> Result(telega.Telega(Nil, Nil), String) {
  let token = os.get_env("TELEGRAM_TOKEN") |> result.unwrap("")
  let url = os.get_env("BOT_URL") |> result.unwrap("https://example.com")

  let bot_router =
    router.new("todo_bot")
    // /start
    |> router.on_command("start", fn(ctx, _command) {
      let assert Ok(_) = reply.with_text(ctx, "Привет! Я TODO-бот.\n\nКоманды:\n/list — список задач\n/add <текст> — добавить\n/help — помощь")
      Ok(ctx)
    })
    // /help
    |> router.on_command("help", fn(ctx, _command) {
      let assert Ok(_) = reply.with_text(ctx, "Доступные команды:\n/list — все задачи\n/add <задача> — добавить задачу\n/done <номер> — отметить выполненной\n/clear — очистить выполненные")
      Ok(ctx)
    })
    // /list
    |> router.on_command("list", fn(ctx, _command) {
      todos.handle_list(ctx, app_ctx)
    })
    // /add — команда с аргументом
    |> router.on_command("add", fn(ctx, command) {
      todos.handle_add(ctx, app_ctx, command)
    })

  use bot <- result.try(
    telega.new(
      token: token,
      url: url,
      webhook_path: "/bot",
      secret_token: None,
    )
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init(),
  )

  Ok(bot)
}
```

Роутер строится через цепочку `|> router.on_command(...)`. Замыкание захватывает `app_ctx`, передавая его в каждый обработчик. `use bot <- result.try(...)` распаковывает `Result` без вложенных `case`.

### handlers/todos.gleam

```gleam
import gleam/int
import gleam/list
import gleam/string
import telega/bot.{type Context}
import telega/reply
import telega/update.{type Command}
import app/context.{type AppContext}

pub fn handle_list(ctx: Context(Nil, Nil), app_ctx: AppContext) {
  let user_id = get_user_id(ctx)

  case sql.list_user_todos(app_ctx.db, user_id) {
    Error(_) -> {
      let assert Ok(_) = reply.with_text(ctx, "Ошибка загрузки задач.")
      Ok(ctx)
    }
    Ok(rows) ->
      case rows {
        [] -> {
          let assert Ok(_) = reply.with_text(ctx, "Список задач пуст. Добавьте задачу командой /add")
          Ok(ctx)
        }
        todos -> {
          let lines =
            todos
            |> list.index_map(fn(todo, i) {
              let status = case todo.completed {
                True -> "✅"
                False -> "☐"
              }
              status <> " " <> int.to_string(i + 1) <> ". " <> todo.title
            })
            |> string.join("\n")
          let assert Ok(_) = reply.with_text(ctx, "Ваши задачи:\n" <> lines)
          Ok(ctx)
        }
      }
  }
}

pub fn handle_add(ctx: Context(Nil, Nil), app_ctx: AppContext, command: Command) {
  let user_id = get_user_id(ctx)
  // Текст после /add (аргумент команды)
  let title = command.payload |> option.unwrap("")

  case string.trim(title) {
    "" -> {
      let assert Ok(_) = reply.with_text(ctx, "Укажите название: /add <задача>")
      Ok(ctx)
    }
    t ->
      case sql.create_user_todo(app_ctx.db, user_id, t) {
        Error(_) -> {
          let assert Ok(_) = reply.with_text(ctx, "Ошибка при сохранении.")
          Ok(ctx)
        }
        Ok(_) -> {
          let assert Ok(_) = reply.with_text(ctx, "✅ Задача «" <> t <> "» добавлена!")
          Ok(ctx)
        }
      }
  }
}
```

`handle_list` формирует нумерованный список с иконками статуса — всё через чистые строковые операции без мутаций. `handle_add` берёт аргумент команды из `command.payload` и отклоняет пустую строку до обращения к базе данных.

### app.gleam

```gleam
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist
import telega/adapters/wisp as telega_wisp
import app/bot
import app/context

pub fn main() {
  wisp.configure_logger()

  let app_ctx = context.new()

  let assert Ok(telegram_bot) = bot.build(app_ctx)

  let assert Ok(_) =
    wisp_mist.handler(handle_request(telegram_bot, _), "secret_key_base")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(telegram_bot, req) {
  use <- telega_wisp.handle_bot(telegram_bot, req)
  wisp.not_found()
}
```

`context.new()` инициализирует базу данных и запускает актора сессий. `bot.build(app_ctx)` собирает роутер. Telega-адаптер перехватывает запросы на `/bot` до основного роутера Wisp — всё остальное возвращает `not_found()`.

## Тестирование бота

Логику бота можно тестировать без реального Telegram-соединения:

```gleam
import gleeunit/should
import app/handlers/todos

// Тестируем чистую логику
pub fn format_todo_list_test() {
  todos.format_list([
    Todo(id: 1, title: "Купить молоко", completed: False),
    Todo(id: 2, title: "Написать тесты", completed: True),
  ])
  |> should.equal("☐ 1. Купить молоко\n✅ 2. Написать тесты")
}
```

Для интеграционного тестирования используют тестового бота в Telegram — создайте отдельный токен через [@BotFather](https://t.me/BotFather).

## Деплой

### Переменные окружения

```bash
export TELEGRAM_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
export BOT_URL="https://mybot.example.com"
export DB_HOST="localhost"
export DB_NAME="todos_bot"
export SECRET_KEY="your_64_char_secret"
```

Все секреты передаются через переменные окружения — ни один токен не хранится в коде. Приложение читает их через `os.get_env` при старте.

### Регистрация webhook

После запуска сервера зарегистрируйте webhook через Telegram API:

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/setWebhook" \
     -H "Content-Type: application/json" \
     -d '{"url": "https://mybot.example.com/bot"}'
```

Webhook регистрируется однократно после деплоя. Telegram начнёт отправлять POST-запросы на указанный URL при каждом новом обновлении от пользователей.

### Проверка webhook

```bash
curl "https://api.telegram.org/bot$TELEGRAM_TOKEN/getWebhookInfo"
```

Ответ покажет текущий URL webhook, статус соединения и количество необработанных обновлений. Если `pending_update_count` растёт — сервер не успевает обрабатывать входящие сообщения.

## Упражнения

Код упражнений находится в `exercises/chapter12/`.

```bash
cd exercises/chapter12
gleam test
```

---

**Упражнение 12.1** (Лёгкое): Парсинг команд бота

```gleam
pub type BotCommand {
  BotStart
  BotHelp
  BotTodo(text: String)
  BotUnknown(text: String)
}

pub fn parse_bot_command(text: String) -> BotCommand {
  todo
}
```

- `"/start"` → `BotStart`
- `"/help"` → `BotHelp`
- `"/todo buy milk"` → `BotTodo("buy milk")`
- любое другое → `BotUnknown(text)`

*Подсказка*: `case text { "/start" -> ... "/todo " <> rest -> ... }`.

---

**Упражнение 12.2** (Лёгкое): Форматирование списка задач

```gleam
pub fn format_todo_list(todos: List(String)) -> String {
  todo
}
```

- Пустой список → `"Список задач пуст."`
- Непустой → `"Ваши задачи:\n1. ...\n2. ..."`

*Подсказка*: `list.index_map`, `string.join`.

---

**Упражнение 12.3** (Лёгкое): Эхо-ответ

```gleam
pub fn echo_response(text: String) -> String {
  todo
}
```

Должна вернуть `"Вы сказали: <text>"`.

---

**Упражнение 12.4** (Среднее, самостоятельное): Бот с состоянием

Реализуйте бота, который:
- По команде `/counter` показывает текущее значение счётчика
- По команде `/inc` увеличивает счётчик на 1
- По команде `/reset` сбрасывает счётчик в 0

Используйте OTP-актора из главы 8 для хранения состояния.

---

**Упражнение 12.5** (Сложное, самостоятельное): TODO-бот с inline-клавиатурой

Расширьте TODO-бота:
- При `/list` показывайте задачи с inline-кнопками "Выполнить" и "Удалить"
- Обрабатывайте callback queries от кнопок
- Обновляйте сообщение после нажатия (редактирование через `reply.edit_text`)

## Итоги

Мы построили Telegram-бота, который объединяет все концепции из предыдущих глав:

- **Типобезопасность** — Gleam ловит ошибки на этапе компиляции
- **OTP** — акторы для состояния сессий (глава 8)
- **Wisp** — webhook-сервер (глава 10)
- **pog + Squirrel** — типобезопасная работа с PostgreSQL (глава 10)
- **gleam_json** — сериализация (глава 7)
- **Result и use** — обработка ошибок без исключений (глава 5)

Telega — зрелая библиотека, активно используемая в продакшене. Бот на Gleam работает на BEAM и наследует всю его отказоустойчивость: крэш обработчика одного сообщения не убивает весь сервер.

## Ресурсы

- [HexDocs — telega](https://hexdocs.pm/telega/)
- [Telega — GitHub](https://github.com/bondiano/telega-gleam)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Wisp — GitHub](https://github.com/gleam-wisp/wisp)
- [HexDocs — pog](https://hexdocs.pm/pog/)
