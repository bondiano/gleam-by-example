# JavaScript FFI и фронтенд интеграция

> «Any application that can be written in JavaScript, will eventually be written in JavaScript.» — Jeff Atwood

<!-- toc -->

## Цели главы

В этой главе мы:

- Научимся вызывать JavaScript функции через `@external`
- Изучим двойной FFI (Erlang + JavaScript)
- Познакомимся с `gleam_javascript` и работой с промисами
- Поймём различия между JS concurrency и BEAM processes
- Создадим обёртки для DOM API и браузерных функций
- Построим типобезопасный интерфейс для работы с JavaScript-библиотеками

## External functions для JavaScript

Для JS-таргета FFI-функции определяются в отдельном `.mjs` файле:

```gleam
// В src/my_module.gleam
@external(javascript, "./my_ffi.mjs", "getCurrentTime")
pub fn current_time() -> Int
```

```javascript
// В src/my_ffi.mjs
export function getCurrentTime() {
  return Date.now();
}
```

Для JavaScript-таргета FFI-функция объявляется в Gleam с атрибутом `@external(javascript, ...)`, а её реализация помещается в отдельный `.mjs`-файл, который экспортирует соответствующую функцию.

### Соглашения о путях

Путь к `.mjs` файлу указывается относительно `.gleam` файла:

```gleam
// В src/api/client.gleam
@external(javascript, "./client_ffi.mjs", "fetch")
// Ищет src/api/client_ffi.mjs

@external(javascript, "../utils_ffi.mjs", "log")
// Ищет src/utils_ffi.mjs
```

Путь к FFI-файлу всегда относительный: `./` означает ту же директорию, что и `.gleam`-файл, `../` — на уровень выше. Компилятор автоматически находит соответствующий `.mjs`-файл рядом с вашим модулем.

### Конвертация типов между Gleam и JavaScript

| Gleam Type | JavaScript Type |
| ----------- | ---------------- |
| `Int` | `number` |
| `Float` | `number` |
| `String` | `string` |
| `Bool` | `boolean` |
| `List(a)` | `Array` (immutable) |
| `Result(a, b)` | `{type: "Ok", 0: value}` или `{type: "Error", 0: error}` |
| `Option(a)` | `{type: "Some", 0: value}` или `{type: "None"}` |
| `#(a, b)` | `[a, b]` (array) |
| Custom type | Object с полем `type` |

### Пример: работа с localStorage

```javascript
// src/storage_ffi.mjs
export function getItem(key) {
  const value = localStorage.getItem(key);
  if (value === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: value };
}

export function setItem(key, value) {
  try {
    localStorage.setItem(key, value);
    return { type: "Ok", 0: undefined };
  } catch (e) {
    return { type: "Error", 0: e.message };
  }
}
```

```gleam
@external(javascript, "./storage_ffi.mjs", "getItem")
pub fn get_item(key: String) -> Result(String, Nil)

@external(javascript, "./storage_ffi.mjs", "setItem")
pub fn set_item(key: String, value: String) -> Result(Nil, String)
```

В JavaScript `Result` представлен как объект с полем `type`: `{type: "Ok", 0: value}` для успеха и `{type: "Error", 0: error}` для ошибки. FFI-функция вручную создаёт эти объекты, а Gleam воспринимает их как типобезопасный `Result`. Обратите внимание: `null` из `localStorage.getItem` конвертируется в `Error(Nil)`, а ошибка `localStorage.setItem` — в `Error(String)`.

## Двойной FFI (Erlang + JavaScript)

Одна функция может иметь реализации для обоих таргетов:

```gleam
@external(erlang, "erlang", "system_time")
@external(javascript, "./time_ffi.mjs", "systemTime")
pub fn system_time() -> Int
```

Компилятор выберет нужную реализацию в зависимости от таргета (`gleam build --target erlang` или `--target javascript`).

### Пример: универсальное логирование

```gleam
// src/logger.gleam
@external(erlang, "io", "format")
@external(javascript, "./logger_ffi.mjs", "log")
pub fn log(message: String) -> Nil
```

```javascript
// src/logger_ffi.mjs
export function log(message) {
  console.log(message);
}
```

Такой код работает и на BEAM, и в браузере — компилятор автоматически выбирает правильную реализацию.

### Функции с Gleam-реализацией + FFI

Можно объявить функцию с телом на Gleam и FFI-альтернативой. Если FFI доступен для текущего таргета, он используется; иначе — Gleam-реализация:

```gleam
@external(javascript, "./fast_ffi.mjs", "reverse")
pub fn reverse(xs: List(a)) -> List(a) {
  // Gleam-реализация как fallback
  list.reverse(xs)
}
```

Такой подход позволяет использовать оптимизированную нативную реализацию там, где она доступна, и автоматически откатываться к Gleam-коду на других платформах.

## Функции с переменным числом аргументов (rest parameters)

