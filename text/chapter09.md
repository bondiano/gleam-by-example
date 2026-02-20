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

## Заключение

В этой главе мы изучили взаимодействие Gleam с JavaScript:

- **External functions** — вызов JavaScript из Gleam через `.mjs` файлы
- **Двойной FFI** — универсальный код для Erlang и JavaScript
- **gleam_javascript** — промисы, массивы, объекты
- **Модель конкурентности** — различия между BEAM processes и JS event loop
- **DOM API** — типобезопасная работа с браузером
- **Интеграция с JS-библиотеками** — обёртки для сторонних пакетов

JavaScript-таргет позволяет использовать Gleam для фронтенд-разработки — от простых скриптов до полноценных SPA. При этом сохраняются все преимущества типобезопасности и паттерн-матчинга.

В следующей главе мы объединим знания обоих таргетов и построим full-stack приложение: Gleam на сервере (BEAM) и Gleam в браузере (JavaScript).
