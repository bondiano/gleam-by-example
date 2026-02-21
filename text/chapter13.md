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

> **Связь с главой 9:** В главе 9 мы изучили JavaScript FFI — вызов JavaScript-функций через `@external`, работу с DOM API, промисами и классами. Lustre абстрагирует всю эту низкоуровневую работу: вместо прямых вызовов `document.getElementById` и `addEventListener` вы работаете с виртуальным DOM и декларативными событиями. Однако знание FFI из главы 9 пригодится для интеграции сторонних JavaScript-библиотек с Lustre.

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

## The Elm Architecture (TEA)

### История и философия

The Elm Architecture (TEA) — архитектурный паттерн, разработанный **Evan Czaplicki** для языка Elm в 2012 году. Паттерн возник как решение проблемы управления состоянием в функциональном языке без мутаций и побочных эффектов.

Ключевая идея TEA: **однонаправленный поток данных** (unidirectional data flow). В отличие от двунаправленного биндинга (MVC, MVVM), где изменения могут распространяться в обе стороны, TEA строго контролирует порядок обновлений:

```text
Пользователь → Событие → Сообщение → Update → Новая Модель → View → UI
              ↑                                                        │
              └────────────────────────────────────────────────────────┘
```

Это делает состояние **предсказуемым**: одна и та же последовательность сообщений всегда приводит к одному и тому же состоянию. Нет скрытых мутаций, нет «action at a distance».

### Влияние TEA на индустрию

TEA вдохновил множество фреймворков и архитектур:

