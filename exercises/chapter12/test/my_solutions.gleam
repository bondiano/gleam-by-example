//// Здесь вы можете писать свои решения упражнений.
////
//// Запуск тестов: gleam test

// ── Типы (не менять) ─────────────────────────────────────────────────────

/// Команды бота.
pub type BotCommand {
  CmdStart
  CmdHelp
  CmdList
  CmdAdd(title: String)
  CmdDone(index: Int)
  CmdUnknown(text: String)
}

/// Состояния диалога.
pub type ConvState {
  Idle
  AwaitingTitle
}

/// Одна задача.
pub type Task {
  Task(text: String, done: Bool)
}

// ── Упражнение 1 ─────────────────────────────────────────────────────────
// Распарсите текст сообщения в команду.
//
// "/start"       → CmdStart
// "/help"        → CmdHelp
// "/list"        → CmdList
// "/add Buy milk" → CmdAdd("Buy milk")
// "/done 3"      → CmdDone(3)
// "/done abc"    → CmdUnknown("/done abc")   ← нельзя парсить число
// всё остальное  → CmdUnknown(text)
//
// Подсказка: case string.trim(text) { "/add " <> title -> CmdAdd(title) ... }
//            int.parse(n) для проверки что строка — число

pub fn parse_command(text: String) -> BotCommand {
  todo
}

// ── Упражнение 2 ─────────────────────────────────────────────────────────
// Форматирует одну задачу.
//
// Task("Buy milk", False)   → "☐ Buy milk"
// Task("Write tests", True) → "✅ Write tests"

pub fn format_task(t: Task) -> String {
  todo
}

// ── Упражнение 3 ─────────────────────────────────────────────────────────
// Форматирует список задач.
//
// []        → "Список задач пуст. Добавьте: /add <задача>"
// [task...] → "Ваши задачи:\n1. ☐ Buy milk\n2. ✅ Write tests"
//
// Подсказка: list.index_map, string.join

pub fn format_task_list(tasks: List(Task)) -> String {
  todo
}

// ── Упражнение 4 ─────────────────────────────────────────────────────────
// State machine для многошагового диалога.
// Возвращает (новое_состояние, текст_ответа).
//
// Idle + "/add"   → (AwaitingTitle, "Введите название задачи:")
// Idle + "/help"  → (Idle, "Доступные команды:\n/list — список задач\n/add — добавить задачу\n/help — помощь")
// Idle + другое   → (Idle, "Не понимаю. /help — список команд.")
// AwaitingTitle + title → (Idle, "✅ Задача «title» добавлена!")
//
// Подсказка: case state, string.trim(input) { Idle, "/add" -> ... }

pub fn conversation_step(state: ConvState, input: String) -> #(ConvState, String) {
  todo
}

// ── Упражнение 5 ─────────────────────────────────────────────────────────
// Полный dispatch: команда → (обновлённые задачи, текст ответа).
//
// CmdStart       → (tasks, "Привет! Я TODO-бот.\n/help — список команд")
// CmdHelp        → (tasks, "Команды:\n/list — список задач\n/add <задача> — добавить\n/done <номер> — выполнено")
// CmdList        → (tasks, форматированный список)
// CmdAdd(title)  → ([..tasks, Task(title, False)], "✅ Задача «title» добавлена!")
// CmdDone(n)     → задача n-1 помечается done=True; если нет → "Нет задачи с номером n"
// CmdUnknown(t)  → (tasks, "Не понимаю: t. /help — список команд")
//
// Подсказка: используйте format_task_list из упражнения 3

pub fn dispatch(
  cmd: BotCommand,
  tasks: List(Task),
) -> #(List(Task), String) {
  todo
}
