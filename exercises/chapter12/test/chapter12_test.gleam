import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_command_start_test() {
  my_solutions.parse_bot_command("/start")
  |> should.equal(my_solutions.BotStart)
}

pub fn parse_command_help_test() {
  my_solutions.parse_bot_command("/help")
  |> should.equal(my_solutions.BotHelp)
}

pub fn parse_command_todo_test() {
  my_solutions.parse_bot_command("/todo buy milk")
  |> should.equal(my_solutions.BotTodo("buy milk"))
}

pub fn parse_command_unknown_test() {
  my_solutions.parse_bot_command("/unknown")
  |> should.equal(my_solutions.BotUnknown("/unknown"))
}

pub fn format_todo_list_test() {
  my_solutions.format_todo_list(["Buy milk", "Write code", "Read book"])
  |> should.equal("Ваши задачи:\n1. Buy milk\n2. Write code\n3. Read book")
}

pub fn format_todo_list_empty_test() {
  my_solutions.format_todo_list([])
  |> should.equal("Список задач пуст.")
}

pub fn echo_response_test() {
  my_solutions.echo_response("Привет!")
  |> should.equal("Вы сказали: Привет!")
}
