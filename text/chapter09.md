# Тестирование

> «Testing can be fun, actually» — Джакомо Кавальери, автор birdie

## Цели главы

В этой главе мы:

- Освоим gleeunit — стандартный тестовый фреймворк Gleam
- Научимся писать выразительные утверждения с `should`
- Изучим property-based testing (PBT) с qcheck
- Познакомимся с генераторами и shrinking
- Попробуем snapshot-тестирование с birdie
- Разберём паттерны организации тестов
- Научимся тестировать акторы и асинхронный код
- Настроим CI с GitHub Actions

## Зачем тестировать?

Gleam — строго типизированный язык, и компилятор ловит многие ошибки. Но типы не могут проверить всё:

- Правильность бизнес-логики (`sort` возвращает отсортированный список, а не просто `List(Int)`)
- Граничные случаи (пустой список, отрицательные числа, unicode)
- Взаимодействие компонентов (JSON encode → decode = оригинал?)
- Регрессии (исправили баг — не сломали другое)

Тесты дополняют типы: типы гарантируют **структурную** корректность, тесты — **семантическую**.

## gleeunit — стандартный фреймворк

`gleeunit` — стандартный тестовый раннер для Gleam. Он минималистичен: запускает все публичные функции с суффиксом `_test` в модулях из директории `test/`.

### Структура теста

```gleam
// test/my_module_test.gleam
import gleeunit
import gleeunit/should
import my_module

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn add_test() {
  my_module.add(1, 2)
  |> should.equal(3)
}

pub fn add_zero_test() {
  my_module.add(0, 0)
  |> should.equal(0)
}
```

Правила:

- Файл в директории `test/`
- Функция `main` вызывает `gleeunit.main()`
- Каждый тест — публичная функция с суффиксом `_test`
- Тесты не принимают аргументов и возвращают `Nil`

### Запуск тестов

```sh
$ gleam test
  Compiling chapter09
   Compiled in 0.15s
    Running chapter09_test.main
.....
5 tests passed
```

### Утверждения (assertions)

Модуль `gleeunit/should` предоставляет набор утверждений:

```gleam
import gleeunit/should

// Равенство
1 + 1 |> should.equal(2)
"hello" |> should.not_equal("world")

// Result
Ok(42) |> should.be_ok
Error("oops") |> should.be_error

// Bool
True |> should.be_true
False |> should.be_false

// Безусловный провал
should.fail()
```

Все функции `should.*` при неуспехе **паникуют** — тест считается проваленным, и gleeunit сообщает, какое значение ожидалось и какое получено.

### Пример: тестирование чистых функций

```gleam
import gleam/string
import gleeunit/should

pub fn capitalize_test() {
  string.capitalise("hello")
  |> should.equal("Hello")
}

pub fn capitalize_empty_test() {
  string.capitalise("")
  |> should.equal("")
}

pub fn capitalize_already_test() {
  string.capitalise("Hello")
  |> should.equal("Hello")
}
```

### Пример: тестирование Result

```gleam
import gleam/int
import gleeunit/should

pub fn parse_valid_test() {
  int.parse("42")
  |> should.be_ok
  |> should.equal(42)
}

pub fn parse_invalid_test() {
  int.parse("not a number")
  |> should.be_error
}
```

Обратите внимание на цепочку: `should.be_ok` возвращает значение внутри `Ok`, поэтому можно продолжить `|> should.equal(42)`.

### Организация тестов

Хорошие практики организации:

```gleam
// Группируйте тесты по функции с комментариями-разделителями
// ============================================================
// Тесты для sort
// ============================================================

pub fn sort_empty_test() { ... }
pub fn sort_single_test() { ... }
pub fn sort_already_sorted_test() { ... }
pub fn sort_reverse_test() { ... }

// ============================================================
// Тесты для filter
// ============================================================

pub fn filter_empty_test() { ... }
pub fn filter_none_match_test() { ... }
pub fn filter_all_match_test() { ... }
```

Имена тестов должны описывать **что проверяется**:

- `sort_empty_test` — сортировка пустого списка
- `parse_negative_number_test` — парсинг отрицательного числа
- `kv_delete_nonexistent_test` — удаление несуществующего ключа

## Тестирование акторов

Акторы из главы 8 тоже нужно тестировать. Подход прямолинейный: создаём актор, отправляем сообщения, проверяем ответы.

```gleam
import gleam/otp/actor
import gleeunit/should

pub fn counter_increment_test() {
  let assert Ok(counter) = start_counter()

  actor.send(counter, Increment)
  actor.send(counter, Increment)
  actor.send(counter, Increment)

  actor.call(counter, waiting: 1000, sending: GetCount)
  |> should.equal(3)
}
```

### Таймауты в тестах

