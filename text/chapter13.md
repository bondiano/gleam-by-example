# Фронтенд с Lustre

> The Elm Architecture на Gleam — типобезопасный UI для браузера и сервера.

<!-- toc -->

## Цели главы

В этой главе мы:

- Изучим Elm Architecture (TEA): Model → Update → View
- Познакомимся с виртуальным DOM Lustre
- Научимся работать с событиями и состоянием
- Разберём эффекты (HTTP-запросы, таймеры)
- Поймём, как Lustre работает на JavaScript-таргете
- Рассмотрим server components — компоненты на сервере с WebSocket
- Построим интерактивное TODO-приложение

## JavaScript-таргет Gleam

Lustre работает в браузере — это JavaScript-среда. Gleam компилируется как для Erlang, так и для JavaScript:

```bash
# Сборка для браузера
gleam build --target javascript

# Запуск тестов на Node.js
gleam test --target javascript
```

В `gleam.toml` можно задать таргет по умолчанию:

```toml
name = "my_app"
version = "1.0.0"
target = "javascript"
```

> **Важно:** большинство модулей из `gleam_erlang` и `gleam_otp` не работают на JS-таргете. Lustre-проекты используют `gleam_stdlib` и JS-совместимые библиотеки.

## The Elm Architecture

Lustre реализует Elm Architecture (TEA) — архитектурный паттерн с однонаправленным потоком данных:

```text
         ┌─────────────────────────────────┐
         │                                 │
    Msg  ▼                                 │
  ┌──────────┐    new state   ┌──────────┐ │
  │  update  │ ─────────────► │  model   │ │ Msg
  └──────────┘                └──────────┘ │
                                    │      │
                                    ▼      │
                              ┌──────────┐ │
                              │   view   │ │
                              └──────────┘ │
                                    │      │
                                    ▼      │
                              виртуальный  │
                                   DOM ────┘
                                (события)
```

Три компонента:

1. **Model** — состояние приложения (иммутабельные данные)
2. **Update** — чистая функция `fn(Model, Msg) -> Model`, которая создаёт новое состояние
3. **View** — чистая функция `fn(Model) -> Element(Msg)`, которая строит виртуальный DOM

Нет мутаций, нет глобального состояния — только чистые функции.

## Простое приложение: счётчик

```gleam
import gleam/int
import lustre
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// 1. Модель — состояние приложения
type Model =
  Int

// 2. Сообщения — возможные действия
type Msg {
  Increment
  Decrement
  Reset
}

// 3. Инициализация начального состояния
fn init(_flags) -> Model {
  0
}

// 4. Обновление состояния
fn update(model: Model, msg: Msg) -> Model {
  case msg {
    Increment -> model + 1
    Decrement -> model - 1
    Reset -> 0
  }
}

// 5. Отображение состояния
fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([], [element.text("Счётчик: " <> int.to_string(model))]),
    html.button([event.on_click(Increment)], [element.text("+")]),
    html.button([event.on_click(Decrement)], [element.text("-")]),
    html.button([event.on_click(Reset)], [element.text("Сброс")]),
  ])
}

// 6. Запуск приложения
pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
```

`lustre.simple` — для приложений без побочных эффектов. `lustre.start` монтирует приложение в DOM-элемент с селектором `#app`.

## Виртуальный DOM

Lustre строит виртуальное дерево элементов, которое затем эффективно синхронизируется с реальным DOM браузера.

### lustre/element

```gleam
import lustre/element.{type Element}

// Текстовый узел
element.text("Привет!")

// Произвольный элемент
element.element("my-component", [], [element.text("контент")])

// Фрагмент (несколько узлов без обёртки)
element.fragment([
  html.p([], [element.text("Первый")]),
  html.p([], [element.text("Второй")]),
])

// Пустой элемент (ничего не рендерится)
element.none()

// Преобразование типа сообщения
element.map(child_element, fn(child_msg) { ParentMsg(child_msg) })
```

