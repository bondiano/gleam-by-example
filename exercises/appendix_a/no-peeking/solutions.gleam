//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/list
import gleam/string

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
