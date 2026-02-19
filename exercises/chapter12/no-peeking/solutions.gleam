//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/list
import gleam/string

pub type BotCommand {
  BotStart
  BotHelp
  BotTodo(text: String)
  BotUnknown(text: String)
}

pub fn parse_bot_command(text: String) -> BotCommand {
  case text {
    "/start" -> BotStart
    "/help" -> BotHelp
    "/todo " <> rest -> BotTodo(rest)
    other -> BotUnknown(other)
  }
}

pub fn format_todo_list(todos: List(String)) -> String {
  case todos {
    [] -> "Список задач пуст."
    items -> {
      let lines =
        items
        |> list.index_map(fn(item, i) {
          int.to_string(i + 1) <> ". " <> item
        })
        |> string.join("\n")
      "Ваши задачи:\n" <> lines
    }
  }
}

pub fn echo_response(text: String) -> String {
  "Вы сказали: " <> text
}