`element.none()` полезен для условного рендеринга — возвращайте его там, где элемент не нужен, вместо обёртки в `Option`. `element.map` преобразует тип сообщения дочернего элемента, позволяя встраивать суб-компоненты с отличным типом `Msg`.

### lustre/element/html

Модуль `lustre/element/html` содержит функции для всех стандартных HTML-элементов. Каждая функция принимает `List(Attribute(msg))` и `List(Element(msg))`:

```gleam
import lustre/element/html

html.div([attribute.class("container")], [
  html.h1([], [element.text("Заголовок")]),
  html.p([], [element.text("Параграф")]),
  html.ul([], [
    html.li([], [element.text("Пункт 1")]),
    html.li([], [element.text("Пункт 2")]),
  ]),
])
```

Самозакрывающиеся (void) элементы не принимают дочерних узлов:

```gleam
html.input([attribute.type_("text"), attribute.placeholder("Введите...")])
html.br([])
html.hr([])
html.img([attribute.src("/logo.png"), attribute.alt("Логотип")])
```

Void-элементы не принимают дочерних узлов — в HTML они самозакрывающиеся. Попытка передать список дочерних элементов таким функциям приведёт к ошибке компиляции.

## Атрибуты

Модуль `lustre/attribute` содержит функции для HTML-атрибутов:

```gleam
import lustre/attribute

// Стандартные атрибуты
attribute.id("my-id")
attribute.class("btn btn-primary")
attribute.classes([#("active", is_active), #("disabled", is_disabled)])
attribute.style([#("color", "red"), #("font-size", "16px")])

// Форма
attribute.type_("text")        // type — зарезервировано, поэтому type_
attribute.value("текст")
attribute.placeholder("Введите...")
attribute.checked(True)
attribute.disabled(False)
attribute.name("email")

// Медиа и ссылки
attribute.src("/image.png")
attribute.href("/about")
attribute.alt("Описание")

// Произвольный атрибут
attribute.attribute("data-id", "42")
```

`attribute.classes` принимает список пар `#(class, bool)` и применяет только те классы, у которых условие — `True`. `attribute.style` принимает список пар `#(property, value)` вместо строки — удобнее для динамических стилей.

### Условные атрибуты

```gleam
fn button_view(is_loading: Bool) -> Element(Msg) {
  html.button(
    [
      attribute.disabled(is_loading),
      attribute.class(case is_loading {
        True -> "btn btn--loading"
        False -> "btn"
      }),
    ],
    [element.text("Сохранить")],
  )
}
```

`attribute.disabled(is_loading)` и условный класс вычисляются при каждом рендере — если `is_loading` изменится, Lustre автоматически обновит только изменившиеся атрибуты в DOM.

## События

Модуль `lustre/event` позволяет подписываться на DOM-события:

```gleam
import lustre/event

// Клик
html.button([event.on_click(ButtonClicked)], [element.text("Нажми")])

// Ввод текста — получаем значение поля
html.input([event.on_input(TextChanged)])

// Отправка формы
html.form([event.on_submit(FormSubmitted)], [...])

// Чекбокс
html.input([
  attribute.type_("checkbox"),
  event.on_check(CheckboxToggled),
])
```

`event.on_input` автоматически извлекает `event.target.value` из DOM-события и передаёт строку в сообщение. `event.on_check` передаёт булево значение состояния чекбокса.

### Произвольные события с декодером

```gleam
import gleam/dynamic/decode

// Считываем event.target.value из DOM-события
fn on_input_change(to_msg: fn(String) -> Msg) -> attribute.Attribute(Msg) {
  event.on("input", {
    use value <- decode.subfield(["target", "value"], decode.string)
    decode.success(to_msg(value))
  })
}
```

`event.on` принимает имя DOM-события и декодер, который разбирает нативный JavaScript-объект события. Это позволяет извлекать любые поля — не только `target.value`, но и координаты мыши, код клавиши и другие данные события.

### Debounce и throttle

```gleam
// Debounce: не отправлять сообщение чаще, чем раз в 300мс
event.on_input(TextChanged) |> event.debounce(300)

// Throttle: пропускать события не чаще раза в 100мс
event.on_mouse_move(MouseMoved) |> event.throttle(100)
```