По умолчанию gleeunit даёт каждому тесту **5 секунд**. Для тестов с акторами этого обычно достаточно, но если тест включает `process.sleep` или ожидание сообщений, может не хватить.

> **Совет:** в тестах используйте небольшие таймауты (`waiting: 100`) вместо `waiting: 1000`. Если актор не отвечает за 100 мс — скорее всего, есть баг, а не медленность.

### Изоляция тестов

Каждый тест должен создавать **собственные** акторы. Не используйте общие акторы между тестами — порядок выполнения не гарантирован:

```gleam
// ✓ Хорошо: каждый тест создаёт своего актора
pub fn test_a() {
  let assert Ok(actor) = start_counter()
  // ...
}

pub fn test_b() {
  let assert Ok(actor) = start_counter()
  // ...
}
```

## Property-based testing с qcheck

Unit-тесты проверяют конкретные примеры: `sort([3, 1, 2]) == [1, 2, 3]`. Но что если пропущен граничный случай?

**Property-based testing** (PBT) — подход, при котором вы описываете **свойства** (законы), которым должна удовлетворять функция, а фреймворк генерирует **сотни случайных входных данных** и проверяет, что свойства выполняются.

### Концепция

Вместо `sort([3, 1, 2]) == [1, 2, 3]` мы пишем:

> «Для **любого** списка `xs`, после `sort(xs)` каждый элемент ≤ следующего»

Фреймворк генерирует списки: `[]`, `[1]`, `[5, -3, 0, 99, -42]`, `[1, 1, 1]`, ... — и проверяет свойство на каждом.

### qcheck — PBT для Gleam

```gleam
import gleam/list
import qcheck

pub fn sort_is_sorted_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  let sorted = list.sort(xs, int.compare)
  is_sorted(sorted)
  |> should.be_true
}

fn is_sorted(xs: List(Int)) -> Bool {
  case xs {
    [] | [_] -> True
    [a, b, ..rest] ->
      case a <= b {
        True -> is_sorted([b, ..rest])
        False -> False
      }
  }
}
```

`qcheck.given(generator)` запускает property-test:

1. Генерирует случайные значения с помощью `generator`
2. Передаёт каждое значение в функцию-свойство
3. Если свойство нарушено — **сжимает** (shrinks) контрпример до минимального

### Генераторы

Генераторы — источники случайных данных:

```gleam
// Примитивные генераторы
qcheck.int()              // случайный Int
qcheck.float()            // случайный Float
qcheck.string()           // случайная String
qcheck.bool()             // True или False

// Коллекции
qcheck.list(qcheck.int())           // List(Int)
qcheck.list(qcheck.string())        // List(String)

// Ограниченные диапазоны
qcheck.int_uniform_inclusive(1, 100)  // Int от 1 до 100
qcheck.small_positive_or_zero_int()   // маленькие неотрицательные

// Константы и выбор
qcheck.return(42)                    // всегда 42
qcheck.from_list([1, 2, 3])         // случайный из списка
```

### Shrinking — сжатие контрпримеров

Когда свойство нарушено на входе `[99, -42, 73, 0, -15]`, qcheck не просто сообщает об ошибке — он **сжимает** контрпример, убирая лишние элементы и уменьшая числа, пока свойство всё ещё нарушено:

```
Failing input: [99, -42, 73, 0, -15]
After shrinking: [1, 0]
```

Это экономит время на отладку — вместо сложного случая вы видите минимальный.

### Пользовательские генераторы

Можно создавать генераторы для своих типов:

```gleam
import qcheck

pub type Color {
  Red
  Green
  Blue
}

fn color_generator() -> qcheck.Generator(Color) {
  qcheck.from_list([Red, Green, Blue])
}

pub type Point {
  Point(x: Int, y: Int)
}

fn point_generator() -> qcheck.Generator(Point) {
  use x <- qcheck.parameter(qcheck.int())
  use y <- qcheck.parameter(qcheck.int())
  qcheck.return(Point(x:, y:))
}
```

### Какие свойства тестировать?

Вот классические свойства, применимые к разным функциям:

**Инволюция** — применение дважды возвращает оригинал:

```gleam
pub fn reverse_involution_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  list.reverse(list.reverse(xs)) == xs
  |> should.be_true
}
```

**Идемпотентность** — повторное применение не меняет результат:

```gleam
pub fn sort_idempotent_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  let sorted = list.sort(xs, int.compare)
  list.sort(sorted, int.compare) == sorted
  |> should.be_true
}
```

**Сохранение инварианта** — свойство выполняется для любого входа:

```gleam
pub fn sort_preserves_length_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  list.length(list.sort(xs, int.compare)) == list.length(xs)
  |> should.be_true
}
```

**Roundtrip** — encode → decode = оригинал:

