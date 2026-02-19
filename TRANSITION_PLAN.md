# План адаптации «PureScript by Example» → «Gleam by Example»

## Оглавление

1. [Общая концепция](#общая-концепция)
2. [Инструментарий и инфраструктура](#инструментарий-и-инфраструктура)
3. [Ключевые отличия PureScript → Gleam](#ключевые-отличия-purescript--gleam)
4. [Главы](#главы)
   - [Глава 1: Введение](#глава-1-введение)
   - [Глава 2: Начало работы](#глава-2-начало-работы)
   - [Глава 3: Функции и пайплайны](#глава-3-функции-и-пайплайны)
   - [Глава 4: Типы данных и коллекции](#глава-4-типы-данных-и-коллекции)
   - [Глава 5: Рекурсия, свёртки и обработка ошибок](#глава-5-рекурсия-свёртки-и-обработка-ошибок)
   - [Глава 6: Строки, битовые массивы и стандартная библиотека](#глава-6-строки-битовые-массивы-и-стандартная-библиотека)
   - [Глава 7: FFI, JSON и типобезопасный парсинг](#глава-7-ffi-json-и-типобезопасный-парсинг)
   - [Глава 8: Процессы и OTP](#глава-8-процессы-и-otp)
   - [Глава 9: Тестирование](#глава-9-тестирование)
   - [Глава 10: Веб-разработка с Wisp](#глава-10-веб-разработка-с-wisp)
   - [Глава 11: Фронтенд с Lustre](#глава-11-фронтенд-с-lustre)
   - [Глава 12: Telegram-бот с Telega](#глава-12-telegram-бот-с-telega)
5. [Покрытие Exercism](#покрытие-exercism)
6. [Покрытие стандартной библиотеки](#покрытие-стандартной-библиотеки)
7. [Стратегия перевода](#стратегия-перевода)
8. [Порядок работы](#порядок-работы)
9. [Принятые решения](#принятые-решения)

---

## Общая концепция

Книга «Gleam by Example» — адаптация «PureScript by Example» (Phil Freeman)
для языка Gleam. Это **не** дословный перевод: мы адаптируем материал
под идиоматический Gleam, сохраняя педагогическую структуру оригинала.

### Философские отличия от предыдущих версий

| Haskell-версия | OCaml-версия | **Gleam-версия** |
|----------------|--------------|------------------|
| Классы типов | Модули, функторы | **Нет — generics + opaque types** |
| Аппликативная валидация | option/result + let-операторы | **Result + use-выражения** |
| Монада IO | Прямые эффекты | **Прямые эффекты (BEAM)** |
| Monad transformers | Effect handlers | **Акторы и OTP** |
| Ленивые вычисления | Строгие + Seq | **Строгие + Iterator** |
| FFI → C | FFI → C | **FFI → Erlang + JavaScript** |
| Нет конкурентности | Eio (файберы) | **BEAM-процессы, акторы, супервизоры** |
| QuickCheck | QCheck | **qcheck** |
| gloss/brick | raylib | **Lustre (веб-UI)** |
| Servant/Scotty | Dream | **Wisp** |
| — | — | **Telegram-бот (Telega)** |

Gleam занимает уникальную нишу: это **строго типизированный язык на BEAM**,
сочетающий безопасность типов с отказоустойчивостью Erlang. В отличие от
Haskell и OCaml, Gleam намеренно **минималистичен** — нет type classes,
нет макросов, нет GADTs. Это делает язык доступнее, а книгу — короче.

### Ключевые преимущества Gleam для книги

1. **Двойной таргет (BEAM + JavaScript)** — уникальная тема
2. **OTP/акторы** — промышленная конкурентность и отказоустойчивость
3. **Простота** — намеренно минималистичный, порог входа ниже
4. **Lustre** — Elm-архитектура на Gleam (фронтенд + server components)
5. **Экосистема BEAM** — доступ к Erlang/Elixir через FFI

---

## Инструментарий и инфраструктура

| Компонент | PureScript | Gleam |
|-----------|-----------|-------|
| Компилятор | purs | gleam (Rust-реализация) |
| Менеджер пакетов | Spago | gleam (встроенный, Hex) |
| Система сборки | Spago (+ purs) | gleam build |
| Конфигурация проекта | spago.dhall | gleam.toml |
| Форматтер | purty / purs-tidy | gleam format |
| REPL | PSCi | — (нет REPL, но есть `gleam run`) |
| LSP | purescript-language-server | gleam lsp |
| Тестовый фреймворк | purescript-test-unit | gleeunit / startest |
| Книга | — | mdBook |

### Версии инструментов

- **Gleam**: >= 1.6.0
- **Erlang/OTP**: >= 27.0
- **mdBook**: 0.4+
- **gleeunit**: 1.0+
- **qcheck**: 1.0+

---

## Ключевые отличия PureScript → Gleam

### Синтаксис и система типов

| Аспект | PureScript | Gleam |
|--------|-----------|-------|
| Применение функций | `f x y` | `f(x, y)` |
| Лямбда | `\x -> x + 1` | `fn(x) { x + 1 }` |
| Привязка | `let x = 5 in ...` | `let x = 5` |
| Записи | `{ name: "Alice" }` | Custom type с labelled fields |
| Обновление записи | `person { name = "Bob" }` | `Person(..person, name: "Bob")` |
| Типы-суммы | `data Color = Red \| Green` | `type Color { Red Green }` |
| Сопоставление | `case x of ...` | `case x { ... }` |
| Типы | `Int`, `String`, `Boolean` | `Int`, `String`, `Bool` |
| Полиморфизм | `forall a. a -> a` | `fn(a) -> a` (вывод) |
| Классы типов | `class Eq a where ...` | **Нет** — generics + модули |
| do-нотация | `do { x <- action; pure x }` | `use x <- result.try(action)` |
| Эффекты | `Effect`, `Aff` | Прямые эффекты (BEAM) |
| Модульная система | Плоская (модуль = файл) | Плоская (модуль = файл) |
| Строки | `String` (JS-строки) | `String` (UTF-8) |
| Массивы | `Array a` (JS-массивы) | **Нет** — используй List |
| Списки | `List a` | `List(a)` |
| Опциональность | `Maybe a` | `Option(a)` |
| Ошибки | `Either e a` | `Result(a, e)` |
| Pipe-оператор | `#` или `\|>` | `\|>` (встроенный) |
| Именованные аргументы | Нет | `fn greet(name name: String)` |
| Use-выражения | Нет | `use x <- callback(arg)` |

### Экосистема и паттерны

| Аспект | PureScript | Gleam |
|--------|-----------|-------|
| Чистота | Принудительная (Effect/Aff) | Конвенциональная (эффекты на BEAM) |
| Ленивость | Строгий (Lazy по запросу) | Строгий (Iterator для ленивости) |
| Конкурентность | Aff (промисы) | **BEAM-процессы, акторы (OTP)** |
| Веб-фреймворк | Halogen, React | **Wisp** (сервер), **Lustre** (фронтенд) |
| JSON | argonaut, simple-json | **gleam_json** + gleam/dynamic/decode |
| Тестирование | purescript-test-unit, purescript-quickcheck | **gleeunit**, **qcheck**, **birdie** |
| FFI | JS (foreign import) | **Erlang + JavaScript** (external) |
| SQL | — | **pog** + **Squirrel** (type-safe codegen) |
| Telegram-боты | — | **Telega** |
| Рантайм | Node.js / Browser | **BEAM** / Browser (JS target) |

---

## Главы

### Глава 1: Введение ✅

#### Оригинал (PureScript)
Мотивация для ФП, введение в PureScript, особенности языка.

#### Адаптация (Gleam) — ГОТОВО
- Мотивация: зачем ещё один ФП-язык?
- Gleam = **безопасность типов** + **отказоустойчивость BEAM** + **простота**
- BEAM (Erlang VM): история, промышленное использование (WhatsApp, Discord, RabbitMQ, Ericsson)
- Двойной таргет: один код → Erlang + JavaScript
- Философия: намеренный минимализм, дружелюбные ошибки
- Hex — единая экосистема (Erlang/Elixir/Gleam)
- Сравнение с другими языками (таблица): Elm, Rust, Elixir, Haskell*, OCaml*
  - * — JS-таргеты через сторонние инструменты (GHCJS, js_of_ocaml)
- Структура книги (12 глав, таблица), как читать, о читателе, ресурсы

#### Упражнения
Нет (вводная глава).

#### Источники
- [Gleam — официальный сайт](https://gleam.run/)
- [Gleam Language Tour](https://tour.gleam.run/)
- [Have You Tried Gleam? (Medium)](https://guycoding.medium.com/have-you-tried-gleam-a-fresh-take-on-functional-programming-a8390234f156)
- [BEAM Book](https://blog.stenmans.org/theBeamBook/)
- [Exercism Gleam Track](https://exercism.org/tracks/gleam)

---

### Глава 2: Начало работы ✅

#### Оригинал (PureScript)
Настройка, первая программа, типы данных, Spago.

#### Адаптация (Gleam) — ГОТОВО
- Установка: `brew install gleam` / cargo / asdf
- Установка Erlang/OTP
- `gleam new`, `gleam run`, `gleam test`, `gleam add`, `gleam format`
- Структура проекта: `gleam.toml`, `src/`, `test/`, `build/`
- Базовые типы: `Int`, `Float`, `String`, `Bool`
- Арифметика: `+`, `-`, `*`, `/` для Int; `+.`, `-.`, `*.`, `/.` для Float
- `let`-привязки, shadowing, блоки `{ ... }`
- Аннотации типов
- Функции: `pub fn`, тип `Nil`
- Discard-паттерны: `_` (анонимный) vs `_name` (именованный)
- Модули: `import`, qualified access, unqualified imports
- Импорт типов: `import gleam/option.{type Option}`
- `gleam/io` — вывод в консоль
- `gleam/int`, `gleam/float` — базовые операции
- **Нет неявных приведений** — `int.to_float`, `float.round`
- Проект: задача Эйлера №1

#### Покрытие stdlib
- `gleam/io`: `println`, `debug`
- `gleam/int`: `to_string`, `to_float`, `parse`, `sum`, `product`, `is_even`, `is_odd`, `absolute_value`, `min`, `max`, `clamp`, `compare`, `power`, `square_root`, `random`, `remainder`, `modulo`
- `gleam/float`: `to_string`, `parse`, `round`, `floor`, `ceiling`, `truncate`, `to_precision`, `absolute_value`, `min`, `max`, `clamp`, `compare`, `power`, `square_root`, `random`, `sum`, `product`, `negate`, `logarithm`, `exponential`

#### Упражнения (Exercism coverage)
1. **diagonal** — длина диагонали прямоугольника (Float, `float.square_root`)
   - Exercism: *difference-of-squares*, *freelancer-rates*
2. **celsius_to_fahrenheit** — конвертация Цельсий → Фаренгейт
   - Exercism: *leap*
3. **fahrenheit_to_celsius** — обратная конвертация Фаренгейт → Цельсий
4. **euler1** — задача Эйлера (сумма кратных 3 и 5)
   - Exercism: *sum-of-multiples*

#### Библиотеки
- `gleam_stdlib`

#### Источники
- [Gleam — Getting Started](https://gleam.run/getting-started/)
- [Gleam Language Tour — Basics](https://tour.gleam.run/basics/)
- [Exercism — Gleam Track](https://exercism.org/tracks/gleam)
- [Project Euler — Problem 1](https://projecteuler.net/problem=1)

---

### Глава 3: Функции и пайплайны ✅

#### Оригинал (PureScript)
Функции, записи (row types), address book.

#### Адаптация (Gleam) — ГОТОВО
- Функции как значения первого класса
- **Нет каррирования** в Gleam (в отличие от PS/Haskell/OCaml) — каждая функция принимает все аргументы сразу
- **Захват функций** (function capture): `add(3, _)` — создание частично применённой функции через `_`
- Анонимные функции: `fn(x) { x + 1 }`
- Замыкания (closures)
- **Именованные аргументы** (`label name: String`) — позиционные, но с метками при вызове
- **Сокращённый синтаксис меток**: `greet(name:, greeting:)` когда имя переменной совпадает с меткой
- Pipe-оператор `|>` — идиоматический стиль Gleam
  - Pipe с дополнительными аргументами
  - Pipe с function capture: `|> string.append("hello, ", _)`
- **use-выражения** — синтаксический сахар для callback-ов
- `gleam/function` — `identity`, `compose`, `flip`, `tap`
- `gleam/bool` — `and`, `or`, `negate`, `guard`, `lazy_guard`
- `gleam/order` — `Lt`, `Eq`, `Gt`
- Case-выражения (pattern matching): строки, кортежи, guards, альтернативные паттерны
- Проект: адресная книга

#### Покрытие stdlib
- `gleam/function`: `identity`, `compose`, `flip`, `tap`, `apply1`..`apply3`
- `gleam/bool`: `and`, `or`, `negate`, `guard`, `lazy_guard`, `to_int`, `to_string`, `compare`
- `gleam/order`: `Lt`, `Eq`, `Gt`, `compare`, `reverse`, `min`, `max`, `negate`

#### Упражнения (Exercism coverage)
1. **apply_twice** — применение функции дважды (функции как значения)
   - Exercism: *secrets* (anonymous-functions)
2. **add_exclamation** — конкатенация строк (простые функции)
3. **shout** — pipe-оператор (`string.uppercase |> <> "!"`)
   - Exercism: *high-school-sweetheart* (pipe-operator)
4. **safe_divide** — case-выражение + Result
   - Exercism: *guessing-game* (case-expressions)
5. **fizzbuzz** — pattern matching на нескольких значениях
   - Exercism: *raindrops*

#### Библиотеки
- `gleam_stdlib`

#### Источники
- [Gleam Language Tour — Functions](https://tour.gleam.run/functions/)
- [Gleam Language Tour — Pipelines](https://tour.gleam.run/functions/pipelines/)
- [Gleam Language Tour — Function capture](https://tour.gleam.run/functions/function-captures/)
- [Gleam Language Tour — Label shorthand syntax](https://tour.gleam.run/functions/label-shorthand-syntax/)
- [Gleam Language Tour — Use](https://tour.gleam.run/advanced-features/use/)
- [Gleam Language Tour — Labelled arguments](https://tour.gleam.run/functions/labelled-arguments/)
- [Gleam Language Tour — Case expressions](https://tour.gleam.run/flow-control/case-expressions/)

---

### Глава 4: Типы данных и коллекции ✅

#### Оригинал (PureScript)
ADTs, pattern matching, type constructors + рекурсия, folds, filter, map.

> **Объединяем главы 4 и 5 оригинала**: Gleam проще, можно дать типы
> и коллекции вместе.

#### Адаптация (Gleam) — ГОТОВО
- **Custom types** (пользовательские типы):
  - Типы-перечисления (Color), типы с данными (Shape), типы-записи (User)
  - Pattern matching на записях (позиционный и именованный, `..` для остатка)
  - Доступ к полям (record accessors) — правило одинаковых полей для multi-variant типов
  - Обновление записи: `Person(..person, name: "Bob")`
- **Labelled fields** — именованные поля конструкторов
- **Type aliases**: `type Name = String`
- **Generics**: `type Box(a) { Box(value: a) }`
- **Constants**: `const pi = 3.14159`
- **Кортежи**: `#(1, "hello", True)`
- **Списки**: `[1, 2, 3]`, `[head, ..tail]`
  - `gleam/list` — подробный обзор: трансформация, свёртки, поиск, сортировка, комбинирование, разбиение, key-value, group
- **Dict** (`gleam/dict`): `new`, `from_list`, `insert`, `get`, `map_values`, `filter`, `upsert`
- **Set** (`gleam/set`): `new`, `from_list`, `insert`, `contains`, `union`, `intersection`, `difference`
- **Queue** (`gleam/queue`): `push_back`, `push_front`, `pop_back`, `pop_front`
- **Iterator** (`gleam/iterator`): `unfold`, `iterate`, `take`, ленивые вычисления
- **Проект: модель файловой системы** — тип `FSNode` (File/Directory), рекурсивный обход, все 6 упражнений работают с этим типом

#### Покрытие stdlib
- `gleam/list`: map, filter, flat_map, fold, fold_right, reduce, find, sort, zip, append, flatten, split, take, drop, chunk, group, key_find, each, и др.
- `gleam/dict`: new, from_list, to_list, insert, get, delete, has_key, size, keys, values, map_values, filter, merge, upsert, fold, each
- `gleam/set`: new, from_list, to_list, insert, contains, delete, size, union, intersection, difference, is_subset, filter, fold
- `gleam/queue`: new, from_list, to_list, push_back, push_front, pop_back, pop_front, is_empty, length, reverse
- `gleam/iterator`: from_list, to_list, repeat, range, unfold, iterate, map, filter, fold, take, drop, zip, each

#### Упражнения — FS-тематика (6 штук, все работают с типом FSNode)
1. **total_size** (Лёгкое) — общий размер узла (рекурсия + fold)
   - Exercism: *bird-count* (recursion)
2. **all_files** (Лёгкое) — все файлы в плоский список (flat_map)
   - Exercism: *flatten-array*, *accumulate*
3. **find_by_extension** (Среднее) — фильтрация по расширению (string.ends_with)
   - Exercism: *strain*
4. **largest_file** (Среднее) — самый большой файл (Result, reduce)
   - Exercism: *go* (results)
5. **count_by_extension** (Среднее) — подсчёт по расширениям (list.group, dict)
   - Exercism: *nucleotide-count*, *word-count*
6. **group_by_directory** (Сложное) — группировка файлов по директориям (filter_map, рекурсия)
   - Exercism: *etl*

#### Библиотеки
- `gleam_stdlib`

#### Источники
- [Gleam Language Tour — Custom types](https://tour.gleam.run/data-types/custom-types/)
- [Gleam Language Tour — Records](https://tour.gleam.run/data-types/records/)
- [Gleam Language Tour — Record accessors](https://tour.gleam.run/data-types/record-accessors/)
- [Gleam Language Tour — Record pattern matching](https://tour.gleam.run/data-types/record-pattern-matching/)
- [Gleam Language Tour — Generics](https://tour.gleam.run/data-types/generic-custom-types/)
- [Gleam Language Tour — Lists](https://tour.gleam.run/data-types/lists/)
- [Gleam Language Tour — Tuples](https://tour.gleam.run/data-types/tuples/)
- [HexDocs — gleam/list](https://hexdocs.pm/gleam_stdlib/gleam/list.html)
- [HexDocs — gleam/dict](https://hexdocs.pm/gleam_stdlib/gleam/dict.html)
- [HexDocs — gleam/set](https://hexdocs.pm/gleam_stdlib/gleam/set.html)
- [HexDocs — gleam/iterator](https://hexdocs.pm/gleam_stdlib/gleam/iterator.html)

---

### Глава 5: Рекурсия, свёртки и обработка ошибок

#### Оригинал (PureScript)
Recursion, folds, Applicative validation, lifting, traversal.

> **Объединяем**: рекурсию и обработку ошибок — обе темы сильно связаны
> через `try_fold`, `try_map`, `use <- result.try`.

#### Адаптация (Gleam)
- **Рекурсия** (`let rec` не нужен — Gleam рекурсивен по умолчанию)
- **Хвостовая рекурсия** и оптимизация хвостовых вызовов на BEAM
- Паттерны рекурсии: аккумуляторы, CPS
- **Result(value, error)** — подробно:
  - `Ok(value)`, `Error(reason)`
  - `result.map`, `result.try` (bind), `result.unwrap`, `result.lazy_unwrap`
  - `result.map_error`, `result.flatten`, `result.all`
  - `result.replace`, `result.replace_error`, `result.values`
  - `result.is_ok`, `result.is_error`, `result.partition`
  - **use** + `result.try` — идиоматические цепочки:
    ```gleam
    use user <- result.try(find_user(id))
    use validated <- result.try(validate(user))
    Ok(save(validated))
    ```
- **Option(a)** — подробно:
  - `Some(value)`, `None`
  - `option.map`, `option.flatten`, `option.unwrap`, `option.lazy_unwrap`
  - `option.is_some`, `option.is_none`, `option.to_result`, `option.from_result`
  - `option.all`, `option.values`
- **let assert** — панические утверждения:
  ```gleam
  let assert Ok(value) = might_fail()
  // Крашится если Error
  ```
- Сравнение: `Result` vs `let assert` vs исключения BEAM — когда что
- **Накопление ошибок** — без аппликативных функторов:
  ```gleam
  fn validate_all(validations, input) {
    let errors = list.filter_map(validations, fn(v) {
      case v(input) {
        Ok(_) -> Error(Nil)
        Error(e) -> Ok(e)
      }
    })
    case errors {
      [] -> Ok(input)
      errs -> Error(errs)
    }
  }
  ```
- Проект: валидация формы

#### Покрытие stdlib
- `gleam/result`: все функции (map, try, unwrap, map_error, flatten, all, replace, values, is_ok, is_error, partition, or, lazy_or, lazy_unwrap, nil_error)
- `gleam/option`: все функции

#### Упражнения (Exercism coverage)
1. Рекурсия и хвостовая рекурсия
   - Exercism: *bird-count* (recursion), *pizza-pricing* (tail-call), *list-ops*, *eliuds-eggs*
2. Result и цепочки с use
   - Exercism: *go* (results), *rna-transcription*, *collatz-conjecture*, *grains*, *series*
3. Option
   - Exercism: *role-playing-game* (options), *two-fer*
4. let assert
   - Exercism: *spring-cleaning* (let-assertions)
5. Валидация с накоплением ошибок
   - Exercism: *phone-number*, *isbn-verifier*, *luhn*
6. Рекурсивные структуры данных
   - Exercism: *binary-search-tree*, *pov*, *zipper*

#### Библиотеки
- `gleam_stdlib`

#### Источники
- [Gleam Language Tour — Result](https://tour.gleam.run/data-types/results/)
- [Gleam Language Tour — Use](https://tour.gleam.run/advanced-features/use/)
- [Gleam Language Tour — Let assert](https://tour.gleam.run/advanced-features/let-assert/)
- [HexDocs — gleam/result](https://hexdocs.pm/gleam_stdlib/gleam/result.html)
- [HexDocs — gleam/option](https://hexdocs.pm/gleam_stdlib/gleam/option.html)

---

### Глава 6: Строки, битовые массивы и стандартная библиотека

#### Оригинал (PureScript)
Нет прямого аналога — эта глава покрывает остаток stdlib.

#### Адаптация (Gleam)
- **Строки** (`gleam/string`) — полный обзор (~37 функций):
  - Базовые: `length`, `is_empty`, `reverse`, `compare`
  - Регистр: `lowercase`, `uppercase`, `capitalise`
  - Поиск: `contains`, `starts_with`, `ends_with`
  - Разбиение: `split`, `split_once`, `pop_grapheme`, `to_graphemes`
  - Сборка: `append`, `concat`, `join`, `repeat`
  - Обрезка: `trim`, `trim_start`, `trim_end`, `pad_start`, `pad_end`
  - Слайсы: `slice`, `crop`, `drop_start`, `drop_end`
  - Замена: `replace`
  - Кодировки: `to_utf_codepoints`, `from_utf_codepoints`, `utf_codepoint`, `utf_codepoint_to_int`, `byte_size`
  - Утилиты: `inspect`, `first`, `last`, `to_option`
- **String builder** (`gleam/string_tree`) — эффективная конкатенация
- **Bit arrays** (`gleam/bit_array`) — бинарные данные:
  - `<<>>` синтаксис
  - `from_string`, `to_string`, `byte_size`, `slice`, `concat`
  - `base64_encode`, `base64_decode`, `base64_url_encode`, `base64_url_decode`
  - `base16_encode`, `base16_decode`
  - `inspect`, `is_utf8`, `pad_to_bytes`
  - Паттерн-матчинг на bit arrays:
    ```gleam
    case bits {
      <<header:8, payload:bytes>> -> ...
      <<0xCA, 0xFE, rest:bytes>> -> ...
    }
    ```
- **Bytes builder** (`gleam/bytes_tree`) — эффективная сборка байтов
- **Regex** (`gleam/regex`):
  - `from_string`, `compile`, `check`, `scan`, `split`, `replace`
- **URI** (`gleam/uri`):
  - `parse`, `to_string`, `origin`, `merge`
  - `parse_query`, `query_to_string`
  - `percent_encode`, `percent_decode`, `path_segments`
- **gleam/pair** — утилиты для кортежей: `first`, `second`, `swap`, `map_first`, `map_second`, `new`
- Проект: CLI-утилита для обработки текста (grep-подобная)

#### Упражнения (Exercism coverage)
1. Работа со строками
   - Exercism: *log-levels*, *bob*, *isogram*, *anagram*, *pig-latin*, *roman-numerals*, *diamond*
2. Pattern matching на строках
   - Exercism: *matching-brackets*, *acronym*, *protein-translation*
3. Bit arrays
   - Exercism: *dna-encoding* (bit-arrays), *variable-length-quantity*
4. Regex
   - Exercism: *log-parser* (regular-expressions)
5. Кодирование/декодирование
   - Exercism: *run-length-encoding*, *atbash-cipher*, *rotational-cipher*, *simple-cipher*, *affine-cipher*

#### Библиотеки
- `gleam_stdlib`

#### Источники
- [HexDocs — gleam/string](https://hexdocs.pm/gleam_stdlib/gleam/string.html)
- [Gleam Language Tour — Bit arrays](https://tour.gleam.run/data-types/bit-arrays/)
- [HexDocs — gleam/bit_array](https://hexdocs.pm/gleam_stdlib/gleam/bit_array.html)
- [HexDocs — gleam/regex](https://hexdocs.pm/gleam_stdlib/gleam/regex.html)
- [HexDocs — gleam/uri](https://hexdocs.pm/gleam_stdlib/gleam/uri.html)

---

### Глава 7: FFI, JSON и типобезопасный парсинг

#### Оригинал (PureScript)
FFI → JavaScript, JSON.

#### Адаптация (Gleam)
Gleam имеет уникальную особенность — **двойной FFI**: Erlang + JavaScript.

- **External functions** — вызов Erlang/JS из Gleam:
  ```gleam
  // В .gleam файле
  @external(erlang, "erlang", "system_time")
  pub fn system_time() -> Int

  // В .gleam файле (JS target)
  @external(javascript, "./my_ffi.mjs", "getCurrentTime")
  pub fn current_time() -> Int
  ```
- **External types** — типы из Erlang/JS
- **gleam/dynamic** — работа с нетипизированными данными:
  - `Dynamic` тип
  - `classify` — определение типа
  - Конвертации: `bool`, `string`, `int`, `float`, `bit_array`, `list`, `properties`
- **gleam/dynamic/decode** — типобезопасное декодирование:
  - Примитивы: `string`, `bool`, `int`, `float`, `dynamic`, `bit_array`
  - Структуры: `field`, `optional_field`, `subfield`, `at`, `optionally_at`
  - Коллекции: `list`, `dict`, `optional`
  - Комбинаторы: `map`, `then`, `one_of`, `success`, `failure`
  - Запуск: `run`
  - Рекурсия: `recursive`
  ```gleam
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    decode.success(User(name:, age:))
  }
  ```
- **JSON** (`gleam_json`):
  - Кодирование: `json.object`, `json.string`, `json.int`, `json.array`
  - Декодирование: `json.parse` + `decode`
- **Opaque types** — сокрытие реализации:
  ```gleam
  pub opaque type Email {
    Email(String)
  }
  pub fn parse(s: String) -> Result(Email, Nil) { ... }
  ```
- **Phantom types** — типы-метки:
  ```gleam
  pub opaque type Currency(currency) { Currency(amount: Int) }
  pub type USD
  pub type EUR
  pub fn usd(amount: Int) -> Currency(USD) { Currency(amount) }
  // Нельзя сложить Currency(USD) + Currency(EUR)
  ```
- **gleam_erlang** — привязки к Erlang:
  - `gleam/erlang`: `rescue`, `format_crash`, `get_line`, `priv_directory`, `ensure_all_started`
  - `gleam/erlang/atom`: `Atom`, `from_string`, `to_string`, `from_dynamic`
  - `gleam/erlang/charlist`: `Charlist`, `from_string`, `to_string`
  - `gleam/erlang/node`: `Node`, `self`, `to_atom`, `connect`, `visible`
  - `gleam/erlang/port`: `Port` тип
  - `gleam/erlang/os`: переменные окружения
- Проект: обёртка над Erlang-библиотекой + JSON API

#### Упражнения (Exercism coverage)
1. External functions
   - Exercism: *erlang-extraction* (external-functions, external-types)
2. Dynamic decode для JSON
3. Opaque types
   - Exercism: *secure-treasure-chest* (opaque-types), *circular-buffer*, *custom-set*
4. Phantom types
   - Exercism: *sticker-shop* (phantom-types)

#### Библиотеки
- `gleam_stdlib`
- `gleam_erlang`
- `gleam_json`

#### Источники
- [Gleam Language Tour — Externals](https://tour.gleam.run/advanced-features/externals/)
- [Gleam Language Tour — Opaque types](https://tour.gleam.run/advanced-features/opaque-types/)
- [HexDocs — gleam/dynamic/decode](https://hexdocs.pm/gleam_stdlib/gleam/dynamic/decode.html)
- [HexDocs — gleam_json](https://hexdocs.pm/gleam_json/)
- [HexDocs — gleam_erlang](https://hexdocs.pm/gleam_erlang/)
- [Gleam for Erlang users — Cheatsheet](https://gleam.run/cheatsheets/gleam-for-erlang-users/)

---

### Глава 8: Процессы и OTP

> **Уникальная глава** — ни в Haskell, ни в OCaml версиях нет аналога.

#### Оригинал (PureScript)
Effect monad + Aff/async.

#### Адаптация (Gleam)
Самая «BEAM-специфичная» глава. Gleam на BEAM даёт доступ к
одной из самых зрелых моделей конкурентности в индустрии.

**Процессы BEAM** (`gleam/erlang/process`):
- Всё — процесс. Процессы легковесные (~300 байт)
- `spawn` — создание процесса
- `Subject` — типизированный канал для отправки сообщений
- `Selector` — мультиплексирование приёма сообщений
- `send` — отправка сообщения
- `receive` — приём с таймаутом
- `sleep` — пауза
- `monitor` / `demonitor` — мониторинг процессов
- `link` — связывание процессов
- `trap_exits` — перехват завершения
- `selecting` / `selecting_process_down` — подписка на события
- `Timer` — периодические действия (`send_after`, `cancel_timer`)

**Акторы** (`gleam/otp/actor`):
- Actor = процесс + состояние + обработчик сообщений
- API:
  ```gleam
  type Message {
    Add(Int)
    Get(Subject(Int))
  }

  fn handle_message(message: Message, state: Int) -> actor.Next(Message, Int) {
    case message {
      Add(i) -> actor.continue(state + i)
      Get(reply) -> {
        process.send(reply, state)
        actor.continue(state)
      }
    }
  }

  pub fn main() {
    let assert Ok(actor) =
      actor.new(0)
      |> actor.on_message(handle_message)
      |> actor.start

    actor.send(actor, Add(5))
    actor.send(actor, Add(3))
    let result = actor.call(actor, Get(_), 1000)
    // result == 8
  }
  ```
- `actor.new` — создание спецификации
- `actor.on_message` — установка обработчика
- `actor.start` — запуск
- `actor.send` — fire-and-forget сообщение
- `actor.call` — запрос-ответ (sync)
- `actor.continue` — продолжить с новым состоянием
- `actor.stop` — завершить актора
- Инициализация: `actor.ready`, `actor.with_selector`

**Супервизоры** (`gleam/otp/supervisor`):
- `supervisor.new` — создание
- `supervisor.add` — добавление дочерних процессов
- `supervisor.start` — запуск дерева
- Стратегии перезапуска: one-for-one
- «Let it crash» — философия

**OTP Deep Dive**:
- Процессное дерево приложения
- `gleam/erlang/application`: `ensure_all_started`
- `gleam/otp/system`: `StatusInfo`, `SystemMessage`, `GetState`, `GetStatus`
- Горячая перезагрузка (hot code reload)
- Распределённые системы: `gleam/erlang/node`
- Сравнение с Go (goroutines), Rust (tokio), OCaml (Eio)

- Проект: конкурентный счётчик с супервизором

#### Упражнения
1. Простой актор-счётчик (send/call)
2. Пул воркеров: N акторов обрабатывают задачи из общей очереди
3. Producer-consumer: один актор генерирует данные, другой обрабатывает
4. Дерево супервизоров: перезапуск при крашах

#### Библиотеки
- `gleam_erlang`
- `gleam_otp`

#### Источники
- [HexDocs — gleam_otp/actor](https://hexdocs.pm/gleam_otp/gleam/otp/actor.html)
- [HexDocs — gleam_otp/supervisor](https://hexdocs.pm/gleam_otp/gleam/otp/supervisor.html)
- [HexDocs — gleam_erlang/process](https://hexdocs.pm/gleam_erlang/gleam/erlang/process.html)
- [OTP Deep Dive (coddykit)](https://www.coddykit.com/pages/blog-detail?id=512482)
- [Gleam OTP — GitHub](https://github.com/gleam-lang/otp)
- [Gleam Actors 101](https://www.tcrez.dev/2025-07-13-gleam-otp-101.html)
- [Learn OTP with Gleam](https://github.com/bcpeinhardt/learn_otp_with_gleam)
- [Fault tolerant Gleam](https://gleam.run/news/fault-tolerant-gleam/)

---

### Глава 9: Тестирование

#### Оригинал (PureScript)
QuickCheck-style property testing.

#### Адаптация (Gleam)
Расширяем тему: не только property-testing, но весь спектр тестирования.

- **gleeunit** — стандартный тестовый раннер:
  ```gleam
  import gleeunit/should

  pub fn add_test() {
    add(1, 2)
    |> should.equal(3)
  }
  ```
  - `should.equal`, `should.not_equal`
  - `should.be_ok`, `should.be_error`
  - `should.be_true`, `should.be_false`
  - `should.fail`

- **Property-based testing** (`qcheck`):
  - Генераторы: `qcheck.int`, `qcheck.string`, `qcheck.list`, `qcheck.float`
  - Пользовательские генераторы
  - Shrinking — автоматическое уменьшение контрпримеров
  - Свойства и законы
  ```gleam
  import qcheck

  pub fn reverse_involution_test() {
    qcheck.run(
      config: qcheck.default_config(),
      generator: qcheck.list(qcheck.int()),
      property: fn(xs) {
        list.reverse(list.reverse(xs)) == xs
      },
    )
  }
  ```

- **Snapshot testing** (`birdie`):
  - Запись «снимков» вывода функций
  - Визуальные диффы при изменениях
  - CLI для интерактивного ревью: accept/reject/skip
  ```gleam
  import birdie

  pub fn pretty_print_test() {
    format_user(alice)
    |> birdie.snap("format alice")
  }
  ```

- Организация тестов: test/, тестовые модули
- CI: `gleam test` в GitHub Actions
- Проект: тестирование структуры данных (сбалансированное дерево или очередь)

#### Упражнения
1. Unit-тесты для функций из предыдущих глав
2. Property: `list.reverse` — инволюция, сохранение длины
3. Property: `list.sort` — идемпотентность, упорядоченность
4. Property: encode/decode roundtrip (JSON сериализация)
5. Snapshot: pretty-print пользовательского типа

#### Библиотеки
- `gleeunit` (или `startest`)
- `qcheck`
- `birdie`

#### Источники
- [Testing can be fun, actually (Giacomo Cavalieri)](https://giacomocavalieri.me/writing/testing-can-be-fun-actually)
- [qcheck — GitHub](https://github.com/mooreryan/gleam_qcheck)
- [HexDocs — qcheck](https://hexdocs.pm/qcheck/)
- [birdie — GitHub](https://github.com/giacomocavalieri/birdie)
- [HexDocs — birdie](https://hexdocs.pm/birdie/)
- [HexDocs — gleeunit](https://hexdocs.pm/gleeunit/)

---

### Глава 10: Веб-разработка с Wisp

#### Оригинал (PureScript)
Canvas graphics (HTML5 Canvas) → React/Halogen.

> **Замена**: вместо графики — веб-разработка. Как глава 18 OCaml-версии
> (Dream), но с Wisp, Squirrel и pog.

#### Адаптация (Gleam)
- **Wisp** — практичный веб-фреймворк:
  - Обработчики: `fn(Request) -> Response`
  - Middleware через `use`:
    ```gleam
    pub fn handle_request(req: Request, ctx: Context) -> Response {
      use <- wisp.log_request(req)
      use <- wisp.rescue_crashes
      use req <- wisp.handle_head(req)
      case wisp.path_segments(req) {
        [] -> home_page(req, ctx)
        ["api", "todos"] -> todos_handler(req, ctx)
        ["api", "todos", id] -> todo_handler(req, ctx, id)
        _ -> wisp.not_found()
      }
    }
    ```
  - Маршрутизация через pattern matching (не DSL!)
  - Встроенный middleware: `wisp.log_request`, `wisp.rescue_crashes`, `wisp.handle_head`, `wisp.serve_static`
  - Body parsing: `wisp.require_json`, `wisp.require_string_body`
  - Ответы: `wisp.ok()`, `wisp.created()`, `wisp.not_found()`, `wisp.bad_request()`, `wisp.json_response`
  - Query params: `wisp.get_query`
  - Формы: `wisp.require_form`
- **Mist** — HTTP-сервер (transport layer для Wisp)
- **gleam_http** — типы Request/Response
- **gleam_json** — сериализация/десериализация
- **pog** — PostgreSQL клиент:
  ```gleam
  let db = pog.default_config()
    |> pog.host("localhost")
    |> pog.database("todos")
    |> pog.connect
  ```
- **Squirrel** — type-safe SQL codegen:
  - Пишешь `.sql` файл в `src/app/sql/`
  - Запускаешь `gleam run -m squirrel`
  - Получаешь типизированные функции в `src/app/sql.gleam`
  ```sql
  -- src/app/sql/list_todos.sql
  SELECT id, title, completed FROM todos ORDER BY id
  ```
  Генерирует:
  ```gleam
  pub fn list_todos(db: pog.Connection) -> Result(List(ListTodosRow), pog.QueryError)
  ```
- Проект: **TODO API** (полноценный CRUD):
  - REST endpoints: GET/POST/PUT/DELETE /todos
  - PostgreSQL через pog + Squirrel
  - JSON сериализация
  - Middleware: логирование, CORS
  - Обработка ошибок
  - Пагинация и фильтрация

#### Упражнения
1. (Лёгкое) Health-check endpoint: `GET /health` → `{"status": "ok"}`
2. (Среднее) Middleware для замера времени обработки запроса
3. (Среднее) Пагинация: `GET /todos?page=2&per_page=10`
4. (Сложное) Auth middleware: проверка Bearer-токена в заголовке Authorization

#### Библиотеки
- `wisp`
- `mist`
- `gleam_http`
- `gleam_json`
- `pog`
- `squirrel` (dev dependency для codegen)

#### Источники
- [Wisp — A practical web framework](https://gleam-wisp.github.io/wisp/)
- [HexDocs — wisp](https://hexdocs.pm/wisp/)
- [Gleam web app tutorial (Andrey Fadeev)](https://blog.andreyfadeev.com/p/gleam-web-application-development-tutorial)
- [learn_gleam_todo — GitHub](https://github.com/andfadeev/learn_gleam_todo)
- [Squirrel — GitHub](https://github.com/giacomocavalieri/squirrel)
- [HexDocs — pog](https://hexdocs.pm/pog/)
- [HexDocs — gleam_json](https://hexdocs.pm/gleam_json/)

---

### Глава 11: Фронтенд с Lustre

#### Оригинал (PureScript)
Canvas graphics / Halogen.

> **Замена**: Lustre — Elm-архитектура на Gleam,
> работает на JavaScript-таргете + server components на BEAM.

#### Адаптация (Gleam)
- **Elm-архитектура (TEA)**: Model → View → Update
- **lustre** — основной модуль:
  - `lustre.application` — полное приложение с эффектами
  - `lustre.simple` — приложение без эффектов
  - `lustre.element` — статический HTML (SSR)
  - `lustre.component` — Custom Elements (Web Components)
  - `lustre.start` — запуск приложения
- **lustre/element** — виртуальный DOM:
  - `Element(msg)` — основной тип
  - `element`, `text`, `fragment`, `none`
  - `map` — преобразование сообщений
- **lustre/element/html** — HTML-элементы:
  - `html`, `head`, `body`, `div`, `p`, `h1`..`h6`
  - `button`, `input`, `form`, `select`, `option`
  - `ul`, `ol`, `li`, `table`, `tr`, `td`
  - `a`, `img`, `span`, `script`, `style`
- **lustre/attribute** — атрибуты:
  - `attribute`, `property`, `class`, `classes`, `id`
  - `style`, `styles`, `value`, `checked`, `disabled`
  - `src`, `href`, `type_`, `placeholder`, `name`
  - `on` — обработчики событий через атрибуты
- **lustre/event** — обработка событий:
  - `on_click`, `on_input`, `on_submit`, `on_check`
  - `on_mouse_down`, `on_mouse_up`, `on_mouse_move`
  - `on_keydown`, `on_keyup`, `on_keypress`
  - `on` — произвольные события с декодером
  - `emit` — отправка событий из компонентов
  - `prevent_default`, `stop_propagation`
  - `debounce`, `throttle`
- **lustre/effect** — побочные эффекты:
  - `Effect(msg)` тип
  - `effect.none` — нет эффекта
  - `effect.batch` — группировка эффектов
  - `effect.from` — создание кастомного эффекта
  - HTTP-запросы через `lustre_http`
- **Компоненты** (`lustre/component`):
  - Custom Elements + Shadow DOM
  - `on_attribute_change`, `on_property_change`
  - Slots, form-associated elements
- **Server Components** (`lustre/server_component`):
  - Компоненты на сервере, рендеринг через WebSocket/SSE
  - ~10kb клиентский рантайм
  - Real-time обновления без перезагрузки страницы
  - Идеально для: чат, дашборды, совместное редактирование
- Проект: **интерактивный TODO** (как в Wisp-главе, но с UI):
  - Lustre-приложение как фронтенд
  - Взаимодействие с TODO API из главы 10
  - Реактивные обновления

#### Упражнения
1. (Лёгкое) Счётчик: кнопки +/- и отображение числа
2. (Среднее) Форма: input + validation + submit
3. (Среднее) Список TODO с добавлением/удалением/отметкой
4. (Сложное) Server component: real-time обновления списка между клиентами

#### Библиотеки
- `lustre`
- `lustre_http` (для HTTP-запросов)

#### Источники
- [Lustre — GitHub](https://github.com/lustre-labs/lustre)
- [HexDocs — lustre](https://hexdocs.pm/lustre/)
- [Lustre Quickstart](https://hexdocs.pm/lustre/guide/01-quickstart.html)
- [Building your first Gleam web app with Wisp and Lustre](https://gleaming.dev/articles/building-your-first-gleam-web-app/)

---

### Глава 12: Telegram-бот с Telega

> **Уникальная глава** — демонстрация реального проекта на Gleam,
> объединяющего OTP, Wisp, JSON и паттерны проектирования.

#### Адаптация (Gleam)
- **Telega** — библиотека для Telegram-ботов на Gleam
- **Архитектура бота**:
  - `telega.new` — создание бота с конфигурацией
  - `telega.with_secret_token` — безопасность webhook
  - Интеграция с Wisp через адаптер
- **Router** — маршрутизация обновлений:
  ```gleam
  let router =
    router.new("my_bot")
    |> router.on_command("start", handle_start)
    |> router.on_command("help", handle_help)
    |> router.on_any_text(handle_text)
    |> router.on_photo(handle_photo)
    |> router.fallback(handle_unknown)
  ```
  - Приоритет маршрутов: команды → callback queries → custom → media → text → fallback
  - **Pattern matching** на текст:
    ```gleam
    router
    |> router.on_text(Exact("hello"), handle_hello)
    |> router.on_text(Prefix("search:"), handle_search)
    |> router.on_text(Contains("help"), handle_help)
    |> router.on_text(Suffix("?"), handle_question)
    ```
  - **Callback queries**:
    ```gleam
    router
    |> router.on_callback(Prefix("page:"), handle_pagination)
    |> router.on_callback(Exact("cancel"), handle_cancel)
    ```
- **Middleware**:
  ```gleam
  router
  |> router.use_middleware(router.with_logging)
  |> router.use_middleware(auth_middleware)
  |> router.use_middleware(rate_limit_middleware)
  ```
  - Встроенный: `with_logging`, `with_filter`, `with_recovery`
- **Композиция роутеров**:
  - `router.merge` — объединение маршрутов
  - `router.compose` — последовательная проверка
  - `router.scope` — фильтрация по предикату (напр. только админы)
- **Telega Client** (`telega/client`) — прямой доступ к Telegram API:
  - `client.new(token)` — создание клиента
  - Opaque type `TelegramClient` с настройками: retry, custom API URL, rate limiting
- **Reply** (`telega/reply`) — отправка ответов
- **Интеграция с Wisp** (`telega/adapters/wisp`):
  ```gleam
  pub fn handle_request(bot: Telega, req: Request) -> Response {
    use <- telega_wisp.handle_bot(telega: bot, req: req)
    // ... обычная маршрутизация Wisp
  }
  ```
- **Error handling**: `with_catch_handler` для graceful degradation
- Проект: **полноценный Telegram-бот**:
  - Команды: /start, /help, /todo
  - Inline-клавиатура с callback queries
  - Управление TODO-списком через Telegram
  - Persistent storage через PostgreSQL (из главы 10)
  - Middleware: логирование, обработка ошибок

#### Упражнения
1. (Лёгкое) Эхо-бот: повторяет любой текст
2. (Среднее) Бот с командами и inline-клавиатурой
3. (Среднее) Middleware для rate-limiting
4. (Сложное) Полноценный TODO-бот с БД и Wisp webhook

#### Библиотеки
- `telega`
- `wisp` (для webhook)
- `mist`
- `pog` (для хранения данных)
- `gleam_json`

#### Источники
- [HexDocs — telega](https://hexdocs.pm/telega/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Wisp — GitHub](https://github.com/gleam-wisp/wisp)

---

## Покрытие Exercism

### Exercism Gleam Track: 36 концептов, 122 упражнения

Книга покрывает **все 36 концептов** Exercism Gleam track:

| Концепт | Глава | Exercism-упражнения |
|---------|-------|---------------------|
| basics | Ch2 | lasagna |
| bools | Ch3 | pacman-rules |
| ints | Ch2 | bettys-bike-shop, difference-of-squares |
| floats | Ch2 | bettys-bike-shop |
| modules | Ch2 | bettys-bike-shop |
| strings | Ch6 | log-levels |
| case-expressions | Ch3 | guessing-game |
| custom-types | Ch4 | valentines-day |
| tuples | Ch4 | tisbury-treasure-hunt |
| lists | Ch4 | tracks-on-tracks-on-tracks |
| labelled-fields | Ch4 | bandwagoner |
| recursion | Ch5 | bird-count |
| tail-call-optimisation | Ch5 | pizza-pricing |
| anonymous-functions | Ch3 | secrets |
| pipe-operator | Ch3 | high-school-sweetheart |
| generics | Ch4 | treasure-chest |
| results | Ch5 | go |
| dicts | Ch4 | high-score-board |
| type-aliases | Ch4 | high-score-board |
| orders | Ch3 | weather-ranking |
| constants | Ch4 | weather-ranking |
| labelled-arguments | Ch3 | wine-cellar |
| sets | Ch4 | gotta-snatch-em-all |
| options | Ch5 | role-playing-game |
| let-assertions | Ch5 | spring-cleaning |
| bit-arrays | Ch6 | dna-encoding |
| iterators | Ch4 | boutique-inventory |
| nil | Ch5 | newsletter |
| io | Ch6 | newsletter |
| opaque-types | Ch7 | secure-treasure-chest |
| phantom-types | Ch7 | sticker-shop |
| external-functions | Ch7 | erlang-extraction |
| external-types | Ch7 | erlang-extraction |
| use-expressions | Ch3 | expert-experiments |
| queues | Ch4 | magician-in-training |
| regular-expressions | Ch6 | log-parser |

### Практические упражнения по главам

Каждая глава включает 4-8 упражнений, многие из которых адаптированы
из Exercism. Всего книга покрывает **~70 из 122 Exercism-упражнений**
(все concept exercises + наиболее показательные practice exercises).

---

## Покрытие стандартной библиотеки

### gleam_stdlib — полное покрытие

| Модуль | Глава | Покрытие |
|--------|-------|----------|
| `gleam/int` | Ch2 | Полное |
| `gleam/float` | Ch2 | Полное |
| `gleam/bool` | Ch3 | Полное |
| `gleam/order` | Ch3 | Полное |
| `gleam/function` | Ch3 | Полное |
| `gleam/list` | Ch4 | Полное (~65 функций) |
| `gleam/dict` | Ch4 | Полное |
| `gleam/set` | Ch4 | Полное |
| `gleam/queue` | Ch4 | Полное |
| `gleam/iterator` | Ch4 | Полное |
| `gleam/pair` | Ch6 | Полное |
| `gleam/result` | Ch5 | Полное |
| `gleam/option` | Ch5 | Полное |
| `gleam/string` | Ch6 | Полное (~37 функций) |
| `gleam/string_tree` | Ch6 | Полное |
| `gleam/bit_array` | Ch6 | Полное |
| `gleam/bytes_tree` | Ch6 | Полное |
| `gleam/regex` | Ch6 | Полное |
| `gleam/uri` | Ch6 | Полное |
| `gleam/io` | Ch2, Ch6 | Полное |
| `gleam/dynamic` | Ch7 | Полное |
| `gleam/dynamic/decode` | Ch7 | Полное |

### gleam_erlang — полное покрытие

| Модуль | Глава | Покрытие |
|--------|-------|----------|
| `gleam/erlang` | Ch7, Ch8 | Полное |
| `gleam/erlang/process` | Ch8 | Полное |
| `gleam/erlang/atom` | Ch7 | Полное |
| `gleam/erlang/charlist` | Ch7 | Полное |
| `gleam/erlang/node` | Ch8 | Полное |
| `gleam/erlang/port` | Ch7 | Полное |
| `gleam/erlang/os` | Ch7 | Полное |
| `gleam/erlang/application` | Ch8 | Полное |

### gleam_otp — полное покрытие

| Модуль | Глава | Покрытие |
|--------|-------|----------|
| `gleam/otp/actor` | Ch8 | Полное |
| `gleam/otp/supervisor` | Ch8 | Полное |
| `gleam/otp/system` | Ch8 | Полное |

---

## Стратегия перевода

### Терминология

| Русский | English | Примечание |
|---------|---------|-----------|
| пользовательский тип | custom type | — |
| именованное поле | labelled field | — |
| именованный аргумент | labelled argument | — |
| пайплайн | pipeline | оператор `\|>` |
| use-выражение | use expression | — |
| генерик | generic | параметрический полиморфизм |
| непрозрачный тип | opaque type | — |
| фантомный тип | phantom type | — |
| сопоставление с образцом | pattern matching | case |
| свёртка | fold | — |
| хвостовая рекурсия | tail call optimisation | — |
| актор | actor | OTP |
| супервизор | supervisor | OTP |
| процесс | process | BEAM |
| субъект | subject | gleam_erlang — типизированный канал |
| селектор | selector | gleam_erlang — мультиплексор сообщений |
| промежуточный обработчик | middleware | — |
| обработчик | handler | — |
| маршрутизация | routing | — |
| снимок (тест) | snapshot test | birdie |

### Принципы перевода

1. **Код на английском** — имена функций, типов, модулей
2. **Комментарии на русском** — пояснения в коде
3. **Текст на русском** — весь нарративный текст
4. **Термины** — русские с английскими в скобках при первом упоминании
5. **Не калькировать** — адаптировать примеры под идиоматический Gleam

---

## Порядок работы

### Фаза 0: Инфраструктура ✅

- [x] Создать структуру каталогов
- [x] Настроить gleam.toml (каждая глава — отдельный проект)
- [x] Настроить mdBook (book.toml)
- [x] Создать заглушки глав (text/chapter01..12.md)
- [x] Создать все exercise-проекты (exercises/chapter01..12)
- [x] Создать скрипты (build-all.sh, test-all.sh, prepare-exercises.sh)
- [x] Написать TRANSITION_PLAN.md

### Фаза 1: Основы (главы 1-4) ✅

- [x] Глава 1: Введение (только текст, без упражнений)
- [x] Глава 2: Начало работы (текст + упражнения)
- [x] Глава 3: Функции и пайплайны (текст + упражнения)
- [x] Глава 4: Типы данных и коллекции (текст + упражнения, FS-проект)

### Фаза 2: Продвинутые основы (главы 5-7) ✅

- [x] Глава 5: Рекурсия, свёртки и обработка ошибок (текст + 7 упражнений, ROP, panic, let assert, MISU)
- [x] Глава 6: Строки, битовые массивы и стандартная библиотека (текст + 5 упражнений)
- [x] Глава 7: FFI, JSON и типобезопасный парсинг (текст + 8 упражнений, opaque/phantom types, PokeAPI)

### Фаза 3: BEAM и OTP (главы 8-9)

- [ ] Глава 8: Процессы и OTP
- [ ] Глава 9: Тестирование

### Фаза 4: Практические проекты (главы 10-12)

- [ ] Глава 10: Веб-разработка с Wisp
- [ ] Глава 11: Фронтенд с Lustre
- [ ] Глава 12: Telegram-бот с Telega

### Фаза 5: Финализация

- [ ] Вычитка и редактура всех глав
- [ ] Проверка всех упражнений
- [ ] CI (GitHub Actions)
- [ ] README.md

---

## Принятые решения

### Gleam >= 1.6.0, OTP >= 27.0

Требуем современные версии для доступа к последним возможностям
языка и runtime. Gleam активно развивается, старые версии быстро
устаревают.

### 12 глав вместо 14/18

Gleam намеренно минималистичен — нет type classes, GADTs, effect handlers,
monad transformers. Вместо «растягивания» материала делаем компактную
книгу с фокусом на практику. Три финальных главы — полноценные проекты.

### Каждая глава — отдельный Gleam-проект

Каждая глава в `exercises/chapterXX/` — отдельный проект с собственным
`gleam.toml`. Это позволяет:
- Независимые зависимости для каждой главы
- Студенты могут работать с одной главой, не устанавливая все зависимости
- Простое добавление новых глав

### Структура упражнений

```
exercises/chapterXX/
├── gleam.toml             # Проект и зависимости
├── src/
│   └── chapterXX.gleam    # Код примеров из текста
├── test/
│   ├── chapterXX_test.gleam  # Тесты
│   └── my_solutions.gleam    # Шаблон для студента
└── no-peeking/
    └── solutions.gleam       # Референсные решения
```

Студенты:
1. Читают `src/*.gleam` (примеры из текста)
2. Заполняют `test/my_solutions.gleam`
3. Запускают `gleam test`
4. Подсматривают в `no-peeking/solutions.gleam` если застряли

### Фокус на Exercism

Максимальное покрытие Exercism Gleam track — это даёт студентам:
- Знакомые задачи, если они уже решали их на других языках
- Возможность продолжить практику на Exercism после книги
- Проверку через внешнюю платформу

### Wisp + Lustre + Telega — три проекта

Три финальных главы строят реальные приложения:
1. **Wisp** — REST API с PostgreSQL (бэкенд)
2. **Lustre** — интерактивный UI (фронтенд)
3. **Telega** — Telegram-бот (full-stack: OTP + Wisp + DB)

Это показывает полный спектр возможностей Gleam и даёт студентам
готовые шаблоны для своих проектов.

### Squirrel для SQL

Вместо ручного написания SQL-запросов используем Squirrel —
type-safe codegen из `.sql` файлов. Это:
- Показывает уникальную экосистему Gleam
- Даёт compile-time безопасность SQL
- Демонстрирует паттерн code generation

### gleeunit как основной тестовый фреймворк

Стандартный и самый распространённый. `qcheck` для property-testing
и `birdie` для snapshot-testing добавляются в главе 9.