В отличие от Erlang, JavaScript поддерживает функции с переменным числом аргументов через rest parameters (`...args`). Многие встроенные функции используют этот паттерн:

```javascript
// JavaScript: console.log принимает любое число аргументов
console.log("Hello", "world", 123, true);

// Math.max находит максимум из N чисел
Math.max(1, 5, 3, 9, 2);  // 9
```

### Обёртка для функций с переменным числом аргументов

Чтобы вызвать такую функцию из Gleam, оборачиваем её в функцию которая будет принимать `List`:

```javascript
// src/console_ffi.mjs
export function logMultiple(messages) {
  console.log(...messages);
}

export function mathMax(numbers) {
  if (numbers.length === 0) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: Math.max(...numbers) };
}
```

```gleam
import gleam/dynamic.{type Dynamic}

@external(javascript, "./console_ffi.mjs", "logMultiple")
pub fn log_multiple(messages: List(Dynamic)) -> Nil

@external(javascript, "./console_ffi.mjs", "mathMax")
pub fn math_max(numbers: List(Float)) -> Result(Float, Nil)

// Использование
pub fn example() {
  log_multiple([
    dynamic.from("User:"),
    dynamic.from("Alice"),
    dynamic.from(30),
  ])
  // Console: User: Alice 30

  math_max([1.5, 9.2, 3.7, 5.1])
  // Ok(9.2)

  math_max([])
  // Error(Nil)
}
```

Паттерн прост: JavaScript-функция принимает массив и разворачивает его через spread operator (`...messages`). Со стороны Gleam это обычная функция, принимающая `List`. Для разнотипных аргументов используем `List(Dynamic)`, для однотипных — `List(Int)`, `List(String)` и т.д.

## Работа с JavaScript классами и инстансами

JavaScript активно использует классы и объектно-ориентированный подход. При обёртке таких API в Gleam мы используем **внешние типы** для представления инстансов и **FFI-функции** для конструкторов и методов.

### Пример: встроенный класс Date

```javascript
// src/date_ffi.mjs
export function newDate() {
  return new Date();
}

export function newDateFromTimestamp(timestamp) {
  return new Date(timestamp);
}

export function getTime(date) {
  return date.getTime();
}

export function toISOString(date) {
  return date.toISOString();
}

export function setFullYear(date, year) {
  date.setFullYear(year);
  return date;  // Возвращаем для chain-ability
}
```

```gleam
// Внешний тип для инстансов Date
pub type JSDate

// Конструкторы (функции, вызывающие new)
@external(javascript, "./date_ffi.mjs", "newDate")
pub fn new_date() -> JSDate

@external(javascript, "./date_ffi.mjs", "newDateFromTimestamp")
pub fn new_date_from_timestamp(timestamp: Int) -> JSDate

// Методы инстанса
@external(javascript, "./date_ffi.mjs", "getTime")
pub fn get_time(date: JSDate) -> Int

@external(javascript, "./date_ffi.mjs", "toISOString")
pub fn to_iso_string(date: JSDate) -> String

@external(javascript, "./date_ffi.mjs", "setFullYear")
pub fn set_full_year(date: JSDate, year: Int) -> JSDate

// Использование
pub fn example() {
  let now = new_date()
  let timestamp = get_time(now)
  let iso = to_iso_string(now)

  let new_year = new_date()
    |> set_full_year(2030)
    |> to_iso_string()
}
```

Паттерн для классов:
1. **Внешний тип** (`JSDate`) представляет инстанс класса — Gleam не знает его внутреннюю структуру
2. **Конструкторы** (`new_date`) вызывают `new ClassName()` и возвращают инстанс
3. **Методы** (`get_time`, `set_full_year`) принимают инстанс первым параметром — это эквивалент `this` в JavaScript

### Пример: Map с мутациями

```javascript
// src/js_map_ffi.mjs
export function newMap() {
  return new Map();
}

export function mapSet(map, key, value) {
  map.set(key, value);
  return map;  // Для chain-ability
}

export function mapGet(map, key) {
  if (map.has(key)) {
    return { type: "Ok", 0: map.get(key) };
  }
  return { type: "Error", 0: undefined };
}

export function mapSize(map) {
  return map.size;
}

export function mapClear(map) {
  map.clear();
}
```

```gleam
pub type JSMap(k, v)

@external(javascript, "./js_map_ffi.mjs", "newMap")
pub fn new_map() -> JSMap(k, v)

@external(javascript, "./js_map_ffi.mjs", "mapSet")
pub fn map_set(map: JSMap(k, v), key: k, value: v) -> JSMap(k, v)

@external(javascript, "./js_map_ffi.mjs", "mapGet")
pub fn map_get(map: JSMap(k, v), key: k) -> Result(v, Nil)

@external(javascript, "./js_map_ffi.mjs", "mapSize")
pub fn map_size(map: JSMap(k, v)) -> Int

@external(javascript, "./js_map_ffi.mjs", "mapClear")
pub fn map_clear(map: JSMap(k, v)) -> Nil

// Использование
pub fn cache_example() {
  let cache = new_map()
    |> map_set("user:1", "Alice")
    |> map_set("user:2", "Bob")

  case map_get(cache, "user:1") {
    Ok(name) -> io.println(name)
    Error(_) -> io.println("Not found")
  }

  let size = map_size(cache)  // 2
  map_clear(cache)
}
```

