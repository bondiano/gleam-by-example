import gleeunit
import gleeunit/should
import lustre/element
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn render_list_test() {
  my_solutions.render_list(["Gleam", "Erlang", "Elixir"])
  |> element.to_string
  |> should.equal("<ul><li>Gleam</li><li>Erlang</li><li>Elixir</li></ul>")
}

pub fn counter_init_test() {
  my_solutions.counter_init()
  |> should.equal(0)
}

pub fn counter_increment_test() {
  0
  |> my_solutions.counter_update(my_solutions.CounterIncrement)
  |> should.equal(1)
}

pub fn counter_decrement_test() {
  5
  |> my_solutions.counter_update(my_solutions.CounterDecrement)
  |> should.equal(4)
}

pub fn counter_reset_test() {
  42
  |> my_solutions.counter_update(my_solutions.CounterReset)
  |> should.equal(0)
}
