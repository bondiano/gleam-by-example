# Рекурсия, свёртки и обработка ошибок

> «Сделайте невозможные состояния невыразимыми» — Ричард Фельдман

<!-- toc -->

## Цели главы

В этой главе мы:

- Научимся писать рекурсивные функции и оптимизировать их хвостовыми вызовами
- Поймём свёртки как обобщение рекурсии
- Разберём философию «ошибки как значения»
- Изучим `Result` и `Option` — два основных типа обработки ошибок
- Освоим `use` + `result.try` для идиоматических цепочек
- Узнаем про `panic` и `let assert` — когда их использовать
- Познакомимся с Railway-Oriented Programming
- Научимся накапливать ошибки вместо остановки на первой

## Рекурсия

Рекурсия — основной способ итерации в функциональных языках. Функция вызывает сама себя, обрабатывая на каждом шаге часть данных.

### Базовая рекурсия

Простейший пример — факториал:

```gleam
pub fn factorial(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> n * factorial(n - 1)
  }
}
```

Каждая рекурсивная функция имеет:

- **Базовый случай** — условие завершения (`n == 0`)
- **Рекурсивный случай** — вызов с «уменьшенной» задачей (`n - 1`)

### Pattern matching на списках

Рекурсия особенно естественна для работы со списками. Список можно разобрать на голову и хвост:

```gleam
pub fn sum(xs: List(Int)) -> Int {
  case xs {
    [] -> 0
    [first, ..rest] -> first + sum(rest)
  }
}

// sum([1, 2, 3])
// = 1 + sum([2, 3])
// = 1 + 2 + sum([3])
// = 1 + 2 + 3 + sum([])
// = 1 + 2 + 3 + 0
// = 6
```

Паттерн `[first, ..rest]` разбивает список: `first` — первый элемент, `rest` — остаток. Пустой список `[]` — базовый случай.

### Множественный pattern matching

Можно рекурсивно обходить несколько списков одновременно:

```gleam
pub fn zip_with(
  xs: List(a),
  ys: List(b),
  f: fn(a, b) -> c,
) -> List(c) {
  case xs, ys {
    [], _ | _, [] -> []
    [x, ..rest_x], [y, ..rest_y] -> [
      f(x, y),
      ..zip_with(rest_x, rest_y, f)
    ]
  }
}

zip_with([1, 2, 3], [10, 20, 30], fn(a, b) { a + b })
// [11, 22, 33]
```

Функция `zip_with` одновременно обходит два списка и применяет переданную функцию к парам элементов, останавливаясь когда один из списков заканчивается.

## Хвостовая рекурсия

Обычная (body) рекурсия наращивает стек вызовов: каждый вызов ждёт возврата следующего и затем выполняет дополнительную операцию.

**Хвостовая рекурсия** — когда рекурсивный вызов стоит в **хвостовой позиции**: результат вызова сразу возвращается, без дополнительных операций. BEAM (Erlang VM) оптимизирует такие вызовы — они выполняются в постоянной памяти стека, как цикл.

### Аккумуляторы

Для преобразования обычной рекурсии в хвостовую используют **аккумулятор** — параметр, накапливающий промежуточный результат:

```gleam
// Обычная рекурсия (НЕ хвостовая)
pub fn sum(xs: List(Int)) -> Int {
  case xs {
    [] -> 0
    [first, ..rest] -> first + sum(rest)  // ← сложение ПОСЛЕ рекурсии
  }
}

// Хвостовая рекурсия (TCO-оптимизируемая)
pub fn sum_tail(xs: List(Int)) -> Int {
  sum_loop(xs, 0)
}

fn sum_loop(xs: List(Int), acc: Int) -> Int {
  case xs {
    [] -> acc
    [first, ..rest] -> sum_loop(rest, acc + first)  // ← хвостовой вызов
  }
}
```

В `sum_loop` рекурсивный вызов — последняя операция. Сложение `acc + first` выполняется **до** вызова, а не после. BEAM превращает это в эффективный цикл.

Паттерн: публичная функция + приватный цикл с аккумулятором:

```gleam
pub fn factorial_tail(n: Int) -> Int {
  factorial_loop(n, 1)
}

fn factorial_loop(n: Int, acc: Int) -> Int {
  case n {
    0 -> acc
    _ -> factorial_loop(n - 1, n * acc)
  }
}
```

Паттерн «публичная функция + приватный цикл» скрывает аккумулятор от пользователя: `factorial_tail` предоставляет удобный интерфейс, а `factorial_loop` содержит хвостово-рекурсивную реализацию с накапливаемым результатом.

### Мифы о хвостовой рекурсии

