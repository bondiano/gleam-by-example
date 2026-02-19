//// Здесь вы можете писать свои решения упражнений.

import gleam/option.{type Option}

/// Упражнение 1: Вычисляет длину списка рекурсивно (без list.length).
pub fn list_length(xs: List(a)) -> Int {
  todo
}

/// Упражнение 2: Разворачивает список рекурсивно (без list.reverse).
pub fn list_reverse(xs: List(a)) -> List(a) {
  todo
}

/// Упражнение 3: Безопасно извлекает первый элемент списка.
pub fn safe_head(xs: List(a)) -> Option(a) {
  todo
}

/// Упражнение 4: Валидирует возраст: 0-150 — Ok, иначе — Error с сообщением.
pub fn validate_age(age: Int) -> Result(Int, String) {
  todo
}

/// Упражнение 5: Валидирует пароль: ≥ 8 символов И содержит цифру.
/// Используйте use + result.try для цепочки проверок.
pub fn validate_password(password: String) -> Result(String, String) {
  todo
}

/// Упражнение 6: ROP-цепочка: строка → Int → > 0 → < 1000.
pub fn parse_and_validate(input: String) -> Result(Int, String) {
  todo
}

/// Тип ошибок валидации формы.
pub type FormError {
  NameTooShort
  EmailInvalid
  AgeTooYoung
  AgeTooOld
}

/// Упражнение 7: Валидирует форму регистрации с накоплением ошибок.
/// Имя ≥ 2 символов, email содержит @, возраст 18-150.
pub fn validate_form(
  name: String,
  email: String,
  age: Int,
) -> Result(#(String, String, Int), List(FormError)) {
  todo
}
