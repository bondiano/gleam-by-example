//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/list
import gleam/option.{type Option, None}
import gleam/string

import telega
import telega/bot.{type Context}
import telega/keyboard
import telega/reply
import telega/router.{type Router}
import telega/update.{type Command}

pub type BotCommand {
  CmdStart
  CmdHelp
  CmdList
  CmdAdd(title: String)
  CmdDone(index: Int)
  CmdUnknown(text: String)
}

pub type ConvState {
  Idle
  AwaitingTitle
}

pub type Task {
  Task(text: String, done: Bool)
}

// Упражнение 1
pub fn parse_command(text: String) -> BotCommand {
  case string.trim(text) {
    "/start" -> CmdStart
    "/help" -> CmdHelp
    "/list" -> CmdList
    "/add " <> title -> CmdAdd(title)
    "/done " <> n ->
      case int.parse(n) {
        Ok(i) -> CmdDone(i)
        Error(_) -> CmdUnknown(text)
      }
    other -> CmdUnknown(other)
  }
}

// Упражнение 2
pub fn format_task(t: Task) -> String {
  case t.done {
    False -> "☐ " <> t.text
    True -> "✅ " <> t.text
  }
}

// Упражнение 3
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

// Упражнение 4
pub fn conversation_step(state: ConvState, input: String) -> #(ConvState, String) {
  case state, string.trim(input) {
    Idle, "/add" ->
      #(AwaitingTitle, "Введите название задачи:")
    Idle, "/help" ->
      #(
        Idle,
        "Доступные команды:\n/list — список задач\n/add — добавить задачу\n/help — помощь",
      )
    Idle, _ ->
      #(Idle, "Не понимаю. /help — список команд.")
    AwaitingTitle, title ->
      #(Idle, "✅ Задача «" <> title <> "» добавлена!")
  }
}

// Упражнение 5
pub fn dispatch(
  cmd: BotCommand,
  tasks: List(Task),
) -> #(List(Task), String) {
  case cmd {
    CmdStart ->
      #(tasks, "Привет! Я TODO-бот.\n/help — список команд")

    CmdHelp ->
      #(
        tasks,
        "Команды:\n/list — список задач\n/add <задача> — добавить\n/done <номер> — выполнено",
      )

    CmdList -> #(tasks, format_task_list(tasks))

    CmdAdd(title) -> {
      let new_tasks = list.append(tasks, [Task(text: title, done: False)])
      #(new_tasks, "✅ Задача «" <> title <> "» добавлена!")
    }

    CmdDone(n) -> {
      let index = n - 1
      case index >= 0 && index < list.length(tasks) {
        False -> #(tasks, "Нет задачи с номером " <> int.to_string(n))
        True -> {
          let updated =
            tasks
            |> list.index_map(fn(t, i) {
              case i == index {
                True -> Task(..t, done: True)
                False -> t
              }
            })
          #(updated, "✅ Задача " <> int.to_string(n) <> " выполнена!")
        }
      }
    }

    CmdUnknown(text) ->
      #(tasks, "Не понимаю: " <> text <> ". /help — список команд")
  }
}

// Упражнение 6
pub fn build_greeting_router() -> Router(Nil, Nil) {
  router.new("greeting")
  |> router.on_command("start", fn(ctx, _cmd: Command) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Привет! Я бот.")
    Ok(ctx)
  })
  |> router.on_command("help", fn(ctx, _cmd: Command) {
    let assert Ok(_) =
      reply.with_text(
        ctx:,
        text: "Команды:\n/start — начало\n/help — помощь",
      )
    Ok(ctx)
  })
}

// Упражнение 7
pub fn build_echo_router() -> Router(Nil, Nil) {
  router.new("echo")
  |> router.on_any_text(fn(ctx, text) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Эхо: " <> text)
    Ok(ctx)
  })
}

// Упражнение 8
pub fn build_register_router() -> Router(Nil, Nil) {
  router.new("register")
  |> router.on_command("register", fn(ctx: Context(Nil, Nil), _cmd: Command) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Как вас зовут?")
    use ctx, name <- telega.wait_text(ctx:, or: None, timeout: None)
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Добро пожаловать, " <> name <> "!")
    Ok(ctx)
  })
}

// Упражнение 9
pub fn build_menu_router() -> Router(Nil, Nil) {
  router.new("menu")
  |> router.on_command("menu", fn(ctx, _cmd: Command) {
    let list_cb = keyboard.string_callback_data("list")
    let add_cb = keyboard.string_callback_data("add")

    let assert Ok(kb) =
      keyboard.inline_builder()
      |> keyboard.inline_text(
        "Список",
        keyboard.pack_callback(callback_data: list_cb, data: "list"),
      )
    let assert Ok(kb) =
      kb
      |> keyboard.inline_text(
        "Добавить",
        keyboard.pack_callback(callback_data: add_cb, data: "add"),
      )
    let kb = keyboard.inline_build(kb)

    let assert Ok(_) =
      reply.with_markup(
        ctx:,
        text: "Выберите действие:",
        markup: keyboard.inline_to_markup(kb),
      )
    Ok(ctx)
  })
}

// Упражнение 10
pub fn build_merged_router() -> Router(Nil, Nil) {
  let admin_router =
    router.new("admin")
    |> router.on_command("ban", fn(ctx, _cmd: Command) {
      let assert Ok(_) =
        reply.with_text(ctx:, text: "Пользователь заблокирован")
      Ok(ctx)
    })

  let user_router =
    router.new("user")
    |> router.on_command("start", fn(ctx, _cmd: Command) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
      Ok(ctx)
    })

  router.merge(user_router, admin_router)
}
