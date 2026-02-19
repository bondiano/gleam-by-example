//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/string

pub fn apply_twice(f: fn(a) -> a, x: a) -> a {
  f(f(x))
}

pub fn add_exclamation(s: String) -> String {
  s <> "!"
}

pub fn shout(s: String) -> String {
  s
  |> string.uppercase
  |> add_exclamation
}

pub fn safe_divide(a: Int, b: Int) -> Result(Int, String) {
  case b {
    0 -> Error("деление на ноль")
    _ -> Ok(a / b)
  }
}

pub fn fizzbuzz(n: Int) -> String {
  case n % 3, n % 5 {
    0, 0 -> "FizzBuzz"
    0, _ -> "Fizz"
    _, 0 -> "Buzz"
    _, _ -> int.to_string(n)
  }
}
