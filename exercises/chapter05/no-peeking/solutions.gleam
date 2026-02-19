//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub fn list_length(xs: List(a)) -> Int {
  list_length_loop(xs, 0)
}

fn list_length_loop(xs: List(a), acc: Int) -> Int {
  case xs {
    [] -> acc
    [_, ..rest] -> list_length_loop(rest, acc + 1)
  }
}

pub fn list_reverse(xs: List(a)) -> List(a) {
  list_reverse_loop(xs, [])
}

fn list_reverse_loop(xs: List(a), acc: List(a)) -> List(a) {
  case xs {
    [] -> acc
    [first, ..rest] -> list_reverse_loop(rest, [first, ..acc])
  }
}

pub fn safe_head(xs: List(a)) -> Option(a) {
  case xs {
    [] -> None
    [first, ..] -> Some(first)
  }
}

pub fn validate_age(age: Int) -> Result(Int, String) {
  case age {
    _ if age < 0 -> Error("возраст не может быть отрицательным")
    _ if age > 150 -> Error("возраст слишком большой")
    _ -> Ok(age)
  }
}

pub fn validate_password(password: String) -> Result(String, String) {
  use _ <- result.try(case string.length(password) >= 8 {
    True -> Ok(Nil)
    False -> Error("пароль должен быть не менее 8 символов")
  })
  use _ <- result.try(case has_digit(password) {
    True -> Ok(Nil)
    False -> Error("пароль должен содержать хотя бы одну цифру")
  })
  Ok(password)
}

fn has_digit(s: String) -> Bool {
  s
  |> string.to_graphemes
  |> list.any(fn(c) {
    case int.parse(c) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

pub fn parse_and_validate(input: String) -> Result(Int, String) {
  use n <- result.try(
    int.parse(input)
    |> result.replace_error("не удалось распознать число"),
  )
  use _ <- result.try(case n > 0 {
    True -> Ok(Nil)
    False -> Error("число должно быть больше 0")
  })
  use _ <- result.try(case n < 1000 {
    True -> Ok(Nil)
    False -> Error("число должно быть меньше 1000")
  })
  Ok(n)
}

pub type FormError {
  NameTooShort
  EmailInvalid
  AgeTooYoung
  AgeTooOld
}

pub fn validate_form(
  name: String,
  email: String,
  age: Int,
) -> Result(#(String, String, Int), List(FormError)) {
  let validations = [
    case string.length(name) >= 2 {
      True -> Ok(Nil)
      False -> Error(NameTooShort)
    },
    case string.contains(email, "@") {
      True -> Ok(Nil)
      False -> Error(EmailInvalid)
    },
    case age {
      a if a < 18 -> Error(AgeTooYoung)
      a if a > 150 -> Error(AgeTooOld)
      _ -> Ok(Nil)
    },
  ]

  let #(_, errors) = result.partition(validations)

  case errors {
    [] -> Ok(#(name, email, age))
    errs -> Error(list.reverse(errs))
  }
}