**Важно:** JavaScript методы часто мутируют объект. Мы возвращаем инстанс из FFI-функций, чтобы поддерживать pipe operator (`|>`), но помните, что изменения происходят in-place.

### Пример: пользовательский класс Canvas

```javascript
// src/canvas_ffi.mjs
export class CanvasRenderer {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    this.ctx = this.canvas.getContext('2d');
  }

  drawRect(x, y, width, height, color) {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(x, y, width, height);
  }

  clear() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }

  setLineWidth(width) {
    this.ctx.lineWidth = width;
    return this;
  }
}

// Обёртки для Gleam
export function newCanvasRenderer(canvasId) {
  return new CanvasRenderer(canvasId);
}

export function drawRect(renderer, x, y, width, height, color) {
  renderer.drawRect(x, y, width, height, color);
}

export function clearCanvas(renderer) {
  renderer.clear();
}

export function setLineWidth(renderer, width) {
  return renderer.setLineWidth(width);
}
```

```gleam
pub type CanvasRenderer

@external(javascript, "./canvas_ffi.mjs", "newCanvasRenderer")
pub fn new_canvas_renderer(canvas_id: String) -> CanvasRenderer

@external(javascript, "./canvas_ffi.mjs", "drawRect")
pub fn draw_rect(
  renderer: CanvasRenderer,
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  color: String,
) -> Nil

@external(javascript, "./canvas_ffi.mjs", "clearCanvas")
pub fn clear_canvas(renderer: CanvasRenderer) -> Nil

@external(javascript, "./canvas_ffi.mjs", "setLineWidth")
pub fn set_line_width(renderer: CanvasRenderer, width: Float) -> CanvasRenderer

// Использование
pub fn draw() {
  let canvas = new_canvas_renderer("my-canvas")

  clear_canvas(canvas)

  canvas
  |> set_line_width(5.0)
  |> draw_rect(10.0, 10.0, 100.0, 50.0, "red")
  |> draw_rect(150.0, 10.0, 100.0, 50.0, "blue")
}
```

Этот пример показывает обёртку для пользовательского класса: JavaScript-класс `CanvasRenderer` инкапсулирует состояние (canvas context). Мы создаём обёртки-функции, которые принимают инстанс и вызывают методы. Gleam-код полностью типобезопасен и использует привычный functional стиль, скрывая императивный JS-код.

## gleam_javascript — привязки к JavaScript

Библиотека `gleam_javascript` предоставляет типизированные обёртки над JavaScript API.

### gleam/javascript/promise

Промисы — основа асинхронности в JavaScript:

```gleam
import gleam/javascript/promise

// Создание промиса
promise.new(fn(resolve, _reject) {
  resolve(42)
})
// Promise(Int)

// Трансформация результата
promise.new(fn(resolve, _reject) { resolve(42) })
|> promise.map(fn(x) { x * 2 })
// Promise(Int) — 84

// Цепочка промисов
promise.new(fn(resolve, _reject) { resolve("https://api.example.com") })
|> promise.then(fn(url) {
  // Возвращаем новый промис
  fetch(url)
})
// Promise(Response)

// Обработка ошибок
promise.new(fn(_resolve, reject) { reject("oops") })
|> promise.rescue(fn(error) {
  io.println("Error: " <> error)
  promise.resolve(0)  // Fallback значение
})
```

Gleam предоставляет типобезопасный API для работы с промисами: `promise.new` создаёт промис с resolve/reject callback'ами, `promise.map` трансформирует результат (аналог `.then()` в JS), `promise.then` позволяет вернуть новый промис (для цепочек), `promise.rescue` обрабатывает ошибки. Все функции сохраняют типы — компилятор знает, что `Promise(Int)` в итоге вернёт `Int`.

### Пример: fetch API

```javascript
// src/http_ffi.mjs
export function fetch(url) {
  return globalThis.fetch(url)
    .then(response => response.text())
    .then(text => ({ type: "Ok", 0: text }))
    .catch(error => ({ type: "Error", 0: error.message }));
}
```

```gleam
import gleam/javascript/promise

@external(javascript, "./http_ffi.mjs", "fetch")
pub fn fetch(url: String) -> promise.Promise(Result(String, String))

// Использование
fetch("https://pokeapi.co/api/v2/pokemon/pikachu")
|> promise.map(fn(result) {
  case result {
    Ok(body) -> io.println("Got: " <> body)
    Error(err) -> io.println("Error: " <> err)
  }
})
```

