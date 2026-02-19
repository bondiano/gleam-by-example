//// Здесь вы можете писать свои решения упражнений.
////
//// Запуск тестов: gleam test

import lustre/element.{type Element}

// ── Упражнение 1 ─────────────────────────────────────────────────────────
// Рендерит одну задачу как HTML-элемент <li>.
//
// todo_item_view("Buy milk", False)  → <li>☐ Buy milk</li>
// todo_item_view("Write tests", True) → <li class="done">✓ Write tests</li>
//
// Подсказка:
//   html.li([attribute.class("done")], [...]) — с классом
//   html.li([], [...])                        — без класса
//   element.text("☐ " <> text)               — для текста

pub fn todo_item_view(text: String, done: Bool) -> Element(msg) {
  todo
}

// ── Упражнение 2 ─────────────────────────────────────────────────────────
// Рендерит список задач.
//
// render_todo_list([]) → <p class="empty">Список пуст</p>
// render_todo_list([#("Buy milk", False)]) → <ul><li>☐ Buy milk</li></ul>
//
// Подсказка:
//   case todos { [] -> ... items -> html.ul([], list.map(items, ...)) }
//   todo_item_view из упражнения 1 — для каждого элемента

pub fn render_todo_list(todos: List(#(String, Bool))) -> Element(msg) {
  todo
}

// ── Упражнения 3-5: счётчик (Model-View-Update) ──────────────────────────

/// Тип сообщений счётчика.
pub type CounterMsg {
  CounterIncrement
  CounterDecrement
  CounterReset
}

/// Начальное состояние счётчика.
/// Принимает флаги (Nil). Должно вернуть 0.
pub fn counter_init(_flags) -> Int {
  todo
}

/// Обновление счётчика.
///
/// CounterIncrement → +1
/// CounterDecrement → -1
/// CounterReset     → 0
pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  todo
}

/// View-функция счётчика.
/// Должна вернуть любой Element(CounterMsg) — содержимое не тестируется.
///
/// Подсказка: html.div([], [html.button([event.on_click(CounterIncrement)], [...]), ...])
pub fn counter_view(model: Int) -> Element(CounterMsg) {
  todo
}

// ── Упражнение 6: TODO-список (Model-View-Update) ────────────────────────

/// Тип одной задачи.
pub type TodoItem {
  TodoItem(id: Int, text: String, done: Bool)
}

/// Тип сообщений для TODO-списка.
pub type TodoMsg {
  AddTodo(text: String)
  ToggleTodo(id: Int)
  DeleteTodo(id: Int)
}

/// Обновление списка задач.
///
/// AddTodo(text)   — добавить задачу. id = list.length(todos) + 1
/// ToggleTodo(id)  — переключить done у задачи с данным id
/// DeleteTodo(id)  — удалить задачу с данным id
///
/// Подсказка:
///   list.map(todos, fn(t) { case t.id == id { True -> TodoItem(..t, done: !t.done) False -> t } })
///   list.filter(todos, fn(t) { t.id != id })

pub fn todo_update(todos: List(TodoItem), msg: TodoMsg) -> List(TodoItem) {
  todo
}
