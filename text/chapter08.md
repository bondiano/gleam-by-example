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

### Работа с процессами через FFI

Одно из главных преимуществ BEAM — легковесные процессы. Библиотека `gleam/erlang/process` предоставляет типобезопасные обёртки, но давайте посмотрим, как они устроены:

```gleam
import gleam/erlang/process.{type Pid}

// Получение PID текущего процесса
@external(erlang, "erlang", "self")
pub fn self() -> Pid

// Создание процесса с линком
@external(erlang, "proc_lib", "spawn_link")
fn spawn_linked(f: fn() -> anything) -> Pid

// Отправка сообщения процессу
@external(erlang, "erlang", "send")
fn send_message(to: Pid, message: anything) -> anything

// Использование
pub fn example() {
  let current_pid = self()

  let worker_pid = spawn_linked(fn() {
    // Код процесса
    io.println("Worker started!")
  })

  send_message(worker_pid, "hello")
}
```

Эти примеры показывают ключевые примитивы BEAM: `erlang:self/0` возвращает PID текущего процесса, `proc_lib:spawn_link/1` создаёт новый процесс и связывает его с родительским (если один упадёт, другой получит сигнал), `erlang:send/2` отправляет сообщение в mailbox процесса.

### Работа с ETS (Erlang Term Storage)

ETS — встроенная in-memory база данных BEAM. Она позволяет хранить огромные объёмы данных с О(1) доступом:

```erlang
% src/ets_ffi.erl
-module(ets_ffi).
-export([new_table/1, insert/3, lookup/2, delete_table/1]).

new_table(Name) ->
    ets:new(binary_to_atom(Name), [set, public, named_table]).

insert(Table, Key, Value) ->
    ets:insert(Table, {Key, Value}),
    ok.

lookup(Table, Key) ->
    case ets:lookup(Table, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil}
    end.

delete_table(Table) ->
    ets:delete(Table),
    ok.
```

```gleam
import gleam/dynamic.{type Dynamic}

pub type EtsTable

@external(erlang, "ets_ffi", "new_table")
pub fn new_table(name: String) -> EtsTable

@external(erlang, "ets_ffi", "insert")
pub fn insert(table: EtsTable, key: String, value: Dynamic) -> Nil

@external(erlang, "ets_ffi", "lookup")
pub fn lookup(table: EtsTable, key: String) -> Result(Dynamic, Nil)

@external(erlang, "ets_ffi", "delete_table")
pub fn delete_table(table: EtsTable) -> Nil

// Использование
pub fn cache_example() {
  let cache = new_table("my_cache")

  insert(cache, "user:1", dynamic.from("Alice"))

  case lookup(cache, "user:1") {
    Ok(value) -> io.debug(value)
    Error(_) -> io.println("Not found")
  }

  delete_table(cache)
}
```

ETS — мощный инструмент для кэширования и совместного состояния между процессами. Таблица создаётся через `ets:new/2` с опциями (здесь `set` означает уникальные ключи, `public` — доступ из любого процесса). `ets:insert/2` добавляет пары ключ-значение, `ets:lookup/2` возвращает значение или пустой список.

### Calling NIFs (Native Implemented Functions)

NIFs позволяют вызывать код на C, Rust или Zig из Erlang. Пример с Rust NIF через библиотеку `rustler`:

```erlang
% src/math_nif.erl
-module(math_nif).
-export([fast_fibonacci/1]).
-on_load(init/0).

init() ->
    ok = erlang:load_nif("./priv/math_nif", 0).

fast_fibonacci(_N) ->
    erlang:nif_error("NIF library not loaded").
```

```rust
// native/math_nif/src/lib.rs (Rust)
#[rustler::nif]
fn fast_fibonacci(n: i64) -> i64 {
    if n <= 1 {
        n
    } else {
        let mut a = 0;
        let mut b = 1;
        for _ in 2..=n {
            let temp = a + b;
            a = b;
            b = temp;
        }
        b
    }
}

rustler::init!("math_nif", [fast_fibonacci]);
```

```gleam
@external(erlang, "math_nif", "fast_fibonacci")
pub fn fast_fibonacci(n: Int) -> Int

// Использование
fast_fibonacci(100)  // Выполняется в нативном коде
```

NIFs выполняются напрямую в нативном коде (не на BEAM VM), что даёт огромный прирост производительности для тяжёлых вычислений. `erlang:load_nif/2` загружает скомпилированную `.so` библиотеку. **Важно:** NIF блокирует scheduler при выполнении — используйте их осторожно для задач, которые выполняются быстро (<1ms), иначе применяйте Dirty NIFs.

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

### 9. simple_ets_cache — работа с ETS (Сложное)

Реализуйте простой кэш на ETS:

```gleam
pub type Cache

pub fn new_cache(name: String) -> Cache
pub fn cache_put(cache: Cache, key: String, value: String) -> Nil
pub fn cache_get(cache: Cache, key: String) -> Result(String, Nil)
pub fn cache_delete(cache: Cache) -> Nil
```

**Подсказка:** создайте `ets_ffi.erl` аналогично примеру из главы. Используйте `ets:new/2`, `ets:insert/2`, `ets:lookup/2`, `ets:delete/1`.

### 10. spawn_and_receive — процессы и сообщения (Сложное)

Реализуйте функцию, запускающую процесс и получающую от него сообщение:

```gleam
pub fn spawn_echo() -> String
```

Функция должна:
1. Создать процесс, который отправляет сообщение `"echo"` родителю
2. Получить это сообщение
3. Вернуть его как строку

**Подсказка:**
- Используйте `process.self()` для получения родительского PID
- Используйте `process.start(fn() { ... }, True)` для создания процесса
- Используйте `process.receive(selector, timeout)` для получения сообщения

## Заключение

В этой главе мы изучили взаимодействие Gleam с Erlang:

- **External functions** — прямой вызов Erlang-функций через `@external`
- **External types** — работа с типами из Erlang
- **gleam_erlang** — типизированные обёртки над Erlang API
- **Атомы** — уникальные идентификаторы с безопасным использованием
- **Charlist** — совместимость со строками Erlang
- **Системное программирование** — файлы, процессы, переменные окружения
- **Продвинутые техники** — работа с процессами, ETS и NIFs

FFI к Erlang открывает доступ к мощной экосистеме BEAM — от работы с файлами и сетью до распределённых систем и OTP. При этом Gleam сохраняет типобезопасность и выразительность.

> **Что дальше:** В главе 10 мы изучим высокоуровневые абстракции OTP для работы с процессами — акторы, супервизоры и философию «Let it crash». Низкоуровневые FFI-функции из этой главы (spawn, send, ETS) станут фундаментом для понимания того, как работают типобезопасные обёртки `gleam/otp/actor` и `gleam/otp/static_supervisor`.

В следующей главе мы переключимся на JavaScript-таргет и изучим FFI для веб-разработки и фронтенд-интеграции.
