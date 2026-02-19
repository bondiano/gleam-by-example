import gleam/function
import gleam/io
import gleam/result
import gleam/string

/// Пример: анонимные функции
pub fn apply_twice(f: fn(a) -> a, x: a) -> a {
  f(f(x))
}

/// Пример: pipe-оператор
pub fn format_name(first: String, last: String) -> String {
  first <> " " <> last
}

/// Пример: use-выражение
pub fn parse_and_double(input: String) -> Result(Int, Nil) {
  use n <- result.try(
    input
    |> string.trim
    |> fn(s) {
      case s {
        "" -> Error(Nil)
        _ -> Ok(s)
      }
    },
  )
  use parsed <- result.try(
    case n {
      _ -> Error(Nil)
    },
  )
  Ok(parsed * 2)
}

/// Пример: именованные аргументы
pub fn greet(greeting greeting: String, name name: String) -> String {
  greeting <> ", " <> name <> "!"
}

/// Пример: function.identity
pub fn demo_identity() -> Nil {
  let value = function.identity(42)
  io.println("identity(42) = " <> string.inspect(value))
  Nil
}