FFI-функция `fetch` оборачивает нативный `fetch()` и конвертирует JavaScript Promise в Gleam `promise.Promise`. Внутри промиса мы получаем текст через `.text()`, затем оборачиваем результат в `Result` — ошибки сети перехватываются `.catch()` и становятся `Error(String)`. Gleam-код использует `promise.map` для работы с асинхронным результатом.

### gleam/javascript/array

JavaScript массивы — mutable, в отличие от immutable Gleam `List`:

```gleam
import gleam/javascript/array

// Создание
let arr = array.from_list([1, 2, 3])

// Доступ
array.get(arr, 0)  // Ok(1)
array.get(arr, 10) // Error(Nil)

// Длина
array.length(arr)  // 3

// Конвертация обратно в List
array.to_list(arr)  // [1, 2, 3]
```

**Важно:** `array.from_list` создаёт копию, а не ссылку — изменения в массиве не влияют на исходный список.

### gleam/javascript/map

JavaScript объекты как словари:

```gleam
import gleam/javascript/map

// Создание
let m = map.new()
  |> map.set("name", "Alice")
  |> map.set("age", "30")

// Чтение
map.get(m, "name")  // Ok("Alice")
map.get(m, "city")  // Error(Nil)

// Размер
map.size(m)  // 2
```

JavaScript Map (не путать с `gleam/dict`) — mutable структура для хранения пар ключ-значение. В отличие от Gleam словарей, изменения в `javascript/map` мутируют исходный объект. `map.new()` создаёт новый Map, `map.set` добавляет пару, `map.get` возвращает `Result` — `Error(Nil)` если ключа нет.

## Модель конкурентности: BEAM vs JavaScript

### BEAM: процессы и акторы

- **Легковесные процессы** — миллионы одновременных процессов
- **Изолированная память** — каждый процесс имеет свою память
- **Передача сообщений** — копирование данных между процессами
- **Преемптивная многозадачность** — планировщик честно распределяет CPU

```gleam
// BEAM: параллельные процессы
import gleam/erlang/process

let pid1 = process.start(fn() { heavy_computation_1() }, True)
let pid2 = process.start(fn() { heavy_computation_2() }, True)
// Оба вычисления идут параллельно на разных ядрах
```

На BEAM каждый `process.start` создаёт настоящий легковесный процесс с собственным планировщиком. Два процесса выполняются **одновременно** на разных CPU-ядрах — это истинный параллелизм. Процессы изолированы: каждый имеет свою память, взаимодействие только через передачу сообщений.

### JavaScript: event loop и промисы

- **Однопоточность** — один поток выполнения
- **Event loop** — очередь задач
- **Async/await** — синтаксический сахар над промисами
- **Не блокирующий I/O** — операции вывода не блокируют поток

```javascript
// JavaScript: concurrency через промисы
const result1 = fetch("https://api.example.com/1");
const result2 = fetch("https://api.example.com/2");

Promise.all([result1, result2]).then(([r1, r2]) => {
  // Оба запроса выполнялись "параллельно" (но не на разных ядрах)
});
```

В JavaScript есть только один поток выполнения. `Promise.all` запускает оба `fetch` **конкурентно**: event loop переключается между ними, пока ждёт I/O операций. Но тяжёлые вычисления заблокируют весь поток — нельзя использовать несколько CPU-ядер без Web Workers. Это конкурентность (concurrency), а не параллелизм (parallelism).

### Ключевые различия

| BEAM | JavaScript |
| ------ | ----------- |
| Истинный параллелизм (multicore) | Конкурентность (event loop) |
| Процессы изолированы | Общее состояние (shared memory) |
| Передача сообщений | Callbacks/Promises |
| Fault tolerance (let it crash) | Error handling (try/catch) |

**Вывод:** на BEAM можно использовать все ядра CPU для параллельных вычислений. В JavaScript "параллелизм" — это иллюзия: event loop переключается между задачами, но в каждый момент выполняется только одна.

## Типобезопасный DOM API

### Пример: работа с элементами

```javascript
// src/dom_ffi.mjs
export function getElementById(id) {
  const element = document.getElementById(id);
  if (element === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: element };
}

export function setInnerText(element, text) {
  element.innerText = text;
}

export function addEventListener(element, event, handler) {
  element.addEventListener(event, handler);
}
```

```gleam
pub type Element

@external(javascript, "./dom_ffi.mjs", "getElementById")
pub fn get_element_by_id(id: String) -> Result(Element, Nil)

@external(javascript, "./dom_ffi.mjs", "setInnerText")
pub fn set_inner_text(element: Element, text: String) -> Nil

@external(javascript, "./dom_ffi.mjs", "addEventListener")
pub fn add_event_listener(
  element: Element,
  event: String,
  handler: fn() -> Nil,
) -> Nil
```