`debounce` задерживает отправку сообщения: если пользователь печатает быстро, сообщение отправится только через 300мс после последнего нажатия — удобно для поиска в реальном времени. `throttle` ограничивает частоту — полезно для обработки движения мыши или скролла.

## Работа со списками

```gleam
import gleam/list

type Model {
  Model(todos: List(String), input: String)
}

type Msg {
  InputChanged(String)
  AddTodo
  RemoveTodo(Int)
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    // Поле ввода
    html.input([
      attribute.value(model.input),
      attribute.placeholder("Новая задача..."),
      event.on_input(InputChanged),
    ]),
    html.button([event.on_click(AddTodo)], [element.text("Добавить")]),

    // Список задач
    html.ul(
      [],
      list.index_map(model.todos, fn(todo, i) {
        html.li([], [
          element.text(todo),
          html.button(
            [event.on_click(RemoveTodo(i))],
            [element.text("✕")],
          ),
        ])
      }),
    ),
  ])
}
```

`list.index_map` передаёт в колбэк и элемент, и его индекс — это нужно, чтобы привязать к кнопке «✕» нужный номер задачи для `RemoveTodo(i)`. Атрибут `value` у `html.input` синхронизирует поле с моделью, делая ввод управляемым.

## Эффекты

Реальные приложения делают HTTP-запросы, работают с localStorage, таймерами. Для этого используются эффекты.

### lustre.application — приложение с эффектами

```gleam
import lustre
import lustre/effect.{type Effect}

fn init(flags) -> #(Model, Effect(Msg)) {
  #(
    Model(todos: [], loading: True),
    // Эффект запускается при инициализации
    fetch_todos(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LoadTodos -> #(model, fetch_todos())
    TodosLoaded(todos) -> #(Model(..model, todos:, loading: False), effect.none())
    AddTodo(text) -> #(
      Model(..model, todos: [text, ..model.todos]),
      effect.none(),
    )
  }
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
```

Отличие от `lustre.simple`: функции `init` и `update` возвращают `#(Model, Effect(Msg))` вместо просто `Model`.

### lustre_http — HTTP-запросы

```gleam
import lustre/effect.{type Effect}
import lustre_http

type Msg {
  GotTodos(Result(List(Todo), lustre_http.HttpError))
}

fn fetch_todos() -> Effect(Msg) {
  lustre_http.get(
    "https://api.example.com/todos",
    lustre_http.expect_json(todos_decoder(), GotTodos),
  )
}
```

`lustre_http.expect_json` принимает декодер и конструктор сообщения. При успехе декодирует JSON и передаёт результат в `GotTodos(Ok(...))`, при сетевой ошибке или неверном JSON — в `GotTodos(Error(...))`.

### Кастомные эффекты

```gleam
fn save_to_local_storage(key: String, value: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    // Выполняется как побочный эффект
    do_save_to_storage(key, value)
    dispatch(SaveComplete)
  })
}
```

`effect.from` создаёт эффект из функции, которая получает `dispatch` — колбэк для отправки сообщений обратно в Lustre. Код внутри выполняется вне цикла обновления, что позволяет делать любые побочные действия: запись в localStorage, подписки на события, таймеры.

### Группировка эффектов

```gleam
fn init(flags) -> #(Model, Effect(Msg)) {
  #(
    initial_model,
    effect.batch([
      fetch_todos(),
      load_user_preferences(),
    ]),
  )
}
```

`effect.batch` объединяет несколько эффектов в один — они запустятся параллельно при инициализации или обновлении. Это удобно, когда нужно сразу загрузить данные из нескольких источников.

## Компоненты

Lustre поддерживает переиспользуемые компоненты в виде Custom Elements Web Components.

### Регистрация компонента