```gleam
pub fn json_roundtrip_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  xs
  |> encode_ints
  |> decode_ints
  |> should.equal(Ok(xs))
}
```

**Постусловие** — результат удовлетворяет определённому свойству:

```gleam
pub fn abs_non_negative_test() {
  use n <- qcheck.given(qcheck.int())
  int.absolute_value(n) >= 0
  |> should.be_true
}
```

## Snapshot-тестирование с birdie

**Snapshot-тесты** сохраняют «снимок» вывода функции и сравнивают с ним при последующих запусках. Это удобно для:

- Форматированного вывода (таблицы, отчёты)
- Сериализации (JSON, HTML)
- Диагностических сообщений

### Как работает birdie

```gleam
import birdie

pub fn format_table_test() {
  format_table(["Name", "Age"], [["Alice", "30"], ["Bob", "25"]])
  |> birdie.snap("format simple table")
}
```

При первом запуске `gleam test`:

1. birdie создаёт файл `birdie_snapshots/format_simple_table.accepted` с выводом функции
2. Тест проходит

При последующих запусках:

1. birdie сравнивает текущий вывод с сохранённым
2. Если совпадает — тест проходит
3. Если отличается — тест падает, показывая diff

### Управление снимками

```sh
# Запуск тестов (birdie создаёт .new файлы для новых/изменённых снимков)
$ gleam test

# Интерактивный ревью: принять, отклонить или пропустить каждый снимок
$ gleam run -m birdie
```

birdie показывает diff для каждого изменённого снимка и предлагает:

- **Accept** — принять новый снимок
- **Reject** — оставить старый
- **Skip** — решить позже

### Когда использовать snapshot-тесты

- **Форматированный вывод**: таблицы, отчёты, pretty-print
- **Сериализация**: JSON, TOML, XML
- **Сложные структуры**: где `should.equal` требует громоздкий ожидаемый результат
- **Регрессии формата**: заметить, если вывод изменился неожиданно

Snapshot-тесты **не** заменяют unit-тесты и PBT — они дополняют их. Используйте unit-тесты для логики, PBT для свойств, snapshots для форматирования.

## Проект: тестирование библиотеки коллекций

Объединим все подходы для тестирования функций из предыдущих глав.

### Unit-тесты

```gleam
import gleam/list
import gleam/int
import gleeunit/should

pub fn sort_empty_test() {
  list.sort([], int.compare)
  |> should.equal([])
}

pub fn sort_single_test() {
  list.sort([42], int.compare)
  |> should.equal([42])
}

pub fn sort_already_sorted_test() {
  list.sort([1, 2, 3, 4, 5], int.compare)
  |> should.equal([1, 2, 3, 4, 5])
}

pub fn sort_reverse_test() {
  list.sort([5, 4, 3, 2, 1], int.compare)
  |> should.equal([1, 2, 3, 4, 5])
}

pub fn sort_duplicates_test() {
  list.sort([3, 1, 3, 1, 2], int.compare)
  |> should.equal([1, 1, 2, 3, 3])
}
```

### Property-based тесты

```gleam
import qcheck

pub fn sort_output_is_sorted_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  let sorted = list.sort(xs, int.compare)
  is_sorted(sorted)
  |> should.be_true
}

pub fn sort_preserves_elements_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  let sorted = list.sort(xs, int.compare)
  list.sort(xs, int.compare) == list.sort(sorted, int.compare)
  |> should.be_true
}
```

### Snapshot-тесты

```gleam
import birdie

pub fn format_table_snapshot_test() {
  format_table(
    ["ID", "Name", "Score"],
    [["1", "Alice", "95"], ["2", "Bob", "87"], ["3", "Charlie", "92"]],
  )
  |> birdie.snap("score table")
}
```

## Тестирование JSON roundtrip

Roundtrip-тесты — один из самых мощных паттернов для PBT. Идея: если мы кодируем значение в JSON и тут же декодируем обратно, должны получить оригинал.

```gleam
import gleam/dynamic/decode
import gleam/json

// Кодирование списка Int в JSON
pub fn encode_ints(xs: List(Int)) -> String {
  xs
  |> json.array(json.int)
  |> json.to_string
}

// Декодирование JSON в список Int
pub fn decode_ints(s: String) -> Result(List(Int), Nil) {
  json.parse(s, decode.list(decode.int))
  |> result.map_error(fn(_) { Nil })
}

// Property: roundtrip
pub fn json_roundtrip_test() {
  use xs <- qcheck.given(qcheck.list(qcheck.int()))
  xs
  |> encode_ints
  |> decode_ints
  |> should.equal(Ok(xs))
}
```

Этот тест генерирует сотни случайных списков и проверяет, что encode → decode = оригинал. Если есть баг в кодировщике или декодировщике — qcheck его найдёт.

