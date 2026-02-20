// Тесты чистой логики Telegram-бота:
// - Парсинг команд
// - Форматирование ответов
// - State machine диалога
// - Dispatch команд

import gleam/list
import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ── Упражнение 1: parse_command ──────────────────────────────────────────

pub fn parse_start_test() {
  my_solutions.parse_command("/start")
  |> should.equal(my_solutions.CmdStart)
}

pub fn parse_help_test() {
  my_solutions.parse_command("/help")
  |> should.equal(my_solutions.CmdHelp)
}

pub fn parse_list_test() {
  my_solutions.parse_command("/list")
  |> should.equal(my_solutions.CmdList)
}

pub fn parse_add_test() {
  my_solutions.parse_command("/add Buy milk")
  |> should.equal(my_solutions.CmdAdd("Buy milk"))
}

pub fn parse_done_test() {
  my_solutions.parse_command("/done 3")
  |> should.equal(my_solutions.CmdDone(3))
}

pub fn parse_done_invalid_number_test() {
  my_solutions.parse_command("/done abc")
  |> should.equal(my_solutions.CmdUnknown("/done abc"))
}

pub fn parse_unknown_test() {
  my_solutions.parse_command("/unknown")
  |> should.equal(my_solutions.CmdUnknown("/unknown"))
}

pub fn parse_plain_text_test() {
  my_solutions.parse_command("hello")
  |> should.equal(my_solutions.CmdUnknown("hello"))
}

// ── Упражнение 2: format_task ─────────────────────────────────────────────

pub fn format_task_not_done_test() {
  my_solutions.format_task(my_solutions.Task("Buy milk", False))
  |> should.equal("☐ Buy milk")
}

pub fn format_task_done_test() {
  my_solutions.format_task(my_solutions.Task("Write tests", True))
  |> should.equal("✅ Write tests")
}

// ── Упражнение 3: format_task_list ───────────────────────────────────────

pub fn format_task_list_empty_test() {
  my_solutions.format_task_list([])
  |> should.equal("Список задач пуст. Добавьте: /add <задача>")
}

pub fn format_task_list_one_item_test() {
  my_solutions.format_task_list([my_solutions.Task("Buy milk", False)])
  |> should.equal("Ваши задачи:\n1. ☐ Buy milk")
}

pub fn format_task_list_mixed_test() {
  my_solutions.format_task_list([
    my_solutions.Task("Buy milk", False),
    my_solutions.Task("Write tests", True),
    my_solutions.Task("Deploy", False),
  ])
  |> should.equal(
    "Ваши задачи:\n1. ☐ Buy milk\n2. ✅ Write tests\n3. ☐ Deploy",
  )
}

// ── Упражнение 4: conversation_step ─────────────────────────────────────

pub fn conv_idle_add_test() {
  my_solutions.conversation_step(my_solutions.Idle, "/add")
  |> should.equal(#(
    my_solutions.AwaitingTitle,
    "Введите название задачи:",
  ))
}

pub fn conv_awaiting_title_test() {
  my_solutions.conversation_step(my_solutions.AwaitingTitle, "Buy milk")
  |> should.equal(#(my_solutions.Idle, "✅ Задача «Buy milk» добавлена!"))
}

pub fn conv_idle_unknown_test() {
  my_solutions.conversation_step(my_solutions.Idle, "random text")
  |> should.equal(#(my_solutions.Idle, "Не понимаю. /help — список команд."))
}

// ── Упражнение 5: dispatch ────────────────────────────────────────────────

pub fn dispatch_start_test() {
  let #(tasks, reply) = my_solutions.dispatch(my_solutions.CmdStart, [])
  list.length(tasks) |> should.equal(0)
  reply |> should.equal("Привет! Я TODO-бот.\n/help — список команд")
}

pub fn dispatch_add_test() {
  let #(tasks, reply) =
    my_solutions.dispatch(my_solutions.CmdAdd("Buy milk"), [])
  list.length(tasks) |> should.equal(1)
  reply |> should.equal("✅ Задача «Buy milk» добавлена!")
}

pub fn dispatch_list_empty_test() {
  let #(_tasks, reply) = my_solutions.dispatch(my_solutions.CmdList, [])
  reply |> should.equal("Список задач пуст. Добавьте: /add <задача>")
}

pub fn dispatch_list_with_items_test() {
  let initial = [
    my_solutions.Task("Buy milk", False),
    my_solutions.Task("Write tests", True),
  ]
  let #(_tasks, reply) = my_solutions.dispatch(my_solutions.CmdList, initial)
  reply
  |> should.equal("Ваши задачи:\n1. ☐ Buy milk\n2. ✅ Write tests")
}

pub fn dispatch_done_test() {
  let initial = [
    my_solutions.Task("Buy milk", False),
    my_solutions.Task("Write tests", False),
  ]
  let #(tasks, reply) = my_solutions.dispatch(my_solutions.CmdDone(1), initial)
  let assert Ok(first) = list.first(tasks)
  first.done |> should.equal(True)
  reply |> should.equal("✅ Задача 1 выполнена!")
}

pub fn dispatch_done_out_of_bounds_test() {
  let initial = [my_solutions.Task("Buy milk", False)]
  let #(tasks, reply) = my_solutions.dispatch(my_solutions.CmdDone(5), initial)
  list.length(tasks) |> should.equal(1)
  reply |> should.equal("Нет задачи с номером 5")
}
