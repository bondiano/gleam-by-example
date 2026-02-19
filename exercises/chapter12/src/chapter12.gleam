// Примеры: реальный TODO-бот на Telega v0.14
//
// Для запуска замените "YOUR_BOT_TOKEN" на токен от @BotFather, затем `gleam run`.
// Тесты упражнений (my_solutions.gleam) проверяют чистую логику независимо от этого файла.
//
// Ключевые паттерны Telega:
//   1. Polling: new_for_polling → with_router → init_for_polling_nil_session
//   2. Router: router.new → on_command / on_any_text
//   3. Ответы: reply.with_text(ctx, text)
//   4. Многошаговый диалог: telega.wait_text / telega.wait_number
//   5. Логирование контекста: telega.log_context(ctx, "label")

import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string

import telega
import telega/polling
import telega/reply
import telega/router
import telega/update.{type Command}

// ── 1. Точка входа ──────────────────────────────────────────────────────────

/// Запускает TODO-бота в режиме long polling.
///
/// Архитектура polling-бота:
///   new_for_polling(token)   — создаёт конфигурацию без webhook
///   with_router(router)      — подключает обработчики
///   init_for_polling_nil_session() — запускает бота (сессия = Nil)
///   start_polling_default(bot) — запускает цикл опроса Telegram API
///   wait_finish(poller)      — блокирует до завершения
pub fn main() {
  let todo_router =
    router.new("todo_bot")
    |> router.on_command("start", handle_start)
    |> router.on_command("help", handle_help)
    |> router.on_command("add", handle_add)
    |> router.on_command("done", handle_done)
    |> router.on_any_text(handle_unknown)

  let assert Ok(bot) =
    telega.new_for_polling(token: "YOUR_BOT_TOKEN")
    |> telega.with_router(todo_router)
    |> telega.init_for_polling_nil_session()

  let assert Ok(poller) = polling.start_polling_default(bot)
  polling.wait_finish(poller)
}

// ── 2. Обработчики команд ───────────────────────────────────────────────────
//
// Сигнатура командного обработчика: fn(ctx, cmd: Command) -> Result(ctx, error)
// log_context добавляет метку к логам этого обработчика.

fn handle_start(ctx, _cmd: Command) {
  use ctx <- telega.log_context(ctx, "start")
  let assert Ok(_) =
    reply.with_text(
      ctx,
      "Привет! Я TODO-бот 📝\n\n"
        <> "Команды:\n"
        <> "/add — добавить задачу\n"
        <> "/done — отметить выполненной\n"
        <> "/help — список команд",
    )
  Ok(ctx)
}

fn handle_help(ctx, _cmd: Command) {
  use ctx <- telega.log_context(ctx, "help")
  let assert Ok(_) =
    reply.with_text(
      ctx,
      "Доступные команды:\n"
        <> "/add — добавить новую задачу\n"
        <> "/done — отметить задачу выполненной\n"
        <> "/help — это сообщение",
    )
  Ok(ctx)
}

/// /add — многошаговый диалог через telega.wait_text.
///
/// Паттерн wait_text:
///   1. reply.with_text — отправляем запрос пользователю
///   2. use ctx, title <- telega.wait_text(...)
///      — приостанавливаем обработчик, ждём следующего текстового сообщения
///   3. Когда пользователь ответил — продолжаем со следующей строки
///
/// or: None   — нет fallback-обработчика для нетекстовых сообщений
/// timeout: None — ожидание без ограничения по времени
fn handle_add(ctx, _cmd: Command) {
  use ctx <- telega.log_context(ctx, "add")
  let assert Ok(_) = reply.with_text(ctx, "Введите название задачи:")

  use ctx, title <- telega.wait_text(ctx, or: None, timeout: None)

  let title = string.trim(title)
  case title {
    "" -> {
      let assert Ok(_) =
        reply.with_text(ctx, "Название не может быть пустым. Попробуйте снова.")
      Ok(ctx)
    }
    t -> {
      let assert Ok(_) =
        reply.with_text(ctx, "✅ Задача «" <> t <> "» добавлена!")
      Ok(ctx)
    }
  }
}

/// /done — многошаговый диалог через telega.wait_number.
///
/// wait_number автоматически:
///   - проверяет, что ввод является целым числом
///   - валидирует диапазон (min/max), если задан
///   - повторяет запрос при невалидном вводе
///
/// В данном примере min/max = None — принимаем любое число.
fn handle_done(ctx, _cmd: Command) {
  use ctx <- telega.log_context(ctx, "done")
  let assert Ok(_) = reply.with_text(ctx, "Введите номер задачи:")

  use ctx, n <- telega.wait_number(
    ctx,
    min: None,
    max: None,
    or: None,
    timeout: None,
  )
  let assert Ok(_) =
    reply.with_text(ctx, "✅ Задача " <> int.to_string(n) <> " выполнена!")
  Ok(ctx)
}

/// Обработчик произвольного текста вне команд.
///
/// router.on_any_text — перехватывает все текстовые сообщения,
/// не совпавшие с предыдущими правилами роутера.
fn handle_unknown(ctx, text: String) {
  use ctx <- telega.log_context(ctx, "unknown")
  let assert Ok(_) =
    reply.with_text(
      ctx,
      "Не знаю команду: «" <> text <> "»\n/help — список команд",
    )
  Ok(ctx)
}

// ── 3. Чистая бизнес-логика ─────────────────────────────────────────────────
//
// Функции ниже не зависят от Telega.
// Именно такую логику тестируют упражнения в my_solutions.gleam.

/// Одна задача в TODO-листе.
pub type Task {
  Task(text: String, done: Bool)
}

/// Форматирует одну задачу: ✅ или ☐ плюс текст.
///
/// ```gleam
/// format_task(Task("Купить молоко", False)) // → "☐ Купить молоко"
/// format_task(Task("Написать тесты", True)) // → "✅ Написать тесты"
/// ```
pub fn format_task(t: Task) -> String {
  case t.done {
    False -> "☐ " <> t.text
    True -> "✅ " <> t.text
  }
}

/// Форматирует список задач для отправки в Telegram-чат.
///
/// ```gleam
/// format_task_list([])
/// // → "Список задач пуст. Добавьте: /add <задача>"
///
/// format_task_list([Task("Купить молоко", False), Task("Написать тесты", True)])
/// // → "Ваши задачи:\n1. ☐ Купить молоко\n2. ✅ Написать тесты"
/// ```
pub fn format_task_list(tasks: List(Task)) -> String {
  case tasks {
    [] -> "Список задач пуст. Добавьте: /add <задача>"
    items -> {
      let lines =
        items
        |> list.index_map(fn(t, i) {
          int.to_string(i + 1) <> ". " <> format_task(t)
        })
        |> string.join("\n")
      "Ваши задачи:\n" <> lines
    }
  }
}