- **Redux** (JavaScript) — почти прямая адаптация TEA для React, созданная Dan Abramov
- **Elmish** (F#) — TEA для .NET экосистемы
- **SwiftUI** (Swift) — Apple использовала идеи TEA для декларативного UI
- **Iced** (Rust) — GUI-фреймворк для Rust на основе TEA
- **Lustre** (Gleam) — то, что мы изучаем в этой главе

### Компоненты TEA

Lustre реализует классическую Elm Architecture с тремя компонентами:

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

**1. Model** — состояние приложения (иммутабельные данные)
```gleam
type Model {
  Model(count: Int, todos: List(String))
}
```

**2. Msg** — алгебраический тип всех возможных действий
```gleam
type Msg {
  Increment
  AddTodo(String)
  DeleteTodo(Int)
}
```

**3. Update** — чистая функция `fn(Model, Msg) -> Model`
```gleam
fn update(model: Model, msg: Msg) -> Model {
  case msg {
    Increment -> Model(..model, count: model.count + 1)
    // ...
  }
}
```

**4. View** — чистая функция `fn(Model) -> Element(Msg)`
```gleam
fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([], [element.text("Count: " <> int.to_string(model.count))]),
    html.button([event.on_click(Increment)], [element.text("+")])
  ])
}
```

### Преимущества TEA

**Типобезопасность.** Система типов гарантирует, что каждое сообщение обработано — забытый case приведёт к ошибке компиляции.

**Предсказуемость.** Чистые функции `update` и `view` всегда дают один результат для одного входа. Нет скрытого состояния.

**Тестируемость.** Логика приложения — чистые функции без I/O. Тесты просты: `assert update(model, Increment) == Model(count: 1)`.

**Time-travel debugging.** Последовательность сообщений полностью описывает историю приложения. Можно «прокручивать» состояние назад и вперёд.

**Масштабируемость.** Локальные изменения не ломают удалённые части приложения — каждое сообщение явно объявлено в типе `Msg`.

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

> **Из главы 9:** `lustre_http` под капотом использует JavaScript `Promise` (промисы), которые мы изучили в главе 9. Функция `fetch()` возвращает промис, который разрешается в `Response`, затем преобразуется в JSON. Lustre оборачивает это в типобезопасный эффект.

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

Lustre поддерживает **серверные компоненты** — революционный подход, где UI-логика работает на BEAM-сервере, а браузеру нужен лишь ~10kb клиентский рантайм для применения патчей.

### Как работают Server Components

```text
Браузер                          Сервер (BEAM)
┌─────────────┐  WebSocket/SSE  ┌──────────────────┐
│  ~10kb JS   │ ◄─── патчи ──── │  Lustre-процесс  │
│  рантайм    │ ──── события ►  │  (OTP-актор)     │
└─────────────┘                 └──────────────────┘
        ▲                                │
        │         JSON-патчи            ▼
    DOM updates          {type: "set_attribute", ...}
```

**Жизненный цикл:**

1. **Подключение:** Браузер открывает WebSocket к серверу и запрашивает начальный HTML
2. **Инициализация:** Сервер создаёт OTP-актор (процесс) для этого клиента, вызывает `init`, возвращает начальный рендер
3. **Взаимодействие:** Пользователь кликает кнопку → браузер отправляет событие по WebSocket → сервер вызывает `update(model, msg)` → вычисляет diff → отправляет патч браузеру
4. **Патчинг:** Браузер применяет патч к реальному DOM (минимальные изменения)
5. **Отключение:** WebSocket закрывается → OTP-актор останавливается (супервизор может перезапустить при сбое)

### Пример: Real-Time Dashboard

```gleam
import gleam/int
import gleam/erlang/process
import lustre
import lustre/element.{type Element}
import lustre/element/html
import lustre/attribute
import lustre/effect.{type Effect}

type Model {
  Model(connected_users: Int, requests_per_second: Int, uptime_seconds: Int)
}

type Msg {
  Tick
  UserConnected
  UserDisconnected
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(
    Model(connected_users: 0, requests_per_second: 0, uptime_seconds: 0),
    // Запускаем таймер — каждую секунду отправляем Tick
    effect.from(fn(dispatch) {
      process.send_after(process.self(), 1000, Tick)
      dispatch(Tick)
    }),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> #(
      Model(
        ..model,
        uptime_seconds: model.uptime_seconds + 1,
        requests_per_second: random_int(50, 200),
      ),
      // Следующий тик через 1 секунду
      effect.from(fn(dispatch) {
        process.send_after(process.self(), 1000, Tick)
      }),
    )
    UserConnected -> #(
      Model(..model, connected_users: model.connected_users + 1),
      effect.none(),
    )
    UserDisconnected -> #(
      Model(..model, connected_users: model.connected_users - 1),
      effect.none(),
    )
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("dashboard")], [
    html.h1([], [element.text("Server Dashboard")]),
    html.div([attribute.class("metrics")], [
      metric("Connected Users", int.to_string(model.connected_users)),
      metric("Requests/sec", int.to_string(model.requests_per_second)),
      metric("Uptime", format_uptime(model.uptime_seconds)),
    ]),
  ])
}

fn metric(label: String, value: String) -> Element(msg) {
  html.div([attribute.class("metric")], [
    html.div([attribute.class("label")], [element.text(label)]),
    html.div([attribute.class("value")], [element.text(value)]),
  ])
}

// Запуск server component
pub fn main() {
  lustre.start_server_component(lustre.application(init, update, view))
}
```

Каждый подключённый пользователь получает **собственный процесс-актор** на сервере. Когда таймер срабатывает, `update` вычисляет новое состояние, Lustre рендерит виртуальный DOM, вычисляет diff и отправляет только изменения в браузер.

### Сравнение с аналогами

| | **Lustre Server Components** | **Phoenix LiveView** | **Blazor Server** |
|---|---|---|---|
| **Язык** | Gleam | Elixir | C# |
| **Платформа** | BEAM VM | BEAM VM | .NET CLR |
| **Транспорт** | WebSocket/SSE | WebSocket | SignalR (WebSocket) |
| **Процесс на клиента** | ✅ OTP-актор | ✅ GenServer | ❌ Общий поток |
| **Типобезопасность** | ✅ Статическая | ⚠️ Динамическая | ✅ Статическая |
| **Размер клиента** | ~10kb | ~30kb | ~500kb |
| **Отказоустойчивость** | ✅ Let it crash | ✅ Let it crash | ⚠️ Требует настройки |

**Phoenix LiveView** (Elixir) — прямой вдохновитель Lustre Server Components. Обе технологии используют BEAM VM и один процесс на подключение. Основное отличие: Gleam даёт статическую типизацию, а Elixir — динамическую.

**Blazor Server** (C#/.NET) — похожий подход, но без изоляции процессов. Все клиенты обслуживаются в одном .NET процессе, что ограничивает отказоустойчивость.

### Trade-offs: когда использовать Server Components?

**✅ Используйте Server Components когда:**

- **Real-time данные** — дашборды, мониторинг, чаты, совместное редактирование
- **Минимальный JavaScript** — важен SEO, быстрая загрузка на медленных сетях
- **Доступ к серверу** — нужен прямой доступ к БД, файловой системе, внутренним API
- **Безопасность** — бизнес-логика остаётся на сервере, не утекает в клиентский бандл
- **Есть BEAM-инфраструктура** — уже используете Erlang/Elixir/Gleam на бэкенде

**❌ Избегайте Server Components когда:**

- **Высокая латентность** — пользователи из разных континентов (каждый клик = round-trip)
- **Офлайн-режим** — приложение должно работать без сети (PWA, мобильные приложения)
- **Интенсивная интерактивность** — анимации, drag-and-drop, игры (лаг будет заметен)
- **Масштабирование горизонтально** — миллионы одновременных пользователей (требуется sticky sessions или Redis Pub/Sub)
- **Статический хостинг** — нельзя использовать серверную логику (GitHub Pages, Netlify без функций)

**Гибридный подход:** используйте Server Components для административных панелей и дашбордов, а классические SPA (CSR) — для публичного интерфейса с высокой интерактивностью.

## Full-Stack приложения: Lustre + Wisp

Lustre позволяет создавать **full-stack приложения** на Gleam: Wisp (Erlang-таргет) на сервере, Lustre (JavaScript-таргет) в браузере. Одна кодовая база, два таргета, общие типы.

### Структура монорепозитория

Рекомендуемая структура для full-stack проекта:

```text
my_app/
├── client/              # Lustre SPA (target = javascript)
│   ├── gleam.toml
│   ├── src/
│   │   ├── client.gleam
│   │   └── client_ffi.mjs
│   └── index.html
├── server/              # Wisp API (target = erlang)
│   ├── gleam.toml
│   ├── src/
│   │   ├── server.gleam
│   │   └── routes.gleam
│   └── priv/
│       └── static/      # Собранный клиент
└── shared/              # Общие типы и функции
    ├── gleam.toml
    └── src/
        ├── models.gleam  # Общие типы данных
        └── codecs.gleam  # JSON-кодеки
```

Три независимых Gleam-проекта:

1. **client** — JavaScript-таргет, зависит от `lustre` и `shared`
2. **server** — Erlang-таргет, зависит от `wisp`, `mist`, `pog` и `shared`
3. **shared** — без таргета (или оба), экспортирует типы и функции

### Общие типы (shared/src/models.gleam)

```gleam
// Общие типы для клиента и сервера
pub type Todo {
  Todo(id: Int, text: String, completed: Bool)
}

pub type User {
  User(id: Int, name: String, email: String)
}

pub type ApiResponse(data) {
  Success(data: data)
  Error(message: String)
}
```

Эти типы компилируются и для JavaScript (клиент), и для Erlang (сервер) — гарантируется согласованность.

### JSON-кодеки (shared/src/codecs.gleam)

```gleam
import gleam/json
import gleam/dynamic/decode
import shared/models.{type Todo}

// Энкодинг: Gleam → JSON (для отправки с сервера)
pub fn encode_todo(todo: Todo) -> json.Json {
  json.object([
    #("id", json.int(todo.id)),
    #("text", json.string(todo.text)),
    #("completed", json.bool(todo.completed)),
  ])
}

pub fn encode_todos(todos: List(Todo)) -> json.Json {
  json.array(todos, encode_todo)
}

// Декодинг: JSON → Gleam (для чтения на клиенте)
pub fn decode_todo(value: dynamic.Dynamic) -> Result(Todo, decode.DecodeErrors) {
  decode.into({
    use id <- decode.field("id", decode.int)
    use text <- decode.field("text", decode.string)
    use completed <- decode.field("completed", decode.bool)
    models.Todo(id:, text:, completed:)
  })
  |> decode.from(value)
}

pub fn decode_todos(value: dynamic.Dynamic) -> Result(List(Todo), decode.DecodeErrors) {
  decode.list(decode_todo) |> decode.from(value)
}
```

Кодеки живут в `shared` и используются на обеих сторонах — сервер энкодит, клиент декодит.

### Сервер: API-роуты (server/src/routes.gleam)

```gleam
import gleam/http
import gleam/json
import wisp
import shared/codecs
import shared/models.{type Todo, Todo}

// Получить все TODO
pub fn get_todos(req: wisp.Request) -> wisp.Response {
  // В реальном приложении — запрос к БД
  let todos = [
    Todo(id: 1, text: "Изучить Lustre", completed: True),
    Todo(id: 2, text: "Построить full-stack приложение", completed: False),
  ]

  let json_body = codecs.encode_todos(todos) |> json.to_string()

  wisp.response(200)
  |> wisp.set_header("content-type", "application/json")
  |> wisp.set_body(wisp.Text(json_body))
}

// Создать новое TODO
pub fn create_todo(req: wisp.Request) -> wisp.Response {
  use body <- wisp.require_string_body(req)

  case json.parse(body, codecs.decode_todo) {
    Ok(todo) -> {
      // Сохранить в БД...
      let response = codecs.encode_todo(todo) |> json.to_string()
      wisp.json_response(response, 201)
    }
    Error(_) -> wisp.bad_request()
  }
}
```

Сервер использует `shared/codecs` для сериализации данных в JSON.

### Клиент: Lustre SPA (client/src/client.gleam)

```gleam
import gleam/http
import gleam/json
import gleam/result
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_http
import shared/models.{type Todo}
import shared/codecs

type Model {
  Model(todos: List(Todo), loading: Bool)
}

type Msg {
  FetchTodos
  TodosFetched(Result(List(Todo), lustre_http.HttpError))
}

fn init(_) -> #(Model, Effect(Msg)) {
  #(
    Model(todos: [], loading: True),
    fetch_todos(),
  )
}

fn fetch_todos() -> Effect(Msg) {
  lustre_http.get(
    "/api/todos",
    lustre_http.expect_json(codecs.decode_todos, TodosFetched),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    FetchTodos -> #(Model(..model, loading: True), fetch_todos())

    TodosFetched(Ok(todos)) -> #(
      Model(..model, todos:, loading: False),
      effect.none(),
    )

    TodosFetched(Error(_)) -> #(
      Model(..model, loading: False),
      effect.none(),
    )
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([], [element.text("TODO List")]),
    case model.loading {
      True -> html.p([], [element.text("Загрузка...")])
      False -> render_todos(model.todos)
    },
  ])
}

fn render_todos(todos: List(Todo)) -> Element(msg) {
  html.ul([], list.map(todos, render_todo))
}

fn render_todo(todo: Todo) -> Element(msg) {
  html.li([], [element.text(todo.text)])
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}
```

Клиент использует те же `shared/models` и `shared/codecs` — полная типобезопасность от сервера до браузера.

### Сборка и развёртывание

**1. Соберите клиента:**

```bash
cd client
gleam build --target javascript
# Результат в build/dev/javascript/client/client.mjs
```

**2. Скопируйте клиентский бандл в `server/priv/static/`:**

```bash
cp build/dev/javascript/client/client.mjs ../server/priv/static/
```

**3. Соберите сервер:**

```bash
cd ../server
gleam build
gleam run
```

**4. Настройте роуты для статики:**

```gleam
// server/src/server.gleam
import wisp

pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.serve_static(req, under: "/static", from: "/priv/static")

  case wisp.path_segments(req) {
    [] -> index_page()  // Отдаёт HTML с <script src="/static/client.mjs">
    ["api", "todos"] -> routes.get_todos(req)
    _ -> wisp.not_found()
  }
}
```

### Автоматизация сборки

Добавьте скрипт в `package.json` или `justfile`:

```json
{
  "scripts": {
    "build:client": "cd client && gleam build",
    "build:server": "cd server && gleam build",
    "build": "npm run build:client && cp client/build/dev/javascript/client/client.mjs server/priv/static/ && npm run build:server",
    "dev": "npm run build && cd server && gleam run"
  }
}
```

Теперь `npm run dev` собирает оба проекта и запускает сервер.

### Преимущества full-stack Gleam

✅ **Одна кодовая база** — один язык, одни инструменты, одна система типов
✅ **Общие типы** — изменения в модели сразу видны и на клиенте, и на сервере
✅ **Типобезопасные API** — декодеры гарантируют, что JSON соответствует типам
✅ **Рефакторинг без страха** — переименовали поле? Компилятор найдёт все проблемы
✅ **Кодогенерация не нужна** — никаких OpenAPI, Swagger, GraphQL Codegen

## Server-Side Rendering (SSR)

Lustre также поддерживает **статический серверный рендеринг** — генерацию HTML на сервере без интерактивности. Это полезно для:

- SEO-оптимизации (поисковые боты видят готовый HTML)
- Быстрой первой отрисовки (Time to First Paint)
- Статических страниц (блоги, документация, лендинги)
- Прогрессивного улучшения (Progressive Enhancement)

### Рендеринг элементов в HTML

Lustre предоставляет две функции для конвертации виртуального DOM в строку:

```gleam
import lustre/element

// Рендерит элемент в HTML-фрагмент
element.to_string(my_element)
// "<div><h1>Hello</h1></div>"

// Рендерит элемент в полный HTML-документ с <!DOCTYPE>
element.to_document_string(my_element)
// "<!DOCTYPE html><html><head>...</head><body>...</body></html>"
```

### Пример: SSR-роут в Wisp

```gleam
import gleam/int
import lustre/element
import lustre/element/html
import lustre/attribute
import wisp

type Model {
  Model(count: Int)
}

fn view(model: Model) -> element.Element(msg) {
  html.html([], [
    html.head([], [
      html.title([], [element.text("Counter App")]),
      html.meta([attribute.attribute("charset", "utf-8")]),
    ]),
    html.body([], [
      html.h1([], [element.text("Server-Rendered Counter")]),
      html.p([], [element.text("Count: " <> int.to_string(model.count))]),
      html.a([attribute.href("/increment")], [element.text("Increment")]),
    ]),
  ])
}

pub fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    [] -> {
      let model = Model(count: 0)
      let html = view(model) |> element.to_document_string()
      wisp.html_response(html, 200)
    }
    ["increment"] -> {
      let model = Model(count: 1)
      let html = view(model) |> element.to_document_string()
      wisp.html_response(html, 200)
    }
    _ -> wisp.not_found()
  }
}
```

Здесь сервер рендерит HTML на каждый запрос — нет JavaScript, нет интерактивности. Страница полностью статична.

### Гидратация (Hydration)

Чтобы добавить интерактивность к серверно-отрендеренному HTML, используется **гидратация** — процесс «оживления» статического HTML клиентским JavaScript.

Идея: сервер рендерит начальное состояние, клиент подхватывает его и продолжает работу как SPA.

**Шаг 1:** Сериализуем модель в JSON и встраиваем в HTML

```gleam
import gleam/json

fn view_with_state(model: Model) -> element.Element(msg) {
  html.html([], [
    html.head([], [...]),
    html.body([], [
      html.div([attribute.id("app")], [
        // Серверный рендер начального состояния
        render_counter(model),
      ]),

      // Встраиваем модель как JSON
      html.script([], [
        element.text(
          "window.__INITIAL_STATE__ = "
          <> json.to_string(model_to_json(model))
          <> ";"
        ),
      ]),

      // Подключаем клиентский бандл
      html.script([attribute.src("/static/app.js")], []),
    ]),
  ])
}

fn model_to_json(model: Model) -> json.Json {
  json.object([
    #("count", json.int(model.count)),
  ])
}
```

**Шаг 2:** На клиенте читаем `__INITIAL_STATE__` и инициализируем приложение

```gleam
// client.gleam (компилируется в JavaScript)
import lustre
import gleam/dynamic/decode

@external(javascript, "./client_ffi.mjs", "getInitialState")
fn get_initial_state() -> dynamic.Dynamic

fn init(_flags) -> Model {
  case decode_model(get_initial_state()) {
    Ok(model) -> model
    Error(_) -> Model(count: 0)  // Fallback
  }
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}
```

```javascript
// client_ffi.mjs
export function getInitialState() {
  return window.__INITIAL_STATE__ || {};
}
```

Теперь сервер рендерит начальный HTML (быстрая первая отрисовка), а клиент подхватывает состояние и продолжает работу (интерактивность).

### SSR vs CSR vs Server Components

| Подход | Где рендер | Где логика | Интерактивность | SEO |
|--------|-----------|-----------|----------------|-----|
| **CSR (SPA)** | Браузер | Браузер | Мгновенная | ❌ Требует JS |
| **SSR + гидратация** | Сервер → Браузер | Браузер | После загрузки | ✅ Готовый HTML |
| **Server Components** | Сервер | Сервер | Через WebSocket | ✅ Готовый HTML |
| **Статический SSR** | Сервер | — | Нет | ✅ Готовый HTML |

Выбор зависит от приоритетов:

- **CSR** — максимальная интерактивность, не нужен сервер
- **SSR + гидратация** — баланс SEO и интерактивности
- **Server Components** — real-time, минимальный JS, но требует постоянного соединения
- **Статический SSR** — максимальная производительность, но без интерактивности

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

---

**Упражнение 11.6** (Сложное, интеграция FFI): Lustre + date-fns

> **Применение главы 9:** Это упражнение требует знаний из главы 9 (JavaScript FFI, классы и библиотеки).

Интегрируйте JavaScript-библиотеку `date-fns` в Lustre-приложение:

1. Установите `date-fns`: `npm install date-fns`
2. Создайте FFI-модуль `src/date_ffi.mjs`:

```javascript
import { format, addDays, differenceInDays } from 'date-fns';

export function formatDate(date, pattern) {
  return format(date, pattern);
}

export function addDays(date, days) {
  return addDays(date, days);
}

export function now() {
  return new Date();
}

export function differenceInDays(dateLeft, dateRight) {
  return differenceInDays(dateLeft, dateRight);
}
```

3. Создайте Gleam-обёртку `src/date_utils.gleam`:

```gleam
pub type JSDate

@external(javascript, "./date_ffi.mjs", "now")
pub fn now() -> JSDate

@external(javascript, "./date_ffi.mjs", "formatDate")
pub fn format_date(date: JSDate, pattern: String) -> String

@external(javascript, "./date_ffi.mjs", "addDays")
pub fn add_days(date: JSDate, days: Int) -> JSDate

@external(javascript, "./date_ffi.mjs", "differenceInDays")
pub fn difference_in_days(date_left: JSDate, date_right: JSDate) -> Int
```

4. Реализуйте приложение, которое:
   - Показывает текущую дату в формате `"yyyy-MM-dd"`
   - Позволяет добавить/вычесть дни (кнопки "+1 день", "-1 день")
   - Показывает разницу в днях от сегодняшней даты

**Ожидаемый результат:**

```text
Текущая дата: 2026-02-21
Выбранная дата: 2026-02-25 (+4 дня от сегодня)

[−1 день] [Сегодня] [+1 день]
```

**Подсказка:** модель — `Model(selected_date: JSDate, today: JSDate)`.

## Итоги

Lustre предлагает строго типизированный UI с:

- **TEA** — однонаправленный поток данных, нет мутаций
- **Виртуальный DOM** — эффективные обновления браузера
- **Эффекты** — чистое управление побочными эффектами
- **Server Components** — компоненты на BEAM с WebSocket

Gleam позволяет использовать один язык и для бэкенда (Wisp, OTP), и для фронтенда (Lustre) — уникальная возможность в мире типизированных языков.

## TEA в других языках и фреймворках

Если вам понравилась The Elm Architecture, вот другие реализации и вдохновлённые ей фреймворки:

### Elm (оригинал)
- **Язык:** Elm (чисто функциональный, компилируется в JavaScript)
- **Сайт:** https://elm-lang.org/
- Оригинальная реализация TEA от Evan Czaplicki
- Самая строгая типизация, нет runtime exceptions
- Идеален для изучения TEA в чистом виде

### Redux (JavaScript/TypeScript)
- **Экосистема:** React
- **Сайт:** https://redux.js.org/
- TEA для JavaScript: actions = Msg, reducers = update
- Redux Toolkit упрощает шаблонный код
- Самая популярная адаптация TEA (миллионы приложений)

### Elmish (F#)
- **Платформа:** .NET
- **Сайт:** https://elmish.github.io/elmish/
- TEA для F# с поддержкой .NET экосистемы
- Интеграция с Xamarin, WPF, Avalonia
- Использует F# discriminated unions для Msg

### Iced (Rust)
- **Применение:** Desktop GUI
- **Сайт:** https://iced.rs/
- Кроссплатформенный GUI-фреймворк на основе TEA
- Использует Rust enums для сообщений
- Поддержка WebAssembly для веб-приложений

### SwiftUI (Swift)
- **Платформа:** Apple (iOS, macOS, watchOS)
- Декларативный UI с однонаправленным потоком данных
- `@State` и `@Binding` вдохновлены TEA
- Интегрирован в официальный SDK Apple

## Ресурсы

**Lustre:**
- [HexDocs — lustre](https://hexdocs.pm/lustre/)
- [Lustre Quickstart](https://hexdocs.pm/lustre/guide/01-quickstart.html)
- [Lustre — GitHub](https://github.com/lustre-labs/lustre)
- [Building your first Gleam web app with Wisp and Lustre](https://gleaming.dev/articles/building-your-first-gleam-web-app/)

**The Elm Architecture:**
- [The Elm Architecture (оригинальный гайд)](https://guide.elm-lang.org/architecture/)
- [Redux — A Predictable State Container for JS Apps](https://redux.js.org/)
- [Elmish: Elm-like abstractions for F#](https://elmish.github.io/elmish/)