```gleam
import lustre
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import gleam/int

type Model = Int

type Msg {
  Increment
  Decrement
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(0, effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Increment -> #(model + 1, effect.none())
    Decrement -> #(model - 1, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.button([event.on_click(Decrement)], [element.text("-")]),
    element.text(int.to_string(model)),
    html.button([event.on_click(Increment)], [element.text("+")]),
  ])
}

pub fn register() {
  lustre.component("my-counter", init, update, view, component.empty())
}
```

Использование в HTML:

```html
<my-counter></my-counter>
```

После вызова `register()` тег `<my-counter>` становится полноценным Custom Element — браузер автоматически монтирует в него Lustre-приложение при добавлении в DOM.

## Server Components

Lustre поддерживает серверные компоненты — UI-логика работает на BEAM-сервере, браузеру нужен лишь ~10kb клиентский рантайм.

### Как работают Server Components

```text
Браузер                          Сервер (BEAM)
┌─────────────┐  WebSocket/SSE  ┌──────────────────┐
│  ~10kb JS   │ ◄─── патчи ──── │  Lustre-процесс  │
│  рантайм    │ ──── события ►  │  (OTP-актор)     │
└─────────────┘                 └──────────────────┘
```

При каждом действии пользователя:

1. Браузер отправляет событие по WebSocket на сервер
2. Сервер запускает `update`, получает новый Model
3. Сервер вычисляет diff виртуального DOM
4. Браузер получает минимальный патч и применяет его

Server Components идеальны для:

- Дашбордов с real-time данными
- Совместного редактирования
- Чатов и уведомлений
- Приложений, где важен SEO и минимальный JS

## Проект: TODO-приложение

Соберём полный TODO-список с фильтрацией.

### Модель

```gleam
pub type Filter {
  All
  Active
  Completed
}

pub type Todo {
  Todo(id: Int, text: String, completed: Bool)
}

pub type Model {
  Model(
    todos: List(Todo),
    input: String,
    filter: Filter,
    next_id: Int,
  )
}
```

`Filter` — алгебраический тип для переключения видимых задач. `Todo` хранит уникальный `id`, текст и признак выполнения. `next_id` в `Model` монотонно растёт и гарантирует, что каждая новая задача получит уникальный идентификатор.

### Сообщения

```gleam
pub type Msg {
  InputChanged(String)
  AddTodo
  ToggleTodo(Int)
  DeleteTodo(Int)
  SetFilter(Filter)
  ClearCompleted
}
```

Каждое возможное действие пользователя — отдельный конструктор: ввод текста, добавление, переключение чекбокса, удаление задачи, смена фильтра и очистка выполненных. Система типов не даст забыть ни один случай в `update`.

### Update

```gleam
fn update(model: Model, msg: Msg) -> Model {
  case msg {
    InputChanged(text) -> Model(..model, input: text)

    AddTodo ->
      case string.trim(model.input) {
        "" -> model
        text -> {
          let todo = Todo(id: model.next_id, text:, completed: False)
          Model(
            ..model,
            todos: list.append(model.todos, [todo]),
            input: "",
            next_id: model.next_id + 1,
          )
        }
      }

    ToggleTodo(id) -> {
      let todos =
        list.map(model.todos, fn(todo) {
          case todo.id == id {
            True -> Todo(..todo, completed: !todo.completed)
            False -> todo
          }
        })
      Model(..model, todos:)
    }

    DeleteTodo(id) -> {
      let todos = list.filter(model.todos, fn(todo) { todo.id != id })
      Model(..model, todos:)
    }

    SetFilter(filter) -> Model(..model, filter:)

    ClearCompleted -> {
      let todos = list.filter(model.todos, fn(todo) { !todo.completed })
      Model(..model, todos:)
    }
  }
}
```

`AddTodo` сначала проверяет, что поле не пустое (`string.trim`), и только потом создаёт задачу — защита от пустых строк. `ToggleTodo` проходит по всему списку с `list.map` и инвертирует только нужный элемент по `id`, не трогая остальные.

### View

