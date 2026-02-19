/// Пример: структура Telegram-бота
/// (полноценная реализация требует токен и webhook)

/// Тип команды бота
pub type BotCommand {
  Start
  Help
  Unknown(String)
}

/// Парсинг команды из строки
pub fn parse_command(text: String) -> BotCommand {
  case text {
    "/start" -> Start
    "/help" -> Help
    cmd -> Unknown(cmd)
  }
}

/// Генерация ответа на команду
pub fn command_response(cmd: BotCommand) -> String {
  case cmd {
    Start -> "Добро пожаловать! Используйте /help для списка команд."
    Help -> "Доступные команды:\n/start — начало\n/help — помощь"
    Unknown(text) -> "Неизвестная команда: " <> text
  }
}
