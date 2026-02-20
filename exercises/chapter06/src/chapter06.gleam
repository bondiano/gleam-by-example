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

// ============================================================
// Примеры: HTML Builder паттерн
// ============================================================

// Этот файл демонстрирует использование builder-паттерна для построения HTML.
// Мы создаём типобезопасный DSL для генерации HTML.

// Пример 1: Простая HTML страница
//
// import my_solutions.{type Element, type Attribute}
//
// pub fn example_page() -> String {
//   my_solutions.div([my_solutions.class("container")], [
//     my_solutions.h1([], [my_solutions.text("Добро пожаловать!")]),
//     my_solutions.p([], [my_solutions.text("Это пример HTML builder.")]),
//   ])
//   |> my_solutions.to_string
// }
//
// Результат:
// <div class="container">
//   <h1>Добро пожаловать!</h1>
//   <p>Это пример HTML builder.</p>
// </div>

// Пример 2: Навигационное меню
//
// pub fn nav_menu(links: List(#(String, String))) -> String {
//   let menu_items =
//     links
//     |> list.map(fn(link) {
//       my_solutions.li([], [
//         my_solutions.a([my_solutions.href(link.0)], [
//           my_solutions.text(link.1)
//         ])
//       ])
//     })
//
//   my_solutions.nav([my_solutions.class("menu")], [
//     my_solutions.ul([], menu_items)
//   ])
//   |> my_solutions.to_string
// }

// Пример 3: Карточка пользователя
//
// pub type User {
//   User(name: String, bio: String, avatar: String)
// }
//
// pub fn user_card(user: User) -> String {
//   my_solutions.div([my_solutions.class("user-card")], [
//     my_solutions.img([
//       my_solutions.attr("src", user.avatar),
//       my_solutions.alt(user.name <> "'s avatar")
//     ]),
//     my_solutions.h2([], [my_solutions.text(user.name)]),
//     my_solutions.p([my_solutions.class("bio")], [
//       my_solutions.text(user.bio)
//     ])
//   ])
//   |> my_solutions.to_string
// }

// Пример 4: Динамическая таблица
//
// pub fn scores_table(scores: List(#(String, Int))) -> String {
//   let rows =
//     scores
//     |> list.map(fn(score) {
//       my_solutions.tr([], [
//         my_solutions.td([], [my_solutions.text(score.0)]),
//         my_solutions.td([my_solutions.class("score")], [
//           my_solutions.text(int.to_string(score.1))
//         ])
//       ])
//     })
//
//   my_solutions.table([my_solutions.class("scores")], [
//     my_solutions.thead([], [
//       my_solutions.tr([], [
//         my_solutions.th([], [my_solutions.text("Игрок")]),
//         my_solutions.th([], [my_solutions.text("Очки")])
//       ])
//     ]),
//     my_solutions.tbody([], rows)
//   ])
//   |> my_solutions.to_string
// }

// Преимущества builder-паттерна для HTML:
//
// 1. **Type Safety**: опечатки в именах тегов выявляются на этапе компиляции
// 2. **Композиция**: элементы легко комбинируются через pipe operator
// 3. **Переиспользование**: можно создавать компоненты-функции
// 4. **Читаемость**: структура HTML отражается в коде
// 5. **Применение**: этот паттерн используется в популярных библиотеках (например, Lustre)
