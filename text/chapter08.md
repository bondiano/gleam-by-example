# Erlang FFI и системное программирование

> «Talk is cheap. Show me the code.» — Linus Torvalds

<!-- toc -->

## Цели главы

В этой главе мы:

- Научимся вызывать Erlang функции через `@external`
- Изучим внешние типы (external types)
- Познакомимся с привязками из `gleam_erlang`
- Поймём как работать с атомами, переменными окружения и charlist
- Создадим утилиты для системного программирования
- Напишем обёртки над Erlang-функциями для работы с файлами и процессами

## External functions для Erlang

Gleam компилируется в Erlang и работает на BEAM VM. Атрибут `@external` позволяет вызывать любую функцию из Erlang напрямую:

```gleam
// Вызов erlang:system_time/1
@external(erlang, "erlang", "system_time")
fn erl_system_time(unit: atom) -> Int

// Можно также объявить как pub
@external(erlang, "os", "system_time")
pub fn os_system_time(unit: atom) -> Int
```

Атрибут `@external` связывает Gleam-функцию с Erlang-функцией: первый параметр — таргет (`erlang`), второй — имя модуля Erlang (`"erlang"`, `"os"`), третий — имя функции. Типы аргументов и возвращаемого значения объявляются в Gleam — компилятор доверяет вам, что сигнатура корректна.

### Двойная проверка типов

Важно понимать: компилятор Gleam **не проверяет**, что Erlang-функция действительно имеет указанную сигнатуру. Это означает:

```gleam
// ❌ Компилятор не обнаружит ошибку!
@external(erlang, "erlang", "system_time")
fn wrong_signature(x: String) -> String  // Неправильные типы
```

Такой код скомпилируется, но упадёт в рантайме. **Всегда проверяйте документацию Erlang** перед написанием FFI-обёрток.

### Функции с Gleam-реализацией + FFI fallback

Можно объявить функцию с телом на Gleam и FFI-альтернативой. Если FFI доступен для текущего таргета, он используется; иначе — Gleam-реализация:

```gleam
@external(erlang, "my_ffi", "fast_sort")
pub fn sort(xs: List(Int)) -> List(Int) {
  // Gleam-реализация как fallback
  list.sort(xs, int.compare)
}
```

Такой подход позволяет использовать оптимизированную нативную реализацию там, где она доступна, и автоматически откатываться к Gleam-коду на других платформах.

## External types

Внешние типы — типы, определённые вне Gleam. Их нельзя создать или разобрать напрямую в Gleam:

```gleam
// Тип Atom из Erlang — существует только на BEAM
pub type Atom

// Regex — внутренняя структура зависит от таргета
pub type Regex
```

Внешние типы объявляются без конструкторов — они непрозрачны для Gleam-кода. `Atom` существует только на BEAM, `Regex` может иметь разную реализацию в зависимости от таргета. Для работы с внешними типами используются FFI-функции: конструкторы, аксессоры, преобразователи.

### Пример: работа с Erlang reference

```gleam
// Reference — уникальный идентификатор в Erlang
pub type Reference

@external(erlang, "erlang", "make_ref")
pub fn make_reference() -> Reference

@external(erlang, "erlang", "ref_to_list")
fn reference_to_charlist(ref: Reference) -> Charlist
```

External type `Reference` скрывает внутреннее представление — мы можем только создавать и преобразовывать значения через FFI.

## gleam_erlang — привязки к Erlang

Библиотека `gleam_erlang` предоставляет типизированные обёртки над Erlang API.

### gleam/erlang/atom

Атомы — уникальные идентификаторы в Erlang. Они похожи на enum-значения, но создаются динамически:

```gleam
import gleam/erlang/atom

// Создание атома из строки
let assert Ok(a) = atom.from_string("hello")

// Обратно в строку
atom.to_string(a)  // "hello"

// Атомы интернированы — одинаковые строки дают один атом
let assert Ok(a1) = atom.from_string("ok")
let assert Ok(a2) = atom.from_string("ok")
// a1 == a2
```

Атомы в Erlang — это интернированные константы, похожие на символы в Ruby или enumы в других языках. `atom.from_string` преобразует строку в атом (может вернуть `Error`, если атом слишком длинный). Важное свойство: одинаковые строки всегда дают один и тот же атом в памяти, поэтому сравнение атомов — это просто сравнение указателей.

> **Внимание:** не создавайте атомы из пользовательского ввода! Таблица атомов в BEAM имеет ограниченный размер и не очищается сборщиком мусора.

### Безопасное использование атомов

Лучшая практика — создавать атомы только из известных заранее строк:

```gleam
// ✓ Хорошо: фиксированный набор атомов
pub type LogLevel {
  Debug
  Info
  Warning
  Error
}

pub fn log_level_to_atom(level: LogLevel) -> atom.Atom {
  let assert Ok(a) = case level {
    Debug -> atom.from_string("debug")
    Info -> atom.from_string("info")
    Warning -> atom.from_string("warning")
    Error -> atom.from_string("error")
  }
  a
}

// ❌ Плохо: атомы из пользовательского ввода
pub fn dangerous(user_input: String) -> atom.Atom {
  let assert Ok(a) = atom.from_string(user_input)  // Утечка памяти!
  a
}
```

