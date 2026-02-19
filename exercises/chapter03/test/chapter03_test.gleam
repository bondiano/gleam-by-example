import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn apply_twice_test() {
  let double = fn(x) { x * 2 }
  my_solutions.apply_twice(double, 3)
  |> should.equal(12)
}

pub fn pipe_add_exclamation_test() {
  my_solutions.add_exclamation("hello")
  |> should.equal("hello!")
}

pub fn pipe_shout_test() {
  my_solutions.shout("hello")
  |> should.equal("HELLO!")
}

pub fn safe_divide_ok_test() {
  my_solutions.safe_divide(10, 3)
  |> should.equal(Ok(3))
}

pub fn safe_divide_error_test() {
  my_solutions.safe_divide(10, 0)
  |> should.equal(Error("деление на ноль"))
}

pub fn fizzbuzz_test() {
  my_solutions.fizzbuzz(15)
  |> should.equal("FizzBuzz")
}

pub fn fizzbuzz_fizz_test() {
  my_solutions.fizzbuzz(9)
  |> should.equal("Fizz")
}

pub fn fizzbuzz_buzz_test() {
  my_solutions.fizzbuzz(10)
  |> should.equal("Buzz")
}

pub fn fizzbuzz_number_test() {
  my_solutions.fizzbuzz(7)
  |> should.equal("7")
}