Распространённое заблуждение: «хвостовая рекурсия всегда быстрее обычной». На современном BEAM это **не так**. Согласно [Erlang Efficiency Guide](https://www.erlang.org/docs/22/efficiency_guide/myths):

> Body-recursive function generally uses the **same amount of memory** as a tail-recursive function. It is generally **not possible to predict** whether the tail-recursive or the body-recursive version will be faster.

Исторически (до Erlang R12B) хвостовая рекурсия давала значительный выигрыш. Современный компилятор устранил большую часть разницы.

**Когда хвостовая рекурсия действительно быстрее:**

- Аккумулирование простого значения без создания промежуточных структур (суммирование, подсчёт)
- Случаи, когда не нужен `list.reverse` в конце (reverse сводит на нет экономию)

**Когда разницы нет:**

- Построение списка (хвостовая версия требует `list.reverse` в конце — то же количество операций)
- Обработка коротких и средних списков

Рекомендация из Erlang Efficiency Guide: **используйте тот вариант, который делает код чище** — обычно это body-рекурсия.

### Когда хвостовая рекурсия обязательна?

Несмотря на развенчанные мифы, есть случаи, когда хвостовая рекурсия **необходима**:

- **Бесконечные циклы** — серверы, акторы, циклы обработки сообщений (глава 8). Без TCO стек будет расти бесконечно
- **Потоковая обработка** — чтение из файла или сокета строка за строкой, когда объём данных неизвестен заранее
- **Аккумулирование скалярного результата** — сумма, максимум, подсчёт — здесь хвостовая рекурсия действительно эффективнее

Для большинства функций над списками конечной длины выбирайте вариант, который проще читать и поддерживать.

## Свёртки как обобщение рекурсии

Большинство рекурсивных функций на списках следуют одному паттерну: пройти список, накапливая результат. Этот паттерн абстрагирован в **свёртку** (fold).

### list.fold

`list.fold` — свёртка слева с начальным значением:

```gleam
import gleam/list

// Сумма элементов
list.fold([1, 2, 3, 4], 0, fn(acc, x) { acc + x })
// 10

// Конкатенация строк
list.fold(["hello", " ", "world"], "", fn(acc, s) { acc <> s })
// "hello world"

// Подсчёт элементов
list.fold([True, False, True, True], 0, fn(acc, x) {
  case x {
    True -> acc + 1
    False -> acc
  }
})
// 3
```

`fold` принимает начальное значение аккумулятора и функцию `fn(acc, element) -> acc`. По сути, `fold` — это хвостовая рекурсия, вынесенная в библиотеку.

### list.reduce

`list.reduce` — свёртка без начального значения. Первый элемент становится аккумулятором:

```gleam
list.reduce([1, 2, 3], fn(acc, x) { acc + x })
// Ok(6)

list.reduce([], fn(acc, x) { acc + x })
// Error(Nil) — пустой список!
```

`reduce` возвращает `Result`, потому что для пустого списка нет начального значения.

### list.fold_right

`list.fold_right` — свёртка справа (от конца к началу):

```gleam
list.fold_right([1, 2, 3], [], fn(x, acc) { [x * 10, ..acc] })
// [10, 20, 30]
```

Обратите внимание: у `fold_right` порядок аргументов функции — `fn(element, acc)`, а не `fn(acc, element)`.

### list.try_fold

`list.try_fold` — свёртка, которая может остановиться при ошибке:

```gleam
import gleam/int

pub fn sum_strings(xs: List(String)) -> Result(Int, Nil) {
  list.try_fold(xs, 0, fn(acc, s) {
    case int.parse(s) {
      Ok(n) -> Ok(acc + n)
      Error(_) -> Error(Nil)
    }
  })
}

sum_strings(["1", "2", "3"])  // Ok(6)
sum_strings(["1", "abc", "3"])  // Error(Nil)
```

`try_fold` останавливается на первом `Error` — не обрабатывая остальные элементы.

## Ошибки как значения

В Gleam нет механизма исключений. Ошибки — это **обычные значения**, которые возвращаются из функций. Это осознанное решение, а не ограничение.

### Почему не исключения?

Исключения (как в Java, Python, JavaScript) создают проблемы:

1. **Невидимость**: по сигнатуре функции не видно, может ли она «упасть»
2. **Нелокальность**: исключение летит сквозь стек вызовов, пока кто-то его не поймает
3. **Хрупкость**: забытый `try/catch` — и программа крашится

В Gleam каждая функция, которая может завершиться неудачей, явно возвращает `Result`:

```gleam
// Сигнатура говорит ВСЁ о поведении функции
pub fn parse(s: String) -> Result(Int, String)

// Вызывающий код ОБЯЗАН обработать оба случая
case parse("42") {
  Ok(n) -> io.println("Число: " <> int.to_string(n))
  Error(msg) -> io.println("Ошибка: " <> msg)
}
```

Компилятор гарантирует: если функция может вернуть ошибку, вызывающий код это увидит и обработает.

## Два вида ошибок

Gleam различает два вида ошибок:

### Ожидаемые ошибки (expected errors)

Ситуации, которые **нормальны** для работы программы:

- Пользователь ввёл некорректные данные
- Файл не найден
- Сетевое соединение оборвалось
- Парсинг строки не удался

Для них используется `Result(value, error)`:

```gleam
pub fn parse_age(s: String) -> Result(Int, String) {
  case int.parse(s) {
    Ok(n) if n >= 0 && n <= 150 -> Ok(n)
    Ok(_) -> Error("возраст должен быть от 0 до 150")
    Error(_) -> Error("не удалось распознать число")
  }
}
```

Функция `parse_age` демонстрирует типичный паттерн обработки ожидаемых ошибок через `Result`: каждая ветка `case` возвращает либо `Ok` с валидным значением, либо `Error` с понятным сообщением о причине отказа.

### Неожиданные ошибки (unexpected errors, bugs)

Ситуации, которые **никогда не должны** произойти в корректной программе:

- Нарушение инварианта (список должен быть непустым, но пуст)
- Невозможная ветка кода
- Баг в логике

Для них используется `panic` или `let assert`:

```gleam
pub fn head(xs: List(a)) -> a {
  // Мы ЗНАЕМ, что список непуст —
  // если он пуст, это баг в вызывающем коде
  let assert [first, ..] = xs
  first
}
```

`let assert` здесь сигнализирует: если список пуст — это баг в вызывающем коде, а не ожидаемая ситуация, поэтому возврат `Result` был бы избыточен.

### Правило выбора

> Используйте `Result` для **ожидаемых** проблем. Используйте `panic`/`let assert` для **багов**, которые сигнализируют об ошибке программиста.

## Result(value, error) — подробно

`Result(value, error)` — тип с двумя вариантами:

```gleam
// Определение из стандартной библиотеки
pub type Result(value, error) {
  Ok(value)
  Error(error)
}
```

`Result` — это тип-сумма с двумя вариантами: `Ok(value)` для успешного результата и `Error(error)` для ошибки; оба варианта параметризованы, что делает тип универсальным.

### Основные функции

```gleam
import gleam/result

// map — преобразовать значение внутри Ok
result.map(Ok(5), fn(x) { x * 2 })      // Ok(10)
result.map(Error("oops"), fn(x) { x * 2 })  // Error("oops")

// try (bind) — цепочка операций, каждая может вернуть ошибку
result.try(Ok(5), fn(x) { Ok(x * 2) })       // Ok(10)
result.try(Ok(5), fn(_) { Error("fail") })    // Error("fail")
result.try(Error("oops"), fn(x) { Ok(x) })   // Error("oops")

// unwrap — извлечь значение или вернуть значение по умолчанию
result.unwrap(Ok(5), 0)          // 5
result.unwrap(Error("oops"), 0)  // 0

// lazy_unwrap — значение по умолчанию вычисляется лениво
result.lazy_unwrap(Ok(5), fn() { expensive_default() })  // 5
```

Эти функции позволяют трансформировать и извлекать значения из `Result`, не разворачивая его вручную через `case`: `map` преобразует успешное значение, `try` строит цепочку зависимых операций, а `unwrap` извлекает значение с резервным вариантом.

### Работа с ошибками

```gleam
// map_error — преобразовать ошибку
result.map_error(Error("oops"), fn(e) { "Error: " <> e })
// Error("Error: oops")

// replace_error — заменить ошибку
result.replace_error(Error(Nil), "не найдено")
// Error("не найдено")

// map_error — преобразовать ошибку
result.map_error(Error("not found"), fn(_) { Nil })
// Error(Nil)
```

`map_error` и `replace_error` позволяют преобразовывать тип ошибки внутри `Error`, не затрагивая успешный вариант — это полезно при унификации разнотипных ошибок в одной цепочке.

### Комбинирование

```gleam
// all — собрать список Result в Result списка
result.all([Ok(1), Ok(2), Ok(3)])
// Ok([1, 2, 3])

result.all([Ok(1), Error("fail"), Ok(3)])
// Error("fail") — останавливается на первой ошибке

// partition — разделить на успешные и ошибочные
result.partition([Ok(1), Error("a"), Ok(3), Error("b")])
// #([1, 3], ["a", "b"])

// values — извлечь только успешные значения
result.values([Ok(1), Error("a"), Ok(3)])
// [1, 3]

// flatten — убрать вложенный Result
result.flatten(Ok(Ok(5)))      // Ok(5)
result.flatten(Ok(Error("x"))) // Error("x")
result.flatten(Error("y"))     // Error("y")
```

`all` превращает список результатов в результат списка (останавливаясь на первой ошибке), `partition` разделяет все результаты на успешные и ошибочные, а `flatten` убирает лишний уровень вложенности `Result`.

### Проверки

```gleam
result.is_ok(Ok(5))         // True
result.is_ok(Error("oops")) // False
result.is_error(Error("x")) // True

// or — вернуть первый Ok
result.or(Error("a"), Ok(5))     // Ok(5)
result.or(Ok(3), Ok(5))         // Ok(3)
result.or(Error("a"), Error("b")) // Error("b")
```

`is_ok` и `is_error` проверяют вариант результата без его разворачивания, а `or` возвращает первый успешный из двух результатов — удобно для задания резервных вариантов.

## Option(a) — подробно

`Option(a)` представляет значение, которое может отсутствовать:

```gleam
import gleam/option.{type Option, None, Some}

// Определение
pub type Option(a) {
  Some(a)
  None
}
```

`Option` — это по сути `Result` без информации об ошибке. Используйте его, когда отсутствие значения — нормальная ситуация и не требует пояснений:

```gleam
import gleam/option
import gleam/list

// list.find возвращает Result — мы знаем, что элемент может не найтись
list.find([1, 2, 3], fn(x) { x > 5 })
// Error(Nil)

// Для пользовательского API Option более выразителен
pub fn safe_head(xs: List(a)) -> Option(a) {
  case xs {
    [] -> None
    [first, ..] -> Some(first)
  }
}
```

`Option` выразительнее `Result(a, Nil)` в ситуациях, когда причина отсутствия значения очевидна из контекста: `None` означает «нет значения», а не «произошла ошибка».

### Основные функции

```gleam
// map — преобразовать значение
option.map(Some(5), fn(x) { x * 2 })  // Some(10)
option.map(None, fn(x) { x * 2 })     // None

// flatten — убрать вложенность
option.flatten(Some(Some(5)))  // Some(5)
option.flatten(Some(None))     // None
option.flatten(None)           // None

// unwrap
option.unwrap(Some(5), 0)   // 5
option.unwrap(None, 0)      // 0

// Конвертация Option ↔ Result
option.to_result(Some(5), "не найдено")  // Ok(5)
option.to_result(None, "не найдено")     // Error("не найдено")

option.from_result(Ok(5))          // Some(5)
option.from_result(Error("oops"))  // None
```

Функции `map`, `flatten` и `unwrap` для `Option` работают аналогично их аналогам для `Result`; функции `to_result` и `from_result` позволяют свободно переключаться между двумя типами в зависимости от того, нужна ли информация об ошибке.

### Комбинирование

```gleam
// all — список Option → Option списка
option.all([Some(1), Some(2), Some(3)])  // Some([1, 2, 3])
option.all([Some(1), None, Some(3)])     // None

// values — извлечь только Some
option.values([Some(1), None, Some(3)])  // [1, 3]

// or / lazy_or
option.or(None, Some(5))    // Some(5)
option.or(Some(3), Some(5)) // Some(3)
```

`all` преобразует список опциональных значений в опциональный список (возвращая `None` при первом отсутствующем значении), `values` извлекает только присутствующие значения, а `or` возвращает первое непустое из двух.

## use + result.try — идиоматические цепочки

Когда нужно выполнить последовательность операций, каждая из которых может вернуть ошибку, `use` + `result.try` позволяет писать плоский код вместо вложенного:

```gleam
import gleam/result
import gleam/int

// Без use — вложенность растёт
pub fn process_nested(input: String) -> Result(String, String) {
  result.try(
    int.parse(input) |> result.replace_error("не число"),
    fn(n) {
      result.try(validate(n), fn(valid) {
        Ok(int.to_string(valid * 2))
      })
    },
  )
}

// С use — плоский, читаемый код
pub fn process(input: String) -> Result(String, String) {
  use n <- result.try(
    int.parse(input)
    |> result.replace_error("не число"),
  )
  use valid <- result.try(validate(n))
  Ok(int.to_string(valid * 2))
}

fn validate(n: Int) -> Result(Int, String) {
  case n > 0 {
    True -> Ok(n)
    False -> Error("число должно быть положительным")
  }
}
```

`use` + `result.try` позволяет выстраивать цепочки зависимых операций в плоском линейном стиле: каждая строка `use x <- result.try(...)` извлекает значение из `Ok` или немедленно возвращает `Error` из всей функции.

Напомним, как `use` работает: `use x <- f(arg)` — это `f(arg, fn(x) { ... })`, где `...` — весь остаток блока. При `Error` цепочка `result.try` останавливается и сразу возвращает ошибку.

### Пример: парсинг и валидация

```gleam
pub type User {
  User(name: String, age: Int, email: String)
}

pub fn parse_user(
  name: String,
  age_str: String,
  email: String,
) -> Result(User, String) {
  use age <- result.try(
    int.parse(age_str)
    |> result.replace_error("возраст должен быть числом"),
  )
  use _ <- result.try(case age >= 0 && age <= 150 {
    True -> Ok(Nil)
    False -> Error("возраст должен быть от 0 до 150")
  })
  use _ <- result.try(case email {
    "" -> Error("email не может быть пустым")
    _ -> Ok(Nil)
  })
  Ok(User(name:, age:, email:))
}
```

Функция `parse_user` демонстрирует реальный сценарий использования `use` + `result.try`: парсинг строки в число, две независимые проверки значений и итоговое построение типа — всё в читаемой плоской форме без вложенности.

## panic

`panic` немедленно завершает процесс с ошибкой:

```gleam
pub fn divide(a: Int, b: Int) -> Int {
  case b {
    0 -> panic as "деление на ноль"
    _ -> a / b
  }
}
```

Синтаксис:

- `panic` — завершает с сообщением по умолчанию
- `panic as "сообщение"` — с пользовательским сообщением

### Когда использовать panic?

`panic` сигнализирует: «это баг, такого не должно было произойти». Используйте его только когда:

1. Нарушен инвариант, который должен был поддерживаться вызывающим кодом
2. Программа оказалась в «невозможном» состоянии
3. Вы пишете прототип и хотите отложить обработку ошибки

### BEAM и «let it crash»

На BEAM `panic` не так страшен, как в других языках. Каждый процесс BEAM изолирован — если один процесс крашится, остальные продолжают работать. Супервизор (глава 8) автоматически перезапустит упавший процесс.

Это философия Erlang — **«let it crash»**: не пытайтесь обработать каждую мыслимую ошибку, позвольте процессу упасть и перезапуститься в чистом состоянии.

Но это **не** означает «используйте `panic` вместо `Result`»! `Result` — для ожидаемых ошибок (валидация, парсинг). `panic` — для багов и невозможных состояний.

## let assert

`let assert` — частичный pattern matching, который вызывает panic при несовпадении:

```gleam
let assert Ok(value) = might_fail()
// Если might_fail() вернёт Error — процесс упадёт
```

Это краткая форма:

```gleam
let value = case might_fail() {
  Ok(v) -> v
  Error(_) -> panic as "unexpected error"
}
```

`let assert` — синтаксический сахар для частичного сопоставления с образцом: он извлекает значение из единственного ожидаемого варианта и аварийно завершает процесс, если реальный вариант не совпадает.

### Примеры использования

```gleam
// Извлечение первого элемента (мы ЗНАЕМ, что список непуст)
let assert [first, ..rest] = non_empty_list

// Деструктуризация Result (мы ЗНАЕМ, что операция успешна)
let assert Ok(config) = load_config()

// Работа с кортежем
let assert #(x, y, _) = get_coordinates()
```

Типичные применения `let assert`: извлечение первого элемента из заведомо непустого списка, деструктуризация заведомо успешного `Result` и разбор кортежа с игнорированием ненужных полей.

### let assert с as

Можно указать сообщение об ошибке:

```gleam
let assert Ok(user) = find_user(id) as "пользователь должен существовать"
```

Клауза `as` после `let assert` задаёт пользовательское сообщение, которое будет выведено при аварийном завершении — это делает диагностику ошибок в логах значительно понятнее.

### Когда использовать let assert?

- В тестах — для краткости
- В инициализации — загрузка конфигурации, которая обязана быть корректной
- Когда контекст **гарантирует** успех — например, после `list.filter` вы знаете, что элементы удовлетворяют предикату

**Не используйте** `let assert` для обработки пользовательского ввода или данных из внешних источников — для этого есть `Result`.

## Railway-Oriented Programming

Railway-Oriented Programming (ROP) — метафора для работы с цепочками `Result`. Представьте двухколейную железную дорогу:

- **Верхняя колея** (Ok) — данные проходят через трансформации
- **Нижняя колея** (Error) — ошибка «проваливается» вниз и пропускает все дальнейшие шаги

```text
Input → [Parse] → [Validate] → [Transform] → Output
   Ok ───✓──────────✓────────────✓──────────→ Ok(result)
   Err ──✗─→─→─→─→─→─→─→─→─→─→─→─→─→─→─→──→ Error(err)
```

Каждый `result.try` — это «стрелка», которая переключает поезд на нижнюю колею при ошибке:

```gleam
pub fn process_order(raw: String) -> Result(Order, String) {
  use data <- result.try(parse_json(raw))
  use order <- result.try(decode_order(data))
  use validated <- result.try(validate_order(order))
  use priced <- result.try(calculate_price(validated))
  Ok(priced)
}
```

Если любой шаг возвращает `Error`, все последующие шаги пропускаются и ошибка возвращается сразу. Это позволяет писать линейный код без вложенных `case`.

### Преобразование ошибок в цепочке

Разные функции в цепочке могут возвращать разные типы ошибок. Используйте `result.map_error` для унификации:

```gleam
pub type ProcessError {
  ParseError(String)
  ValidationError(String)
  PriceError(String)
}

pub fn process_order(raw: String) -> Result(Order, ProcessError) {
  use data <- result.try(
    parse_json(raw)
    |> result.map_error(ParseError),
  )
  use validated <- result.try(
    validate_order(data)
    |> result.map_error(ValidationError),
  )
  use priced <- result.try(
    calculate_price(validated)
    |> result.map_error(PriceError),
  )
  Ok(priced)
}
```

При наличии разнотипных ошибок в цепочке `result.map_error` приводит каждую к общему типу-сумме `ProcessError`, что позволяет всей функции иметь единый тип возврата `Result(Order, ProcessError)`.

## Накопление ошибок

ROP останавливается на первой ошибке. Но иногда нужно собрать **все** ошибки — например, при валидации формы пользователь хочет увидеть все проблемы сразу.

### result.partition

`result.partition` разделяет список результатов на успешные и ошибочные:

```gleam
let results = [Ok(1), Error("a"), Ok(3), Error("b")]
let #(successes, errors) = result.partition(results)
// successes = [1, 3]
// errors = ["a", "b"]
```

`result.partition` обрабатывает весь список целиком и разделяет результаты на два списка: успешные значения и ошибки — в отличие от `result.all`, который останавливается на первой ошибке.

### Паттерн: валидация с накоплением

```gleam
import gleam/string

pub type FormError {
  NameTooShort
  EmailInvalid
  AgeTooYoung
  AgeTooOld
}

fn validate_name(name: String) -> Result(Nil, FormError) {
  case string.length(name) >= 2 {
    True -> Ok(Nil)
    False -> Error(NameTooShort)
  }
}

fn validate_email(email: String) -> Result(Nil, FormError) {
  case string.contains(email, "@") {
    True -> Ok(Nil)
    False -> Error(EmailInvalid)
  }
}

fn validate_age(age: Int) -> Result(Nil, FormError) {
  case age {
    a if a < 18 -> Error(AgeTooYoung)
    a if a > 150 -> Error(AgeTooOld)
    _ -> Ok(Nil)
  }
}

pub fn validate_form(
  name: String,
  email: String,
  age: Int,
) -> Result(#(String, String, Int), List(FormError)) {
  let validations = [
    validate_name(name),
    validate_email(email),
    validate_age(age),
  ]

  let #(_, errors) = result.partition(validations)

  case errors {
    [] -> Ok(#(name, email, age))
    errs -> Error(errs)
  }
}

validate_form("A", "invalid", 10)
// Error([NameTooShort, EmailInvalid, AgeTooYoung])
```

Ключевая идея: мы запускаем **все** валидации независимо друг от друга, а затем собираем ошибки в список. Пользователь видит полную картину.

## Сделайте невозможные состояния невыразимыми

Вместо проверки данных на каждом шаге можно спроектировать типы так, чтобы некорректные данные **невозможно было создать**. Это принцип «Make Illegal States Unrepresentable» (MISU).

### Проблема: «сырые» типы

```gleam
pub type User {
  User(name: String, email: String, age: Int)
}

// Любой код может создать невалидного пользователя
let bad_user = User(name: "", email: "not-an-email", age: -5)
```

Когда поля типа представлены примитивами вроде `String` и `Int`, ничто в системе типов не мешает создать семантически некорректное значение: пустое имя, невалидный email или отрицательный возраст компилятор пропустит без предупреждений.

### Решение: типы-обёртки

Вместо `String` для email создайте отдельный тип, который можно получить **только** через валидацию:

```gleam
// Email нельзя создать напрямую — только через parse_email
pub opaque type Email {
  Email(String)
}

pub fn parse_email(s: String) -> Result(Email, String) {
  case string.contains(s, "@") {
    True -> Ok(Email(s))
    False -> Error("некорректный email")
  }
}
```

Подробно мы разберём `opaque type` и smart constructors в главе 7. Пока запомните идею: **если данные проходят через валидацию при создании, дальнейший код может доверять им без перепроверки**.

## Проект: валидация формы регистрации

Соберём изученные концепции в проекте. Представим форму регистрации пользователя:

```gleam
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type RegistrationError {
  NameTooShort
  NameTooLong
  EmailMissingAt
  PasswordTooShort
  PasswordNoDigit
  AgeTooYoung
  AgeTooOld
}

pub type Registration {
  Registration(
    name: String,
    email: String,
    password: String,
    age: Int,
  )
}

fn validate_name(name: String) -> List(RegistrationError) {
  let errors = []
  let errors = case string.length(name) < 2 {
    True -> [NameTooShort, ..errors]
    False -> errors
  }
  let errors = case string.length(name) > 50 {
    True -> [NameTooLong, ..errors]
    False -> errors
  }
  errors
}

fn validate_email(email: String) -> List(RegistrationError) {
  case string.contains(email, "@") {
    True -> []
    False -> [EmailMissingAt]
  }
}

fn has_digit(s: String) -> Bool {
  s
  |> string.to_graphemes
  |> list.any(fn(c) {
    case int.parse(c) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

fn validate_password(password: String) -> List(RegistrationError) {
  let errors = []
  let errors = case string.length(password) < 8 {
    True -> [PasswordTooShort, ..errors]
    False -> errors
  }
  let errors = case has_digit(password) {
    True -> errors
    False -> [PasswordNoDigit, ..errors]
  }
  errors
}

fn validate_age(age: Int) -> List(RegistrationError) {
  case age {
    a if a < 18 -> [AgeTooYoung]
    a if a > 150 -> [AgeTooOld]
    _ -> []
  }
}

pub fn register(
  name: String,
  email: String,
  password: String,
  age: Int,
) -> Result(Registration, List(RegistrationError)) {
  let errors =
    list.flatten([
      validate_name(name),
      validate_email(email),
      validate_password(password),
      validate_age(age),
    ])

  case errors {
    [] -> Ok(Registration(name:, email:, password:, age:))
    errs -> Error(errs)
  }
}
```

Использование:

```gleam
register("A", "bad", "short", 10)
// Error([NameTooShort, EmailMissingAt, PasswordTooShort, PasswordNoDigit, AgeTooYoung])

register("Алиса", "alice@example.com", "password123", 25)
// Ok(Registration("Алиса", "alice@example.com", "password123", 25))
```

Все ошибки собираются одним списком — пользователь видит полную картину и может исправить всё за один раз.

## Упражнения

Решения пишите в файле `exercises/chapter05/test/my_solutions.gleam`. Запускайте тесты:

```sh
cd exercises/chapter05
gleam test
```

Упражнения 1-3 закрепляют рекурсию и безопасную обработку отсутствующих значений. Упражнения 4-7 шаг за шагом строят систему валидации из проекта главы — от одного поля до полной формы с накоплением ошибок.

### 1. list_length (Лёгкое)

Вычислите длину списка через рекурсию (не используйте `list.length`).

```gleam
pub fn list_length(xs: List(a)) -> Int
```

**Примеры:**

```text
list_length([1, 2, 3, 4, 5]) == 5
list_length([]) == 0
```

**Подсказка:** используйте хвостовую рекурсию с аккумулятором. Базовый случай — пустой список.

### 2. list_reverse (Лёгкое)

Разверните список через хвостовую рекурсию (не используйте `list.reverse`).

```gleam
pub fn list_reverse(xs: List(a)) -> List(a)
```

**Примеры:**

```text
list_reverse([1, 2, 3]) == [3, 2, 1]
```

**Подсказка:** используйте аккумулятор-список, добавляя каждый элемент в его начало.

### 3. safe_head (Лёгкое)

Безопасно извлеките первый элемент списка. Для пустого списка верните `None`. Это первое знакомство с обработкой «возможно отсутствующего» значения — мост к `Result` в следующих упражнениях.

```gleam
pub fn safe_head(xs: List(a)) -> Option(a)
```

**Примеры:**

```text
safe_head([1, 2, 3]) == Some(1)
safe_head([]) == None
```

Примеры показывают безопасное извлечение первого элемента списка: для непустого списка возвращается `Some` с элементом, а для пустого — `None`.

### 4. validate_age (Среднее)

Первый шаг к форме регистрации: реализуйте валидатор возраста. Возраст корректен от 0 до 150 (включительно). Верните `Ok(age)` при успехе, `Error` с описанием проблемы — при ошибке.

```gleam
pub fn validate_age(age: Int) -> Result(Int, String)
```

**Примеры:**

```text
validate_age(25) == Ok(25)
validate_age(-1) == Error("возраст не может быть отрицательным")
validate_age(200) == Error("возраст слишком большой")
```

Примеры показывают, что функция возвращает `Ok` для корректного возраста и содержательные сообщения об ошибке для отрицательных значений и значений, превышающих максимально допустимое.

### 5. validate_password (Среднее)

Продолжаем строить валидаторы. Пароль должен быть не менее 8 символов **и** содержать хотя бы одну цифру. Используйте `use` + `result.try` для цепочки проверок — это паттерн ROP из раздела выше.

```gleam
pub fn validate_password(password: String) -> Result(String, String)
```

**Примеры:**

```text
validate_password("pass1234") == Ok("pass1234")
validate_password("short1") == Error("пароль должен быть не менее 8 символов")
validate_password("longpassword") == Error("пароль должен содержать хотя бы одну цифру")
validate_password("12345678") == Ok("12345678")
```

**Подсказка:** вам понадобится вспомогательная функция `has_digit(s: String) -> Bool`. Разберите строку на графемы через `string.to_graphemes` и проверьте каждый через `int.parse`. Обратите внимание: в отличие от `validate_age`, здесь **две** проверки — их нужно связать через `use` + `result.try`.

### 6. parse_and_validate (Среднее)

Представьте, что возраст приходит строкой из формы. Реализуйте полную ROP-цепочку: распарсьте строку в число, проверьте, что оно больше 0 и меньше 1000.

```gleam
pub fn parse_and_validate(input: String) -> Result(Int, String)
```

**Примеры:**

```text
parse_and_validate("42")    == Ok(42)
parse_and_validate("abc")   == Error("не удалось распознать число")
parse_and_validate("0")     == Error("число должно быть больше 0")
parse_and_validate("-5")    == Error("число должно быть больше 0")
parse_and_validate("1000")  == Error("число должно быть меньше 1000")
parse_and_validate("999")   == Ok(999)
```

**Подсказка:** используйте `int.parse` с `result.replace_error`, затем проверки через `result.try`. Это расширение паттерна из упражнения 5 — теперь в начале цепочки стоит парсинг.

### 7. validate_form (Сложное)

Финальное упражнение: соберите валидаторы в единую функцию с **накоплением** ошибок. В отличие от ROP-цепочки (упражнения 5-6), которая останавливается на первой ошибке, здесь нужно запустить **все** проверки и вернуть **все** найденные ошибки — как в проекте `register`.

Проверьте:

- Имя: длина ≥ 2
- Email: содержит `@`
- Возраст: от 18 до 150

```gleam
pub type FormError {
  NameTooShort
  EmailInvalid
  AgeTooYoung
  AgeTooOld
}

pub fn validate_form(
  name: String,
  email: String,
  age: Int,
) -> Result(#(String, String, Int), List(FormError))
```

**Примеры:**

```text
validate_form("Алиса", "alice@mail.com", 25) == Ok(#("Алиса", "alice@mail.com", 25))
validate_form("A", "bad", 10) == Error([NameTooShort, EmailInvalid, AgeTooYoung])
validate_form("Боб", "bob@mail.com", 200) == Error([AgeTooOld])
```

**Подсказка:** запустите каждую валидацию отдельно (как в проекте главы), соберите ошибки в список через `result.partition`.

## Заключение

В этой главе мы изучили:

- **Рекурсия** — основной способ итерации, pattern matching на списках
- **Хвостовая рекурсия** — оптимизация через аккумуляторы; на современном BEAM разница с body-рекурсией минимальна, но обязательна для бесконечных циклов
- **Свёртки** — `fold`, `reduce`, `try_fold` как обобщение рекурсии
- **Ошибки как значения** — философия Gleam: явные типы вместо исключений
- **Result и Option** — два основных типа для обработки ошибок и отсутствия значений
- **use + result.try** — идиоматические цепочки операций
- **panic и let assert** — для багов и невозможных состояний
- **ROP** — композиция через Result, «железнодорожная» метафора
- **Накопление ошибок** — сбор всех проблем вместо остановки на первой
- **MISU** — проектирование типов, делающих невозможные состояния невыразимыми

В следующей главе мы подробно изучим строки, битовые массивы и оставшиеся модули стандартной библиотеки.