Внешний тип `Element` скрывает реализацию DOM-элемента — в Gleam это просто непрозрачный тип. `get_element_by_id` возвращает `Result`: если элемент не найден (`null` в JS), получаем `Error(Nil)`. Функции `set_inner_text` и `add_event_listener` принимают `Element` и безопасно вызывают соответствующие DOM API.

### Пример использования

```gleam
pub fn main() {
  case get_element_by_id("app") {
    Ok(element) -> {
      set_inner_text(element, "Hello from Gleam!")
      add_event_listener(element, "click", fn() {
        set_inner_text(element, "Clicked!")
      })
    }
    Error(_) -> io.println("Element not found")
  }
}
```

Типичный паттерн работы с DOM: получаем элемент через `get_element_by_id`, обрабатываем случай отсутствия элемента через pattern matching на `Result`, затем безопасно работаем с гарантированно существующим элементом. Обработчик события — обычная Gleam-функция, которая компилируется в JavaScript callback.

## Интеграция с JavaScript-библиотеками

### Пример: wrapper для date-fns

```javascript
// src/datefns_ffi.mjs
import { format, addDays } from 'date-fns';

export function formatDate(date, pattern) {
  return format(date, pattern);
}

export function addDaysToDate(date, days) {
  return addDays(date, days);
}

export function now() {
  return new Date();
}
```

```gleam
pub type JSDate

@external(javascript, "./datefns_ffi.mjs", "now")
pub fn now() -> JSDate

@external(javascript, "./datefns_ffi.mjs", "formatDate")
pub fn format_date(date: JSDate, pattern: String) -> String

@external(javascript, "./datefns_ffi.mjs", "addDaysToDate")
pub fn add_days(date: JSDate, days: Int) -> JSDate

// Использование
pub fn example() {
  let today = now()
  let tomorrow = add_days(today, 1)
  format_date(tomorrow, "yyyy-MM-dd")
  // "2026-02-21"
}
```

Этот пример показывает интеграцию с npm-пакетами: FFI-файл импортирует `date-fns`, экспортирует обёртки над его функциями. Со стороны Gleam мы работаем с типобезопасным API: `JSDate` — внешний тип (JavaScript `Date` объект), функции принимают и возвращают Gleam-типы. Компилятор гарантирует, что мы не передадим строку вместо даты.

## Упражнения

Решения пишите в файле `exercises/chapter09/test/my_solutions.gleam`. Запускайте тесты:

```sh
cd exercises/chapter09
gleam test --target javascript
```

### 1. current_timestamp — Date.now() (Лёгкое)

Реализуйте функцию, возвращающую текущее время в миллисекундах:

```gleam
pub fn current_timestamp() -> Int
```

**Подсказка:** создайте `my_ffi.mjs` с функцией, вызывающей `Date.now()`.

### 2. local_storage — get/set (Среднее)

Реализуйте типобезопасный интерфейс для localStorage:

```gleam
pub fn storage_get(key: String) -> Result(String, Nil)
pub fn storage_set(key: String, value: String) -> Result(Nil, String)
pub fn storage_remove(key: String) -> Nil
```

**Подсказка:** обработайте случай `localStorage.getItem(key) === null` как `Error(Nil)`.

### 3. console_log_levels — разные уровни логов (Среднее)

Реализуйте функции для разных уровней логирования:

```gleam
pub fn console_log(message: String) -> Nil
pub fn console_warn(message: String) -> Nil
pub fn console_error(message: String) -> Nil
```

**Подсказка:** `console.log()`, `console.warn()`, `console.error()`.

### 4. timeout — setTimeout wrapper (Среднее)

Реализуйте типобезопасную обёртку для setTimeout:

```gleam
pub type TimeoutId

pub fn set_timeout(callback: fn() -> Nil, delay: Int) -> TimeoutId
pub fn clear_timeout(id: TimeoutId) -> Nil
```

**Подсказка:** в JavaScript `setTimeout` возвращает число (id таймера).

### 5. fetch_json — HTTP запрос с парсингом (Среднее-Сложное)

Реализуйте функцию для HTTP-запросов, возвращающую промис:

```gleam
pub fn fetch_json(url: String) -> promise.Promise(Result(String, String))
```

**Подсказка:** используйте `fetch()`, затем `.text()`, оберните в `Promise.resolve({type: "Ok", 0: text})`.

### 6. query_selector — типобезопасный поиск элементов (Сложное)

Реализуйте функцию поиска элемента по CSS-селектору:

```gleam
pub type Element

pub fn query_selector(selector: String) -> Result(Element, Nil)
pub fn query_selector_all(selector: String) -> List(Element)
```

**Подсказка:** `document.querySelector` возвращает `null` если не найдено. Для `querySelectorAll` преобразуйте `NodeList` в массив через `Array.from()`, затем в Gleam List.

### 7. json_parse_safe — безопасный JSON.parse (Сложное)

Реализуйте безопасную обёртку для `JSON.parse`:

