// Тесты Lustre:
// - Генерация HTML проверяется через element.to_string
// - Полный MVU-цикл тестируется через lustre/dev/simulate

import gleam/list
import gleeunit
import gleeunit/should
import lustre/dev/simulate
import lustre/element
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ── Упражнение 1: todo_item_view ─────────────────────────────────────────
// todo_item_view(text, done) рендерит один пункт списка.
// done=False → <li>☐ <текст></li>
// done=True  → <li class="done">✓ <текст></li>

pub fn todo_item_not_done_test() {
  my_solutions.todo_item_view("Buy milk", False)
  |> element.to_string
  |> should.equal("<li>☐ Buy milk</li>")
}

pub fn todo_item_done_test() {
  my_solutions.todo_item_view("Write tests", True)
  |> element.to_string
  |> should.equal("<li class=\"done\">✓ Write tests</li>")
}

// ── Упражнение 2: render_todo_list ──────────────────────────────────────
// render_todo_list([]) → <p class="empty">Список пуст</p>
// render_todo_list(todos) → <ul><li>☐ ...</li>...</ul>

pub fn render_todo_list_empty_test() {
  my_solutions.render_todo_list([])
  |> element.to_string
  |> should.equal("<p class=\"empty\">Список пуст</p>")
}

pub fn render_todo_list_one_item_test() {
  my_solutions.render_todo_list([#("Buy milk", False)])
  |> element.to_string
  |> should.equal("<ul><li>☐ Buy milk</li></ul>")
}

pub fn render_todo_list_mixed_test() {
  my_solutions.render_todo_list([#("Buy milk", False), #("Write tests", True)])
  |> element.to_string
  |> should.equal(
    "<ul><li>☐ Buy milk</li><li class=\"done\">✓ Write tests</li></ul>",
  )
}

// ── Упражнение 3: counter_init ───────────────────────────────────────────
// Начальное значение счётчика: 0
// Принимает флаги (Nil при запуске приложения)

pub fn counter_init_test() {
  my_solutions.counter_init(Nil)
  |> should.equal(0)
}

// ── Упражнение 4: counter_update ────────────────────────────────────────
// Функция обновления счётчика

pub fn counter_increment_test() {
  my_solutions.counter_update(0, my_solutions.CounterIncrement)
  |> should.equal(1)
}

pub fn counter_decrement_test() {
  my_solutions.counter_update(5, my_solutions.CounterDecrement)
  |> should.equal(4)
}

pub fn counter_reset_test() {
  my_solutions.counter_update(42, my_solutions.CounterReset)
  |> should.equal(0)
}

// ── Упражнение 5: полный MVU цикл через simulate ─────────────────────────
// Тест запускает полное приложение и отправляет сообщения

pub fn counter_simulate_increment_test() {
  simulate.simple(
    init: my_solutions.counter_init,
    update: my_solutions.counter_update,
    view: my_solutions.counter_view,
  )
  |> simulate.start(Nil)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.model
  |> should.equal(3)
}

pub fn counter_simulate_decrement_test() {
  simulate.simple(
    init: my_solutions.counter_init,
    update: my_solutions.counter_update,
    view: my_solutions.counter_view,
  )
  |> simulate.start(Nil)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterDecrement)
  |> simulate.model
  |> should.equal(1)
}

pub fn counter_simulate_reset_test() {
  simulate.simple(
    init: my_solutions.counter_init,
    update: my_solutions.counter_update,
    view: my_solutions.counter_view,
  )
  |> simulate.start(Nil)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterIncrement)
  |> simulate.message(my_solutions.CounterReset)
  |> simulate.model
  |> should.equal(0)
}

// ── Упражнение 6: todo_update ────────────────────────────────────────────
// Функция обновления для списка задач
// AddTodo добавляет задачу с id = list.length(todos) + 1
// ToggleTodo переключает todo.done по id
// DeleteTodo удаляет задачу по id

pub fn todo_update_add_test() {
  my_solutions.todo_update([], my_solutions.AddTodo("Buy milk"))
  |> should.equal([my_solutions.TodoItem(id: 1, text: "Buy milk", done: False)])
}

pub fn todo_update_add_second_test() {
  let existing = [my_solutions.TodoItem(id: 1, text: "Buy milk", done: False)]
  my_solutions.todo_update(existing, my_solutions.AddTodo("Write code"))
  |> list.length
  |> should.equal(2)
}

pub fn todo_update_toggle_test() {
  let todos = [my_solutions.TodoItem(id: 1, text: "Buy milk", done: False)]
  my_solutions.todo_update(todos, my_solutions.ToggleTodo(1))
  |> should.equal([my_solutions.TodoItem(id: 1, text: "Buy milk", done: True)])
}

pub fn todo_update_delete_test() {
  let todos = [
    my_solutions.TodoItem(id: 1, text: "Buy milk", done: False),
    my_solutions.TodoItem(id: 2, text: "Write code", done: False),
  ]
  my_solutions.todo_update(todos, my_solutions.DeleteTodo(1))
  |> should.equal([
    my_solutions.TodoItem(id: 2, text: "Write code", done: False),
  ])
}
