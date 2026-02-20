import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string

// ============================================================
// Пример: функции для unit-тестирования
// ============================================================

/// Сортирует список целых чисел
pub fn sort(xs: List(Int)) -> List(Int) {
  list.sort(xs, int.compare)
}

/// Проверяет, содержит ли список дубликаты
pub fn has_duplicates(xs: List(a)) -> Bool {
  case xs {
    [] -> False
    [first, ..rest] ->
      case list.contains(rest, first) {
        True -> True
        False -> has_duplicates(rest)
      }
  }
}

// ============================================================
// Пример: функции для snapshot-тестирования
// ============================================================

/// Форматирует таблицу с заголовками и строками
pub fn format_table(headers: List(String), rows: List(List(String))) -> String {
  let header_line = string.join(headers, " | ")
  let separator = string.repeat("-", string.length(header_line))
  let data_lines =
    rows
    |> list.map(fn(row) { string.join(row, " | ") })
    |> string.join("\n")
  header_line <> "\n" <> separator <> "\n" <> data_lines
}

// ============================================================
// Пример: JSON encode/decode для roundtrip-тестирования
// ============================================================

/// Кодирует список Int в JSON-строку
pub fn encode_int_list(xs: List(Int)) -> String {
  xs
  |> json.array(json.int)
  |> json.to_string
}

/// Декодирует JSON-строку в список Int
pub fn decode_int_list(s: String) -> Result(List(Int), Nil) {
  json.parse(s, decode.list(decode.int))
  |> result.map_error(fn(_) { Nil })
}

// ============================================================
// Пример: функция для PBT
// ============================================================

/// Ограничивает значение диапазоном [lo, hi]
pub fn clamp(value: Int, lo: Int, hi: Int) -> Int {
  int.min(hi, int.max(lo, value))
}