```gleam
pub fn json_parse(json_str: String) -> Result(dynamic.Dynamic, String)
```

**Подсказка:** оберните `JSON.parse` в `try/catch`, верните `{type: "Ok", 0: parsed}` или `{type: "Error", 0: error.message}`.

### 8. event_target_value — получение значения из event.target (Сложное)

Реализуйте функцию извлечения значения из события input:

```gleam
pub type Event

pub fn event_target_value(event: Event) -> Result(String, Nil)
```

**Подсказка:** проверьте `event.target?.value`, верните `Error` если `undefined`.

### 9. varargs_logger — console.log с разными типами (Среднее-Сложное)

Реализуйте функцию для логирования множества значений разных типов:

```gleam
pub fn log_values(values: List(Dynamic)) -> Nil
```

**Подсказка:** создайте JavaScript функцию, принимающую массив и использующую spread operator: `console.log(...values)`.

### 10. math_operations — varargs для математики (Среднее)

Реализуйте функции с переменным числом аргументов:

```gleam
pub fn sum_all(numbers: List(Float)) -> Float
pub fn multiply_all(numbers: List(Float)) -> Float
```

**Подсказка:** в JavaScript используйте `reduce()`:
```javascript
export function sumAll(numbers) {
  return numbers.reduce((a, b) => a + b, 0);
}
```

### 11. js_date_wrapper — работа с Date классом (Сложное)

Реализуйте типобезопасную обёртку для JavaScript Date:

```gleam
pub type JSDate

pub fn new_date() -> JSDate
pub fn date_from_string(iso: String) -> Result(JSDate, Nil)
pub fn add_days(date: JSDate, days: Int) -> JSDate
pub fn format_date(date: JSDate, format: String) -> String
```

**Подсказка:**
- `new Date()` для создания
- `new Date(isoString)` для парсинга (может вернуть `Invalid Date`)
- Для `add_days`: `date.setDate(date.getDate() + days)`
- Для `format_date` используйте `toLocaleDateString()` или библиотеку date-fns

### 12. canvas_wrapper — обёртка для Canvas API (Сложное)

Реализуйте минимальную обёртку для HTML Canvas:

```gleam
pub type Canvas

pub fn get_canvas(element_id: String) -> Result(Canvas, Nil)
pub fn fill_rect(canvas: Canvas, x: Float, y: Float, w: Float, h: Float, color: String) -> Canvas
pub fn clear(canvas: Canvas) -> Canvas
```

**Подсказка:**
- `document.getElementById(id)?.getContext('2d')` для получения контекста
- Храните context как инстанс
- Методы `.fillRect()`, `.clearRect()` для рисования

## Сравнение FFI-подходов: Gleam vs другие языки

Разные языки, компилирующиеся в JavaScript, используют различные подходы к FFI. Вот сравнение основных конкурентов.

### TypeScript — Декларации типов + экосистема

**Подход:** TypeScript — это надстройка над JavaScript. Типы объявляются через `.d.ts` файлы (type declarations), но благодаря проекту **DefinitelyTyped** большинство популярных библиотек уже имеют готовые типы в `@types/*`.

```typescript
// TypeScript — прямой доступ к JS API (типы встроены)
const now = Date.now();  // number
localStorage.setItem("key", "value");
console.log("Hello", 123, true);  // varargs работают нативно

// Типы для сторонних библиотек — устанавливаются из npm
import { format } from 'date-fns';
// npm install @types/date-fns  ← типы из DefinitelyTyped
const formatted: string = format(new Date(), 'yyyy-MM-dd');

// Для библиотеки без готовых типов нужно писать .d.ts вручную
declare module 'my-obscure-lib' {
  export function doSomething(x: number): string;
}
```

