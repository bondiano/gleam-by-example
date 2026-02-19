//// Здесь вы можете писать свои решения упражнений.

/// Типы команд бота.
pub type BotCommand {
  BotStart
  BotHelp
  BotTodo(text: String)
  BotUnknown(text: String)
}

/// Парсит текст команды в тип BotCommand.
/// "/start" → BotStart, "/help" → BotHelp,
/// "/todo ..." → BotTodo(text), остальное → BotUnknown.
pub fn parse_bot_command(text: String) -> BotCommand {
  todo
}

/// Форматирует список задач для отображения в Telegram.
/// Пустой список → "Список задач пуст."
/// Иначе → "Ваши задачи:\n1. ...\n2. ..."
pub fn format_todo_list(todos: List(String)) -> String {
  todo
}

/// Эхо-ответ: "Вы сказали: <текст>".
pub fn echo_response(text: String) -> String {
  todo
}
