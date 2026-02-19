import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// --- Упражнение 1: list_length ---

pub fn list_length_test() {
  my_solutions.list_length([1, 2, 3, 4, 5])
  |> should.equal(5)
}

pub fn list_length_empty_test() {
  my_solutions.list_length([])
  |> should.equal(0)
}

// --- Упражнение 2: list_reverse ---

pub fn list_reverse_test() {
  my_solutions.list_reverse([1, 2, 3])
  |> should.equal([3, 2, 1])
}

pub fn list_reverse_empty_test() {
  my_solutions.list_reverse([])
  |> should.equal([])
}

// --- Упражнение 3: safe_head ---

pub fn safe_head_some_test() {
  my_solutions.safe_head([1, 2, 3])
  |> should.equal(Some(1))
}

pub fn safe_head_none_test() {
  my_solutions.safe_head([])
  |> should.equal(None)
}

// --- Упражнение 4: validate_age ---

pub fn validate_age_ok_test() {
  my_solutions.validate_age(25)
  |> should.equal(Ok(25))
}

pub fn validate_age_too_young_test() {
  my_solutions.validate_age(-1)
  |> should.be_error
}

pub fn validate_age_too_old_test() {
  my_solutions.validate_age(200)
  |> should.be_error
}

// --- Упражнение 5: validate_password ---

pub fn validate_password_ok_test() {
  my_solutions.validate_password("pass1234")
  |> should.equal(Ok("pass1234"))
}

pub fn validate_password_too_short_test() {
  my_solutions.validate_password("short1")
  |> should.equal(Error("пароль должен быть не менее 8 символов"))
}

pub fn validate_password_no_digit_test() {
  my_solutions.validate_password("longpassword")
  |> should.equal(Error("пароль должен содержать хотя бы одну цифру"))
}

pub fn validate_password_all_digits_test() {
  my_solutions.validate_password("12345678")
  |> should.equal(Ok("12345678"))
}

// --- Упражнение 6: parse_and_validate ---

pub fn parse_and_validate_ok_test() {
  my_solutions.parse_and_validate("42")
  |> should.equal(Ok(42))
}

pub fn parse_and_validate_not_number_test() {
  my_solutions.parse_and_validate("abc")
  |> should.equal(Error("не удалось распознать число"))
}

pub fn parse_and_validate_zero_test() {
  my_solutions.parse_and_validate("0")
  |> should.equal(Error("число должно быть больше 0"))
}

pub fn parse_and_validate_negative_test() {
  my_solutions.parse_and_validate("-5")
  |> should.equal(Error("число должно быть больше 0"))
}

pub fn parse_and_validate_too_large_test() {
  my_solutions.parse_and_validate("1000")
  |> should.equal(Error("число должно быть меньше 1000"))
}

pub fn parse_and_validate_max_test() {
  my_solutions.parse_and_validate("999")
  |> should.equal(Ok(999))
}

// --- Упражнение 7: validate_form ---

pub fn validate_form_ok_test() {
  my_solutions.validate_form("Алиса", "alice@mail.com", 25)
  |> should.equal(Ok(#("Алиса", "alice@mail.com", 25)))
}

pub fn validate_form_all_errors_test() {
  my_solutions.validate_form("A", "bad", 10)
  |> should.equal(
    Error([
      my_solutions.NameTooShort,
      my_solutions.EmailInvalid,
      my_solutions.AgeTooYoung,
    ]),
  )
}

pub fn validate_form_too_old_test() {
  my_solutions.validate_form("Боб", "bob@mail.com", 200)
  |> should.equal(Error([my_solutions.AgeTooOld]))
}

pub fn validate_form_single_error_test() {
  my_solutions.validate_form("Алиса", "bad-email", 25)
  |> should.equal(Error([my_solutions.EmailInvalid]))
}
