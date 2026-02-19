import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn diagonal_test() {
  my_solutions.diagonal(3.0, 4.0)
  |> should.equal(5.0)
}

pub fn celsius_to_fahrenheit_test() {
  my_solutions.celsius_to_fahrenheit(0.0)
  |> should.equal(32.0)
}

pub fn celsius_to_fahrenheit_100_test() {
  my_solutions.celsius_to_fahrenheit(100.0)
  |> should.equal(212.0)
}

pub fn fahrenheit_to_celsius_test() {
  my_solutions.fahrenheit_to_celsius(32.0)
  |> should.equal(0.0)
}

pub fn euler1_test() {
  my_solutions.euler1(10)
  |> should.equal(23)
}

pub fn euler1_1000_test() {
  my_solutions.euler1(1000)
  |> should.equal(233_168)
}