### Переменные окружения через FFI

В ранних версиях `gleam_erlang` был модуль `gleam/erlang/os`, но в текущей версии он удалён. Для работы с переменными окружения используем прямой FFI к Erlang. Создаём файл `src/my_ffi.erl`:

```erlang
-module(my_ffi).
-export([get_env/1]).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.
```

И используем из Gleam:

```gleam
@external(erlang, "my_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)

pub fn env_var_or_default(name: String, default: String) -> String {
  case get_env(name) {
    Ok(value) -> value
    Error(_) -> default
  }
}
```

Это отличный пример применения FFI — нужная функция из Erlang, но нет готовой обёртки. Мы пишем небольшой Erlang-модуль и подключаем через `@external`.

### gleam/erlang — общие утилиты

Модуль `gleam/erlang` предоставляет утилиты для взаимодействия с BEAM-рантаймом:

```gleam
import gleam/erlang

// rescue — перехват Erlang-исключений
erlang.rescue(fn() { panic as "oops" })
// Error(Errored(...))

// get_line — чтение строки из stdin
erlang.get_line("Введите имя: ")
// Ok("Алиса\n")

// priv_directory — путь к priv/ директории OTP-приложения
erlang.priv_directory("my_app")
// Ok("/path/to/my_app/priv")
```

Модуль `gleam/erlang` предоставляет утилиты для взаимодействия с BEAM-рантаймом: перехват исключений через `rescue`, чтение пользовательского ввода через `get_line` и доступ к ресурсам OTP-приложения через `priv_directory`.

### gleam/erlang/charlist

Charlist — строки Erlang (список целых чисел). Нужны для совместимости с Erlang API:

```gleam
import gleam/erlang/charlist

let cl = charlist.from_string("hello")
charlist.to_string(cl)  // "hello"
```

Charlist используется при вызове Erlang-функций, которые ожидают строки в виде списков символов — `charlist.from_string` и `charlist.to_string` обеспечивают конвертацию в обе стороны.

### Пример: чтение файла через Erlang file API

```gleam
import gleam/erlang/charlist

@external(erlang, "file", "read_file")
fn erl_read_file(path: Charlist) -> Result(BitArray, Atom)

pub fn read_file(path: String) -> Result(BitArray, String) {
  let charlist_path = charlist.from_string(path)

  case erl_read_file(charlist_path) {
    Ok(contents) -> Ok(contents)
    Error(reason) -> Error("failed to read: " <> atom.to_string(reason))
  }
}
```

Этот пример показывает типичный паттерн FFI-обёртки: Erlang-функция `file:read_file/1` принимает путь как `Charlist` и возвращает `Result(BitArray, Atom)`. Мы оборачиваем её в удобную Gleam-функцию: конвертируем `String` в `Charlist` на входе, и `Atom` в `String` при ошибке на выходе.

## Продвинутые техники FFI

### Представление Gleam-типов в Erlang

Gleam компилируется в Erlang, и пользовательские типы (custom types) представляются как кортежи. Это важно понимать при работе с FFI:

```gleam
// В Gleam:
type Result(a, e) {
  Ok(a)
  Error(e)
}

// В Erlang становится:
// Ok(value) → {ok, value}
// Error(reason) → {error, reason}
```

Это означает, что `Result` в Gleam **совместим** с Erlang-конвенцией `{ok, Value} | {error, Reason}`. Erlang-функции, возвращающие такие кортежи, можно типизировать как `Result`:

```gleam
// Erlang: file:consult/1 возвращает {ok, Terms} | {error, Reason}
@external(erlang, "file", "consult")
fn erl_consult(path: Charlist) -> Result(List(Dynamic), Atom)

pub fn read_erlang_terms(path: String) -> Result(List(Dynamic), String) {
  charlist.from_string(path)
  |> erl_consult
  |> result.map_error(atom.to_string)
}
```

Общее правило: конструкторы Gleam преобразуются в кортежи вида `{конструктор_строчными, поле1, поле2, ...}`:

```gleam
// В Gleam:
type Status {
  Idle
  Running(pid: Pid)
  Completed(result: Int, time: Int)
}

// В Erlang:
// Idle → {idle}
// Running(pid) → {running, Pid}
// Completed(42, 100) → {completed, 42, 100}
```

Это позволяет Gleam-коду естественно взаимодействовать с существующими Erlang-библиотеками.

### Вызов функций с переменным числом аргументов

Некоторые Erlang-функции принимают переменное число аргументов. Решение — создать обёртку в Erlang:

```erlang
% src/my_ffi.erl
-module(my_ffi).
-export([format_string/2]).

format_string(Format, Args) ->
    lists:flatten(io_lib:format(Format, Args)).
```