## CI: тестирование в GitHub Actions

Настройка CI для Gleam-проекта:

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27.0"
          gleam-version: "1.6.0"
      - run: gleam test
      - run: gleam format --check src/ test/
```

Ключевые шаги:

1. **setup-beam** — устанавливает Erlang/OTP и Gleam
2. **gleam test** — запускает все тесты
3. **gleam format --check** — проверяет форматирование (без изменения файлов)

## Упражнения

В этой главе упражнения необычные: вы будете реализовывать функции **и** видеть, как они тестируются разными подходами (unit, PBT, snapshot).

Решения пишите в файле `exercises/chapter09/test/my_solutions.gleam`. Запускайте тесты:

```sh
$ cd exercises/chapter09
$ gleam test
```

### 1. is_sorted — проверка сортировки (Лёгкое)

Реализуйте функцию, проверяющую, отсортирован ли список по возрастанию.

```gleam
pub fn is_sorted(xs: List(Int)) -> Bool
```

**Примеры:**

```
is_sorted([]) == True
is_sorted([1]) == True
is_sorted([1, 2, 3, 4, 5]) == True
is_sorted([1, 3, 2]) == False
is_sorted([5, 4, 3]) == False
```

**Подсказка:** рекурсия с pattern matching на `[a, b, ..rest]`. Базовые случаи: `[]` и `[_]` → True.

### 2. encode_ints / decode_ints — JSON roundtrip (Среднее)

Реализуйте кодирование и декодирование списка целых чисел в/из JSON.

```gleam
pub fn encode_ints(xs: List(Int)) -> String
pub fn decode_ints(s: String) -> Result(List(Int), Nil)
```

**Примеры:**

```
encode_ints([1, 2, 3]) == "[1,2,3]"
decode_ints("[1,2,3]") == Ok([1, 2, 3])
decode_ints("not json") == Error(Nil)
```

Тест проверит roundtrip: `encode_ints(xs) |> decode_ints == Ok(xs)`.

**Подсказка:** `json.array(xs, json.int) |> json.to_string` для кодирования. `json.parse(s, decode.list(decode.int))` для декодирования.

### 3. my_sort — сортировка с PBT (Среднее)

Реализуйте сортировку списка целых чисел (любым алгоритмом).

```gleam
pub fn my_sort(xs: List(Int)) -> List(Int)
```

Тесты проверят несколько свойств вашей сортировки через qcheck:

- Результат отсортирован (каждый элемент ≤ следующего)
- Длина сохраняется
- Идемпотентность (повторная сортировка не меняет результат)
- Сохранение элементов (те же элементы, что и на входе)

**Подсказка:** можно использовать `list.sort(xs, int.compare)` или написать свою реализацию (insertion sort, merge sort).

### 4. int_in_range — генератор чисел в диапазоне (Среднее)

Реализуйте функцию-генератор, которая создаёт целые числа в заданном диапазоне `[lo, hi]`.

```gleam
pub fn int_in_range(lo: Int, hi: Int) -> qcheck.Generator(Int)
```

Тесты проверят свойства генератора:

- Все сгенерированные числа ≥ lo
- Все сгенерированные числа ≤ hi

**Подсказка:** используйте `qcheck.int_uniform_inclusive(lo, hi)`.

### 5. clamp — ограничение значения с PBT (Сложное)

Реализуйте функцию, ограничивающую значение диапазоном `[lo, hi]`.

```gleam
pub fn clamp(value: Int, lo: Int, hi: Int) -> Int
```

**Примеры:**

```
clamp(5, 1, 10) == 5     // в диапазоне — не меняется
clamp(-3, 0, 100) == 0   // меньше lo — возвращает lo
clamp(999, 0, 100) == 100 // больше hi — возвращает hi
```

Тесты проверят через qcheck:

- Результат всегда ≥ lo
- Результат всегда ≤ hi
- Если value в диапазоне — возвращается без изменений
- Идемпотентность: `clamp(clamp(x, lo, hi), lo, hi) == clamp(x, lo, hi)`

**Подсказка:** `int.min(hi, int.max(lo, value))` или case-выражение с guards.

## Заключение

В этой главе мы изучили:

- **gleeunit** — стандартный тестовый раннер с утверждениями `should.*`
- **Организация тестов** — именование, группировка, изоляция
- **Тестирование акторов** — создание, отправка сообщений, таймауты
- **Property-based testing** с qcheck — генераторы, свойства, shrinking
- **Snapshot-тестирование** с birdie — снимки вывода, интерактивный ревью
- **JSON roundtrip** — мощный паттерн для PBT
- **CI** — GitHub Actions для автоматического тестирования

В следующей главе мы создадим полноценное веб-приложение с Wisp — HTTP-фреймворком для Gleam.
