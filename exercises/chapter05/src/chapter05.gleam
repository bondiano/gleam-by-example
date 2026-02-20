import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Пример: рекурсия
pub fn factorial(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> n * factorial(n - 1)
  }
}

/// Пример: хвостовая рекурсия с аккумулятором
pub fn factorial_tail(n: Int) -> Int {
  factorial_loop(n, 1)
}

fn factorial_loop(n: Int, acc: Int) -> Int {
  case n {
    0 -> acc
    _ -> factorial_loop(n - 1, n * acc)
  }
}

/// Пример: цепочки с Result и use
pub fn parse_pair(
  first: String,
  second: String,
  parse: fn(String) -> Result(Int, Nil),
) -> Result(#(Int, Int), Nil) {
  use a <- result.try(parse(first))
  use b <- result.try(parse(second))
  Ok(#(a, b))
}

/// Пример: panic
pub fn unwrap_or_panic(r: Result(a, b)) -> a {
  case r {
    Ok(value) -> value
    Error(_) -> panic as "неожиданная ошибка"
  }
}

/// Пример: let assert
pub fn head(xs: List(a)) -> a {
  let assert [first, ..] = xs
  first
}

/// Пример: ROP-цепочка
pub fn parse_and_double(input: String) -> Result(Int, String) {
  use n <- result.try(
    int.parse(input)
    |> result.replace_error("не число"),
  )
  use valid <- result.try(case n > 0 {
    True -> Ok(n)
    False -> Error("число должно быть положительным")
  })
  Ok(valid * 2)
}

/// Тип ошибок формы (используется в упражнении 7)
pub type FormError {
  NameTooShort
  EmailInvalid
  AgeTooYoung
  AgeTooOld
}

/// Пример: валидация с накоплением ошибок
pub fn validate_all(validations: List(Result(Nil, e))) -> Result(Nil, List(e)) {
  let #(_, errors) = result.partition(validations)
  case errors {
    [] -> Ok(Nil)
    errs -> Error(errs)
  }
}

/// Пример: свёртки
pub fn sum_with_fold(xs: List(Int)) -> Int {
  list.fold(xs, 0, fn(acc, x) { acc + x })
}

/// Пример: try_fold
pub fn sum_strings(xs: List(String)) -> Result(Int, Nil) {
  list.try_fold(xs, 0, fn(acc, s) {
    case int.parse(s) {
      Ok(n) -> Ok(acc + n)
      Error(_) -> Error(Nil)
    }
  })
}

/// Пример: MISU — непрозрачный Email (превью для Ch7)
pub opaque type Email {
  Email(String)
}

pub fn parse_email(s: String) -> Result(Email, String) {
  case string.contains(s, "@") {
    True -> Ok(Email(s))
    False -> Error("некорректный email")
  }
}

pub fn email_to_string(email: Email) -> String {
  let Email(s) = email
  s
}