**Преимущества:**
- ✅ Нулевой runtime оверхед — типы удаляются при компиляции
- ✅ **Огромная экосистема** — @types/* покрывает ~90% популярных библиотек
- ✅ Нет FFI-слоя — пишете JS с проверкой типов
- ✅ Постепенная миграция — можно добавлять типы инкрементально

**Недостатки:**
- ❌ **Слабая типизация** — `any`, `unknown`, type assertions (`as`) обходят проверки
- ❌ **Runtime ошибки возможны** — `null`/`undefined`, неправильные типы в .d.ts
- ❌ **Доверие типам** — `.d.ts` могут быть неточными или устаревшими
- ❌ Нет паттерн-матчинга и ADT (algebraic data types)

**Бойлерплейт:**
- ⭐ **Для популярных библиотек:** минимальный (`npm install @types/library`)
- ⚠️ **Для редких библиотек:** нужно писать `.d.ts` вручную (аналогично FFI в Gleam)
- ❌ **Для legacy JS-кода:** может потребоваться много деклараций

---

### Elm — Порты (изоляция)

**Подход:** Elm полностью изолирован от JavaScript. Взаимодействие только через **порты** (ports) — асинхронные каналы сообщений.

```elm
-- Elm: декларация порта (отправка в JS)
port sendToJS : String -> Cmd msg

-- Elm: подписка на порт (получение из JS)
port receiveFromJS : (String -> msg) -> Sub msg

-- Использование
sendToJS "hello from Elm"
```

```javascript
// JavaScript: подключение портов
const app = Elm.Main.init();

app.ports.sendToJS.subscribe(function(data) {
  console.log("Got from Elm:", data);
  // Вызов JS API
  localStorage.setItem("key", data);
  // Отправка обратно
  app.ports.receiveFromJS.send("saved!");
});
```

**Преимущества:**
- ✅ Абсолютная безопасность — Elm-код никогда не упадёт из-за JS
- ✅ Чистота — все побочные эффекты явно описаны
- ✅ No runtime exceptions в Elm-коде

**Недостатки:**
- ❌ **Огромный бойлерплейт** — каждый вызов JS требует порт + подписку + JSON-сериализацию
- ❌ Асинхронность — невозможен синхронный вызов JS-функции
- ❌ JSON-граница — можно передавать только сериализуемые данные
- ❌ Нельзя использовать JS-библиотеки напрямую

**Бойлерплейт:** Очень высокий. Простой `Date.now()` требует минимум 10 строк кода.

---

### ReScript — Прямой FFI (как Gleam)

**Подход:** ReScript (бывший BuckleScript) — функциональный язык с JS-подобным синтаксисом и прямым FFI через `@module` и `@val`.

```rescript
// ReScript: FFI к JavaScript
@val external dateNow: unit => float = "Date.now"
@scope("console") @val external log: string => unit = "log"

// Использование
let now = dateNow()
log("Hello")

// Внешние модули
@module("date-fns") external format: (Js.Date.t, string) => string = "format"
let formatted = format(Js.Date.make(), "yyyy-MM-dd")
```

**Преимущества:**
- ✅ **Простой синтаксис** — близок к JavaScript, легко освоить
- ✅ Прямой доступ к JS API (как Gleam)
- ✅ Минимальный бойлерплейт для FFI
- ✅ Отличный вывод типов
- ✅ Генерирует **очень читаемый** JS-код (почти как рукописный)

**Недостатки:**
- ⚠️ Нужно вручную объявлять типы для каждой JS-функции
- ⚠️ Доверие компилятору — ошибки в типах FFI не отловятся
- ❌ Маленькая экосистема готовых биндингов (в отличие от @types/*)

**Бойлерплейт:** Средний — каждая JS-функция требует `external` декларацию, но это одна строка.

---

### PureScript — Внешние декларации (как Haskell)

**Подход:** PureScript — Haskell для JavaScript. FFI через `foreign import`.

```purescript
-- PureScript: декларация FFI
foreign import dateNow :: Effect Number
foreign import consoleLog :: String -> Effect Unit

-- Использование
main = do
  now <- dateNow
  consoleLog "Hello"
```

```javascript
// ffi.js: реализация
export const dateNow = () => Date.now();
export const consoleLog = (msg) => console.log(msg);
```

**Преимущества:**
- ✅ Сильная типизация (как Haskell)
- ✅ Effect-система — все побочные эффекты явны
- ✅ Мощная система типов (type classes, higher-kinded types)

**Недостатки:**
- ❌ **Высокий порог входа** — монады, do-нотация, Effect
- ❌ Сгенерированный JS код сложный и большой
- ❌ Бойлерплейт для каждой JS-функции (`.purs` + `.js`)

**Бойлерплейт:** Высокий — нужны отдельные файлы `.purs` и `.js`, плюс понимание Effect-монад.

---

### Gleam — Баланс простоты и безопасности

**Подход:** Gleam использует `@external` с отдельными `.mjs` файлами. Подход похож на ReScript, но проще.

```gleam
// Gleam: декларация FFI
@external(javascript, "./ffi.mjs", "dateNow")
pub fn date_now() -> Int

@external(javascript, "./ffi.mjs", "consoleLog")
pub fn console_log(msg: String) -> Nil
```

```javascript
// ffi.mjs: реализация
export function dateNow() {
  return Date.now();
}

export function consoleLog(msg) {
  console.log(msg);
}
```

**Преимущества:**
- ✅ **Простота** — проще, чем PureScript и Elm
- ✅ **Прямой доступ** — как TypeScript/ReScript, но с типами
- ✅ **Минимальный бойлерплейт** — одна строка `@external` + одна JS-функция
- ✅ **Читаемый синтаксис** — легче Haskell/OCaml
- ✅ **Двойной FFI** — один код для Erlang и JavaScript

**Недостатки:**
- ⚠️ Доверие типам — компилятор не проверяет соответствие FFI-сигнатур
- ⚠️ Нет effect-системы — `Nil` не отличает чистую функцию от побочного эффекта
- ❌ Небольшая экосистема (по сравнению с TypeScript)

**Бойлерплейт:** Низкий — одна строка Gleam + одна функция JS.

---

### Сравнительная таблица

| Язык | Подход | Бойлерплейт FFI | Безопасность типов | Порог входа | Готовые типы |
|------|--------|-----------------|-------------------|-------------|--------------|
| **TypeScript** | Декларации (.d.ts) | ⭐ Минимум* | ⚠️ Слабая | ⭐ Самый низкий | ⭐⭐⭐ @types/* |
| **ReScript** | @module/@val | ⭐⭐ Средний | ⭐⭐ Хорошая | ⭐ Низкий | ⚠️ Мало |
| **Gleam** | @external + .mjs | ⭐⭐ Низкий | ⭐⭐ Хорошая | ⭐ Низкий | ⚠️ Растущая |
| **Elm** | Порты | ❌ Очень высокий | ⭐⭐⭐ Абсолютная | ⚠️ Средний | ❌ Изолирован |
| **PureScript** | Foreign import | ❌ Высокий | ⭐⭐⭐ Сильная | ❌ Высокий | ⚠️ Небольшая |

**\* TypeScript:** Для популярных библиотек — минимум (`npm i @types/lib`), для редких — нужно писать `.d.ts` вручную.

**Порог входа:** TypeScript ≈ ReScript ≈ Gleam < Elm << PureScript

### Вывод

**Выбирайте язык в зависимости от приоритетов:**

- **Нужна максимальная экосистема и быстрый старт?** → **TypeScript**
  - ✅ Готовые типы для 90% библиотек (@types/*)
  - ✅ Низкий порог входа, знакомый синтаксис
  - ❌ Но слабые гарантии (any, null/undefined, type assertions)

- **Хотите производительность и простоту?** → **ReScript**
  - ✅ Простой JS-подобный синтаксис, легко освоить
  - ✅ Прямой FFI + отличный вывод типов
  - ✅ Генерирует очень чистый JS-код
  - ❌ Но маленькая экосистема готовых биндингов

- **Нужна простота + типобезопасность + full-stack (Erlang + JS)?** → **Gleam**
  - ✅ Простой синтаксис, сильная типизация, двойной таргет
  - ✅ Один язык для бэкенда и фронтенда
  - ❌ Но придётся писать FFI-обёртки для большинства библиотек

- **Нужна абсолютная безопасность ценой удобства?** → **Elm**
  - ✅ No runtime exceptions в принципе
  - ✅ Time-travel debugging, отличные сообщения об ошибках
  - ❌ Но очень много бойлерплейта для любого JS-взаимодействия
  - ❌ Изоляция от экосистемы JS

- **Готовы к Haskell-уровню сложности?** → **PureScript**
  - ✅ Самая мощная система типов (type classes, higher-kinded types)
  - ✅ Эффект-система для управления побочными эффектами
  - ❌ Но крутая кривая обучения (монады, do-notation, Effect)
  - ❌ Сложный сгенерированный код

**Спектр сложности:**

```
Простые                                      Сложные
TypeScript ≈ ReScript ≈ Gleam  <  Elm  <<  PureScript
```

**Компромиссы:**

- **TypeScript/ReScript:** Минимум усилий для FFI, но слабее гарантии
- **Gleam:** Золотая середина — простой синтаксис + сильные типы + full-stack
- **Elm/PureScript:** Максимальные гарантии, но высокая церемониальность

Gleam особенно привлекателен, если вы хотите **один язык для бэкенда (BEAM) и фронтенда (JavaScript)** с сильной типизацией и без академической сложности.

## Заключение

В этой главе мы изучили взаимодействие Gleam с JavaScript:

- **External functions** — вызов JavaScript из Gleam через `.mjs` файлы
- **Двойной FFI** — универсальный код для Erlang и JavaScript
- **gleam_javascript** — промисы, массивы, объекты
- **Varargs (rest parameters)** — функции с переменным числом аргументов
- **Классы и инстансы** — обёртки для JavaScript-классов (Date, Map, Canvas)
- **Модель конкурентности** — различия между BEAM processes и JS event loop
- **DOM API** — типобезопасная работа с браузером
- **Интеграция с JS-библиотеками** — обёртки для сторонних пакетов

JavaScript-таргет позволяет использовать Gleam для фронтенд-разработки — от простых скриптов до полноценных SPA. При этом сохраняются все преимущества типобезопасности и паттерн-матчинга.

> **Что дальше:** В главе 13 мы изучим **Lustre** — фреймворк для построения UI на Gleam. Lustre абстрагирует низкоуровневую работу с DOM (которую мы изучили в этой главе) и предоставляет декларативный API в стиле The Elm Architecture. Знания из этой главы пригодятся для интеграции сторонних JavaScript-библиотек (date-fns, chart.js) в Lustre-приложения.

В следующей главе мы переключимся обратно на Erlang-таргет и построим веб-приложение с базой данных используя Wisp и PostgreSQL.
