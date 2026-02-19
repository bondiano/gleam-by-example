//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// Упражнение 1
pub fn todo_item_view(text: String, done: Bool) -> Element(msg) {
  case done {
    True ->
      html.li([attribute.class("done")], [element.text("✓ " <> text)])
    False ->
      html.li([], [element.text("☐ " <> text)])
  }
}

// Упражнение 2
pub fn render_todo_list(todos: List(#(String, Bool))) -> Element(msg) {
  case todos {
    [] -> html.p([attribute.class("empty")], [element.text("Список пуст")])
    items ->
      html.ul(
        [],
        list.map(items, fn(item) { todo_item_view(item.0, item.1) }),
      )
  }
}

// Упражнения 3-5: счётчик

pub type CounterMsg {
  CounterIncrement
  CounterDecrement
  CounterReset
}

pub fn counter_init(_flags) -> Int {
  0
}

pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  case msg {
    CounterIncrement -> model + 1
    CounterDecrement -> model - 1
    CounterReset -> 0
  }
}

pub fn counter_view(model: Int) -> Element(CounterMsg) {
  html.div([attribute.class("counter")], [
    html.button([event.on_click(CounterDecrement)], [element.text("−")]),
    html.span([], [element.text(int.to_string(model))]),
    html.button([event.on_click(CounterIncrement)], [element.text("+")]),
    html.button([event.on_click(CounterReset)], [element.text("Сброс")]),
  ])
}

// Упражнение 6: TODO-список

pub type TodoItem {
  TodoItem(id: Int, text: String, done: Bool)
}

pub type TodoMsg {
  AddTodo(text: String)
  ToggleTodo(id: Int)
  DeleteTodo(id: Int)
}

pub fn todo_update(todos: List(TodoItem), msg: TodoMsg) -> List(TodoItem) {
  case msg {
    AddTodo(text) -> {
      let id = list.length(todos) + 1
      list.append(todos, [TodoItem(id:, text:, done: False)])
    }
    ToggleTodo(id) ->
      list.map(todos, fn(t) {
        case t.id == id {
          True -> TodoItem(..t, done: !t.done)
          False -> t
        }
      })
    DeleteTodo(id) -> list.filter(todos, fn(t) { t.id != id })
  }
}
