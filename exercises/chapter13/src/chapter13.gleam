// Примеры: Lustre — виртуальный DOM, MVU, server-side HTML
//
// Этот файл демонстрирует ключевые паттерны Lustre:
// 1. HTML DSL (element/html) для генерации HTML
// 2. Model-View-Update (The Elm Architecture)
// 3. Тестирование с lustre/dev/simulate

import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/dev/simulate
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// ── 1. HTML DSL ──────────────────────────────────────────────────────────
// Lustre используется для server-side HTML тоже: element.to_string → String

/// Карточка пользователя
pub fn user_card(name: String, role: String) -> Element(msg) {
  html.div([attribute.class("card")], [
    html.h2([], [element.text(name)]),
    html.span([attribute.class("role")], [element.text(role)]),
  ])
}

/// Навигационная ссылка
pub fn nav_link(label: String, href: String, active: Bool) -> Element(msg) {
  html.a(
    [
      attribute.href(href),
      attribute.class(case active {
        True -> "nav-link nav-link--active"
        False -> "nav-link"
      }),
    ],
    [element.text(label)],
  )
}

// ── 2. TODO Item ──────────────────────────────────────────────────────────

pub type Todo {
  Todo(id: Int, text: String, done: Bool)
}

/// Рендерит одну задачу: чекбокс + текст
pub fn todo_item(item: Todo) -> Element(msg) {
  html.li(
    [
      attribute.class(case item.done {
        True -> "todo todo--done"
        False -> "todo"
      }),
    ],
    [
      html.span([], [
        element.text(case item.done {
          True -> "✓ " <> item.text
          False -> "☐ " <> item.text
        }),
      ]),
    ],
  )
}

/// Рендерит список задач или пустое состояние
pub fn todo_list(todos: List(Todo)) -> Element(msg) {
  case todos {
    [] -> html.p([attribute.class("empty")], [element.text("Список пуст")])
    items -> html.ul([], list.map(items, todo_item))
  }
}

// ── 3. Counter App (полный MVU) ───────────────────────────────────────────

pub type CounterMsg {
  Increment
  Decrement
  Reset
}

pub fn counter_init(_flags) -> Int {
  0
}

pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  case msg {
    Increment -> model + 1
    Decrement -> model - 1
    Reset -> 0
  }
}

pub fn counter_view(model: Int) -> Element(CounterMsg) {
  html.div([attribute.class("counter")], [
    html.button([event.on_click(Decrement)], [element.text("−")]),
    html.span([attribute.class("count")], [element.text(int.to_string(model))]),
    html.button([event.on_click(Increment)], [element.text("+")]),
    html.button([event.on_click(Reset)], [element.text("Сброс")]),
  ])
}

// Запуск счётчика в браузере:
pub fn main() {
  let app = lustre.simple(counter_init, counter_update, counter_view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// ── 4. Демонстрация lustre/dev/simulate ──────────────────────────────────

pub fn simulate_counter_example() -> Int {
  simulate.simple(
    init: counter_init,
    update: counter_update,
    view: counter_view,
  )
  |> simulate.start(Nil)
  |> simulate.message(Increment)
  |> simulate.message(Increment)
  |> simulate.message(Increment)
  |> simulate.message(Decrement)
  |> simulate.model
  // → 2
}
