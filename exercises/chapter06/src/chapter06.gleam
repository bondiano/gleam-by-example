import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/string
import gleam/string_tree
import gleam/uri

/// Пример: работа со строками
pub fn initials(first: String, last: String) -> String {
  let assert Ok(f) = string.first(first)
  let assert Ok(l) = string.first(last)
  string.uppercase(f) <> "." <> string.uppercase(l) <> "."
}

/// Пример: проверка содержания подстроки
pub fn contains_word(text: String, word: String) -> Bool {
  string.contains(text, word)
}

/// Пример: bit arrays — кодирование строки в UTF-8
pub fn encode_utf8(s: String) -> BitArray {
  <<s:utf8>>
}

/// Пример: string_tree — эффективная сборка строк
pub fn build_greeting(names: List(String)) -> String {
  names
  |> list.fold(string_tree.new(), fn(tree, name) {
    tree
    |> string_tree.append("Привет, ")
    |> string_tree.append(name)
    |> string_tree.append("!\n")
  })
  |> string_tree.to_string
}

/// Пример: bit_array — base64
pub fn to_base64(s: String) -> String {
  s
  |> bit_array.from_string
  |> bit_array.base64_encode(True)
}

/// Пример: regexp — проверка email
pub fn is_email(s: String) -> Bool {
  let assert Ok(re) = regexp.from_string("^[\\w.+-]+@[\\w-]+\\.[a-z]{2,}$")
  regexp.check(re, s)
}

/// Пример: URI — извлечение хоста
pub fn get_host(url: String) -> Result(String, Nil) {
  case uri.parse(url) {
    Ok(u) ->
      case u.host {
        Some(host) -> Ok(host)
        None -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

/// Пример: pattern matching на bit arrays
pub fn classify_byte(b: BitArray) -> String {
  case b {
    <<n:8>> if n >= 0 && n <= 127 -> "ASCII"
    <<n:8>> if n >= 128 -> "Extended"
    _ -> "Unknown"
  }
}
