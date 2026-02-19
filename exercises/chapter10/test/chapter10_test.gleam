import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn health_check_test() {
  my_solutions.health_check_body()
  |> should.equal("{\"status\":\"ok\"}")
}

pub fn parse_todo_ok_test() {
  my_solutions.parse_todo("{\"title\":\"Buy milk\",\"completed\":false}")
  |> should.equal(Ok(my_solutions.Todo(title: "Buy milk", completed: False)))
}

pub fn parse_todo_error_test() {
  my_solutions.parse_todo("{\"invalid\":true}")
  |> should.be_error
}

pub fn todo_to_json_test() {
  my_solutions.todo_to_json_string(my_solutions.Todo(
    title: "Buy milk",
    completed: False,
  ))
  |> should.equal("{\"title\":\"Buy milk\",\"completed\":false}")
}