```gleam
fn filtered_todos(model: Model) -> List(Todo) {
  case model.filter {
    All -> model.todos
    Active -> list.filter(model.todos, fn(t) { !t.completed })
    Completed -> list.filter(model.todos, fn(t) { t.completed })
  }
}

fn view(model: Model) -> Element(Msg) {
  let remaining =
    model.todos
    |> list.filter(fn(t) { !t.completed })
    |> list.length

  html.div([attribute.class("app")], [
    html.h1([], [element.text("TODO")]),

    html.div([attribute.class("input-row")], [
      html.input([
        attribute.value(model.input),
        attribute.placeholder("Что нужно сделать?"),
        event.on_input(InputChanged),
      ]),
      html.button([event.on_click(AddTodo)], [element.text("Добавить")]),
    ]),

    html.ul(
      [attribute.class("todo-list")],
      model |> filtered_todos |> list.map(todo_view),
    ),

    html.div([attribute.class("footer")], [
      element.text(int.to_string(remaining) <> " осталось"),
      filter_buttons(model.filter),
    ]),
  ])
}

fn todo_view(todo: Todo) -> Element(Msg) {
  html.li([], [
    html.input([
      attribute.type_("checkbox"),
      attribute.checked(todo.completed),
      event.on_check(fn(_) { ToggleTodo(todo.id) }),
    ]),
    html.span([], [element.text(todo.text)]),
    html.button(
      [event.on_click(DeleteTodo(todo.id))],
      [element.text("✕")],
    ),
  ])
}
```

`filtered_todos` вычисляется заново при каждом вызове `view` — это нормально в функциональном UI, где вся функция рендера чистая. `todo_view` вынесена отдельно, чтобы `view` оставалась читаемой и компактной.

## Упражнения

Код упражнений находится в `exercises/chapter11/`.

Тесты запускаются на JavaScript-таргете:

```bash
cd exercises/chapter11
gleam test
```

---

**Упражнение 11.1** (Лёгкое): Рендеринг списка

```gleam
pub fn render_list(items: List(String)) -> Element(msg) {
  todo
}
```

Функция должна вернуть элемент `<ul>` с `<li>` для каждой строки из `items`.

*Подсказка*: `html.ul`, `html.li`, `list.map`.

---

**Упражнение 11.2** (Лёгкое): Инициализация счётчика

```gleam
pub fn counter_init() -> Int {
  todo
}
```

Возвращает начальное значение счётчика: `0`.

---

**Упражнение 11.3** (Лёгкое): Обновление счётчика

```gleam
pub type CounterMsg {
  CounterIncrement
  CounterDecrement
  CounterReset
}

pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  todo
}
```

`CounterIncrement` увеличивает на 1, `CounterDecrement` уменьшает на 1, `CounterReset` сбрасывает в 0.

---

**Упражнение 11.4** (Среднее, самостоятельное): Форма с валидацией

Реализуйте компонент формы:

- Поле для ввода email
- При отправке: если email содержит `@` — показать "OK", иначе — "Неверный email"
- Используйте `lustre.simple`

---

**Упражнение 11.5** (Сложное, самостоятельное): TODO с фильтрами

Реализуйте полноценный TODO-список с:

- Добавлением/удалением задач
- Отметкой выполнения (чекбокс)
- Тремя фильтрами: Все / Активные / Завершённые

## Итоги

Lustre предлагает строго типизированный UI с:

- **TEA** — однонаправленный поток данных, нет мутаций
- **Виртуальный DOM** — эффективные обновления браузера
- **Эффекты** — чистое управление побочными эффектами
- **Server Components** — компоненты на BEAM с WebSocket

Gleam позволяет использовать один язык и для бэкенда (Wisp, OTP), и для фронтенда (Lustre) — уникальная возможность в мире типизированных языков.

## Ресурсы

- [HexDocs — lustre](https://hexdocs.pm/lustre/)
- [Lustre Quickstart](https://hexdocs.pm/lustre/guide/01-quickstart.html)
- [Lustre — GitHub](https://github.com/lustre-labs/lustre)
- [Building your first Gleam web app with Wisp and Lustre](https://gleaming.dev/articles/building-your-first-gleam-web-app/)