```gleam
@external(erlang, "my_ffi", "format_string")
pub fn format(template: String, args: List(Dynamic)) -> String

// Использование
import gleam/dynamic

format("Hello, ~s! You are ~p years old.", [
  dynamic.from("Alice"),
  dynamic.from(30),
])
// "Hello, Alice! You are 30 years old."
```

Этот паттерн решает проблему Erlang-функций с переменным числом аргументов: создаём промежуточный Erlang-модуль, который принимает список аргументов и передаёт их в `io_lib:format/2`. Со стороны Gleam это выглядит как обычная функция с фиксированной сигнатурой. `Dynamic` позволяет передавать значения разных типов в одном списке.

## Упражнения

Решения пишите в файле `exercises/chapter08/test/my_solutions.gleam`. Запускайте тесты:

```sh
cd exercises/chapter08
gleam test
```

### 1. system_time_seconds — FFI к erlang:system_time (Лёгкое)

Реализуйте функцию, возвращающую текущее время в секундах:

```gleam
pub fn system_time_seconds() -> Int
```

**Подсказка:** используйте `@external(erlang, "erlang", "system_time")` с атомом `second`. Создайте атом через:

```gleam
@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(s: String) -> atom.Atom
```

### 2. get_api_base_url — переменные окружения (Лёгкое)

Реализуйте функцию, читающую переменную окружения `POKEAPI_BASE_URL`:

```gleam
pub fn get_api_base_url() -> String
```

Если переменная не установлена, возвращает `"https://pokeapi.co"`.

**Подсказка:** создайте `chapter08_ffi.erl` с функцией `get_env/1` (как в примере выше).

### 3. file_exists — проверка существования файла (Среднее)

Реализуйте функцию проверки существования файла:

```gleam
pub fn file_exists(path: String) -> Bool
```

**Подсказка:** используйте `@external(erlang, "filelib", "is_file")`. Не забудьте преобразовать `String` в `Charlist`.

### 4. read_lines — чтение файла построчно (Среднее)

Реализуйте функцию, читающую файл и разбивающую его на строки:

```gleam
pub fn read_lines(path: String) -> Result(List(String), String)
```

**Подсказка:** используйте FFI к `file:read_file/1`, затем преобразуйте `BitArray` в `String` через `bit_array.to_string`, и разбейте на строки через `string.split(..., "\n")`.

### 5. LogLevel — безопасная работа с атомами (Среднее)

Реализуйте безопасный ADT для уровней логирования:

```gleam
pub type LogLevel {
  Debug
  Info
  Warning
  Error
}

pub fn log_level_to_atom(level: LogLevel) -> atom.Atom
pub fn log_level_from_atom(a: atom.Atom) -> Result(LogLevel, Nil)
```

**Подсказка:** `log_level_from_atom` должен проверять `atom.to_string(a)` и возвращать соответствующий `LogLevel` или `Error(Nil)`.

### 6. pid_to_string — работа с процессами (Среднее-Сложное)

Реализуйте функцию преобразования Pid (идентификатор процесса BEAM) в строку:

```gleam
pub fn pid_to_string(pid: process.Pid) -> String
```

**Подсказка:** используйте `@external(erlang, "erlang", "pid_to_list")`, который возвращает `Charlist`, затем преобразуйте в `String`.

### 7. measure_time — измерение времени выполнения (Сложное)

Реализуйте функцию, измеряющую время выполнения переданной функции:

```gleam
pub fn measure_time(f: fn() -> a) -> #(a, Int)
```

Возвращает кортеж `#(результат, время_в_микросекундах)`.

**Подсказка:**

1. Получите время до вызова через `erlang:monotonic_time(microsecond)`
2. Вызовите `f()`
3. Получите время после
4. Вычтите и верните разницу

### 8. ensure_dir — создание директории (Сложное)

Реализуйте функцию, создающую директорию (включая родительские):

```gleam
pub fn ensure_dir(path: String) -> Result(Nil, String)
```

**Подсказка:** используйте `@external(erlang, "filelib", "ensure_dir")`. Эта функция требует путь к файлу (не директории!), поэтому добавьте `"/"` в конец пути.

## Заключение

В этой главе мы изучили взаимодействие Gleam с Erlang:

- **External functions** — прямой вызов Erlang-функций через `@external`
- **External types** — работа с типами из Erlang
- **gleam_erlang** — типизированные обёртки над Erlang API
- **Атомы** — уникальные идентификаторы с безопасным использованием
- **Charlist** — совместимость со строками Erlang
- **Системное программирование** — файлы, процессы, переменные окружения

FFI к Erlang открывает доступ к мощной экосистеме BEAM — от работы с файлами и сетью до распределённых систем и OTP. При этом Gleam сохраняет типобезопасность и выразительность.

В следующей главе мы переключимся на JavaScript-таргет и изучим FFI для веб-разработки и фронтенд-интеграции.
