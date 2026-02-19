# Функции и пайплайны

> Эта глава посвящена функциям как значениям первого класса, pipe-оператору и use-выражениям.

## Цели главы

В этой главе мы:

- Научимся работать с функциями как со значениями
- Поймём, почему в Gleam нет каррирования
- Освоим pipe-оператор `|>` — основной инструмент композиции
- Разберём use-выражения — синтаксический сахар для callback-ов
- Познакомимся с pattern matching и case-выражениями

## Функции как значения первого класса

В Gleam функции — такие же значения, как числа или строки. Их можно сохранять в переменные, передавать в другие функции и возвращать из функций.

```gleam
import gleam/io

pub fn main() {
  // Сохраняем функцию в переменную
  let add_one = fn(x) { x + 1 }

  // Вызываем через переменную
  io.debug(add_one(5))  // 6

  // Передаём функцию как аргумент
  io.debug(apply_twice(add_one, 3))  // 5
}

pub fn apply_twice(f: fn(a) -> a, x: a) -> a {
  f(f(x))
}
```

Функция `apply_twice` принимает функцию `f` и значение `x`, а затем применяет `f` к `x` дважды. Тип `fn(a) -> a` означает: «функция, которая принимает значение типа `a` и возвращает значение того же типа». Здесь `a` — **параметр типа** (generic), который будет подставлен конкретным типом при вызове.

## Нет каррирования

В Haskell, OCaml и PureScript каждая функция принимает ровно один аргумент, а многоаргументные функции — это цепочки функций, возвращающих функции:

```
-- Haskell: add :: Int -> Int -> Int
-- На самом деле: add :: Int -> (Int -> Int)
add x y = x + y
add3 = add 3  -- частичное применение
```

В Gleam каррирования **нет**. Каждая функция принимает все аргументы сразу:

```gleam
pub fn add(x: Int, y: Int) -> Int {
  x + y
}

// ✗ Ошибка! Нельзя вызвать add(3) — нужны оба аргумента
// let add3 = add(3)

// ✓ Для частичного применения используйте анонимную функцию
let add3 = fn(y) { add(3, y) }
```

Это осознанное решение: код без каррирования проще читать, а сообщения об ошибках — понятнее.

### Захват функций (function capture)

Вместо анонимных функций-обёрток Gleam предлагает сокращённый синтаксис — **function capture**. Символ `_` обозначает место для аргумента:

```gleam
// Полная запись
let add3 = fn(y) { add(3, y) }

// Захват функции — то же самое, но короче
let add3 = add(3, _)
```

`add(3, _)` создаёт новую функцию, которая принимает один аргумент и подставляет его вместо `_`. Это **единственный** способ частичного применения в Gleam — явный и наглядный.

## Анонимные функции

Анонимные (лямбда) функции создаются ключевым словом `fn`:

```gleam
let double = fn(x) { x * 2 }
let greet = fn(name) { "Привет, " <> name <> "!" }
let add = fn(a, b) { a + b }
```

Анонимные функции часто используются как аргументы функций высшего порядка:

```gleam
import gleam/list

pub fn main() {
  let numbers = [1, 2, 3, 4, 5]

  // Удвоить каждый элемент
  list.map(numbers, fn(x) { x * 2 })
  // [2, 4, 6, 8, 10]

  // Оставить только чётные
  list.filter(numbers, fn(x) { x % 2 == 0 })
  // [2, 4]
}
```

Пример демонстрирует передачу анонимных функций в `list.map` и `list.filter` для трансформации и фильтрации списков.

### Замыкания

Анонимные функции захватывают переменные из окружающего контекста:

```gleam
pub fn make_adder(n: Int) -> fn(Int) -> Int {
  fn(x) { x + n }  // n захвачена из внешней области
}

pub fn main() {
  let add5 = make_adder(5)
  add5(3)   // 8
  add5(10)  // 15
}
```

Захваченные значения неизменяемы — замыкание видит тот `n`, который существовал на момент создания функции.

## Именованные аргументы

Gleam поддерживает **именованные (labelled) аргументы**. Они позволяют указывать имя параметра при вызове для ясности:

```gleam
pub fn greet(greeting greeting: String, name name: String) -> String {
  greeting <> ", " <> name <> "!"
}
```

В сигнатуре `greeting greeting: String` первое слово — внешняя метка (для вызова), второе — внутреннее имя (для тела функции). Если они совпадают, можно указать имя один раз:

```gleam
pub fn greet(greeting greeting: String, name name: String) -> String
// то же самое, что:
pub fn greet(greeting: String, name: String) -> String
```

При вызове именованные аргументы можно передавать в **любом порядке**:

```gleam
greet(greeting: "Привет", name: "Алиса")
// "Привет, Алиса!"

greet(name: "Боб", greeting: "Здравствуй")
// "Здравствуй, Боб!"
```

Именованные аргументы особенно полезны для функций с несколькими параметрами одного типа, где порядок неочевиден:

```gleam
// Без меток — что есть что?
send("alice@example.com", "bob@example.com", "Привет!")

// С метками — ясно
send(from: "alice@example.com", to: "bob@example.com", body: "Привет!")
```

Именованные аргументы устраняют неоднозначность при нескольких параметрах одного типа: по меткам сразу видно, что означает каждый аргумент.

### Сокращённый синтаксис меток

Если локальная переменная называется так же, как именованный аргумент, имя можно не повторять:

```gleam
let name = "Алиса"
let greeting = "Привет"

// Полная запись
greet(greeting: greeting, name: name)

// Сокращённая — то же самое
greet(greeting:, name:)
```

Запись `name:` без значения означает: «подставь переменную `name`». Это работает и при создании записей (custom types с labelled fields).

## Pipe-оператор

Pipe-оператор `|>` — главный инструмент композиции в Gleam. Он передаёт результат левого выражения как **первый аргумент** правого:

```gleam
// Без pipe
string.uppercase(string.trim("  hello  "))

// С pipe — читается слева направо, сверху вниз
"  hello  "
|> string.trim
|> string.uppercase
```

Оба варианта делают одно и то же, но второй читается как последовательность шагов: «взять строку, обрезать пробелы, перевести в верхний регистр».

### Pipe с дополнительными аргументами

Если функция принимает больше одного аргумента, pipe подставляет значение как первый:

```gleam
import gleam/string

"hello"
|> string.append(", world")   // string.append("hello", ", world")
|> string.uppercase            // string.uppercase("hello, world")
// "HELLO, WORLD"
```

Pipe-оператор автоматически подставляет предыдущее значение первым аргументом, поэтому `string.append` получает `"hello"` как базу и добавляет `", world"`.

### Pipe с function capture

По умолчанию `|>` подставляет значение как **первый** аргумент. Если нужно подставить в другую позицию, используйте function capture с `_`:

```gleam
import gleam/string

// _ указывает, куда подставить значение из pipe
"world"
|> string.append("hello, ", _)
|> string.uppercase
// "HELLO, WORLD"
```

Здесь `string.append("hello, ", _)` создаёт функцию, которая подставляет входящее значение вторым аргументом. Без `_` получилось бы `string.append("world", "hello, ")` — не то, что нужно.

Ещё пример — построение строки справа налево:

```gleam
"1"
|> string.append("2")       // string.append("1", "2")  → "12"
|> string.append("3", _)    // string.append("3", "12") → "312"
```

Символ `_` в function capture позволяет передать значение из pipe в любую позицию аргумента, а не только в первую.

### Практический пример

Pipe-оператор позволяет строить читаемые конвейеры обработки данных:

```gleam
import gleam/int
import gleam/list
import gleam/string

pub fn format_scores(scores: List(Int)) -> String {
  scores
  |> list.sort(int.compare)
  |> list.reverse
  |> list.map(int.to_string)
  |> string.join(", ")
}

// format_scores([42, 17, 88, 5]) == "88, 42, 17, 5"
```

Функция `format_scores` сортирует результаты по убыванию и объединяет их в строку через запятую — весь конвейер записан без промежуточных переменных.

## use-выражения

use-выражение — **синтаксический сахар для callback-ов**. Это **не** монадический `do` из Haskell — это простая перезапись вложенных callback-функций в плоский код.

### Проблема: вложенные callback-и

Представьте цепочку операций, каждая из которых может завершиться ошибкой:

```gleam
import gleam/result

pub fn process(input: String) -> Result(Int, String) {
  result.try(parse_input(input), fn(value) {
    result.try(validate(value), fn(valid) {
      Ok(valid * 2)
    })
  })
}
```

С каждым шагом вложенность растёт. Код сложно читать.

### Решение: use

`use` разворачивает callback в плоский стиль:

```gleam
import gleam/result

pub fn process(input: String) -> Result(Int, String) {
  use value <- result.try(parse_input(input))
  use valid <- result.try(validate(value))
  Ok(valid * 2)
}
```

Запись `use x <- f(arg)` означает: «вызови `f(arg, fn(x) { ... })`, где `...` — весь оставшийся код блока». Другими словами, use **захватывает остаток блока как callback**.

### Как use работает внутри

Компилятор преобразует:

```gleam
use x <- f(a)
use y <- g(x)
h(y)
```

в:

```gleam
f(a, fn(x) {
  g(x, fn(y) {
    h(y)
  })
})
```

Никакой магии — только устранение вложенности.

### use с несколькими значениями

use может связывать несколько переменных:

```gleam
use first, rest <- list.pop(items)
```

Это эквивалентно `list.pop(items, fn(first, rest) { ... })`.

## Case-выражения и pattern matching

Case-выражение — основной способ ветвления в Gleam:

```gleam
pub fn describe(n: Int) -> String {
  case n {
    0 -> "ноль"
    1 -> "один"
    _ -> "другое число"
  }
}
```

`_` — подстановочный паттерн, совпадающий с любым значением.

### Pattern matching на строках

```gleam
pub fn greet(name: String) -> String {
  case name {
    "Алиса" -> "Привет, Алиса! Как дела?"
    "Боб" -> "Здорово, Боб!"
    name -> "Привет, " <> name <> "!"
  }
}
```

В последней ветке `name` — новая переменная, привязанная к значению.

### Сопоставление нескольких значений

Case может сопоставлять несколько значений одновременно:

```gleam
import gleam/int

pub fn fizzbuzz(n: Int) -> String {
  case n % 3, n % 5 {
    0, 0 -> "FizzBuzz"
    0, _ -> "Fizz"
    _, 0 -> "Buzz"
    _, _ -> int.to_string(n)
  }
}
```

Пример показывает сопоставление с образцом по нескольким значениям одновременно с помощью кортежа в `case`.

### Guards

Guards — дополнительные условия в ветках `case`:

```gleam
pub fn classify_age(age: Int) -> String {
  case age {
    a if a < 0 -> "некорректный возраст"
    a if a < 13 -> "ребёнок"
    a if a < 18 -> "подросток"
    a if a < 65 -> "взрослый"
    _ -> "пенсионер"
  }
}
```

Guards используют ключевое слово `if` после паттерна. В них допустимы сравнения и логические операторы.

### Альтернативные паттерны

Несколько паттернов можно объединить оператором `|` (ИЛИ):

```gleam
pub fn is_weekend(day: String) -> Bool {
  case day {
    "Saturday" | "Sunday" -> True
    _ -> False
  }
}
```

Оператор `|` в паттернах позволяет объединять несколько вариантов в одну ветку, избегая дублирования логики.

## Модуль gleam/function

Модуль `gleam/function` содержит утилиты для работы с функциями:

```gleam
import gleam/function

// identity — возвращает аргумент без изменений
function.identity(42)  // 42

// compose — композиция двух функций
let double_then_add1 = function.compose(
  fn(x) { x * 2 },
  fn(x) { x + 1 },
)
double_then_add1(5)  // 11

// flip — меняет порядок аргументов
let flipped_append = function.flip(string.append)
flipped_append("мир", "привет, ")  // "привет, мир"

// tap — выполняет побочный эффект и возвращает исходное значение
42
|> function.tap(io.debug)  // выводит 42, возвращает 42
|> int.to_string
```

Эти утилиты особенно полезны при построении конвейеров из pipe-операторов, когда нужно адаптировать порядок аргументов или вставить отладочный вывод без разрыва цепочки.

## Модуль gleam/bool

Утилиты для работы с логическими значениями:

```gleam
import gleam/bool

bool.to_int(True)       // 1
bool.to_int(False)      // 0
bool.to_string(True)    // "True"
bool.negate(True)       // False

// guard — раннее прерывание при выполнении условия
pub fn divide(a: Int, b: Int) -> Result(Int, String) {
  use <- bool.guard(b == 0, Error("деление на ноль"))
  Ok(a / b)
}
```

`bool.guard(condition, return_value)` — если `condition` равно `True`, немедленно возвращает `return_value`. Иначе выполняет оставшийся код. Это идиоматический способ «раннего возврата» в Gleam.

## Модуль gleam/order

Тип `Order` используется для сравнения значений:

```gleam
import gleam/order

// Тип Order имеет три значения: Lt, Eq, Gt
order.compare(1, 2)     // Lt
order.compare(2, 2)     // Eq
order.compare(3, 2)     // Gt

// Обращение порядка
order.negate(order.Lt)  // Gt

// Полезно для сортировки
order.reverse           // функция для обратной сортировки
```

Тип `Order` и его функции часто используются совместно с сортировкой списков — например, передаётся в `list.sort` для управления порядком элементов.

## Проект: адресная книга

Соберём изученные концепции в небольшом проекте. Представим адресную книгу как список записей:

```gleam
import gleam/io
import gleam/list
import gleam/string

pub type Entry {
  Entry(name: String, phone: String, city: String)
}

pub fn format_entry(entry: Entry) -> String {
  entry.name <> " (" <> entry.city <> "): " <> entry.phone
}

pub fn find_by_city(
  entries: List(Entry),
  city: String,
) -> List(Entry) {
  entries
  |> list.filter(fn(e) { e.city == city })
}

pub fn format_book(entries: List(Entry)) -> String {
  entries
  |> list.map(format_entry)
  |> string.join("\n")
}

pub fn main() {
  let book = [
    Entry(name: "Алиса", phone: "+7-900-111-22-33", city: "Москва"),
    Entry(name: "Боб", phone: "+7-900-444-55-66", city: "Петербург"),
    Entry(name: "Чарли", phone: "+7-900-777-88-99", city: "Москва"),
  ]

  book
  |> find_by_city("Москва")
  |> format_book
  |> io.println
  // Алиса (Москва): +7-900-111-22-33
  // Чарли (Москва): +7-900-777-88-99
}
```

Обратите внимание, как pipe-оператор превращает цепочку вызовов в читаемый конвейер. Мы ещё не знакомы с пользовательскими типами (они будут в следующей главе), но уже можем видеть, как `Entry` описывает структуру данных с именованными полями.

## Упражнения

Решения пишите в файле `exercises/chapter03/test/my_solutions.gleam`. Запускайте тесты:

```sh
$ cd exercises/chapter03
$ gleam test
```

Запускайте тесты после каждого упражнения, чтобы сразу видеть результат.

### 1. apply_twice (Лёгкое)

Напишите функцию `apply_twice`, которая применяет функцию `f` к значению `x` дважды.

```gleam
pub fn apply_twice(f: fn(a) -> a, x: a) -> a
```

**Примеры:**

```
apply_twice(fn(x) { x * 2 }, 3) == 12
apply_twice(fn(x) { x + 1 }, 0) == 2
```

Примеры показывают ожидаемое поведение функции `apply_twice` при применении функции к значению дважды.

### 2. add_exclamation (Лёгкое)

Напишите функцию, которая добавляет восклицательный знак к строке.

```gleam
pub fn add_exclamation(s: String) -> String
```

**Примеры:**

```
add_exclamation("hello") == "hello!"
add_exclamation("") == "!"
```

Примеры показывают ожидаемое поведение функции `add_exclamation` для строк разной длины.

### 3. shout (Среднее)

Напишите функцию, которая переводит строку в верхний регистр и добавляет `"!"`. Используйте pipe-оператор.

```gleam
pub fn shout(s: String) -> String
```

**Примеры:**

```
shout("hello") == "HELLO!"
shout("gleam") == "GLEAM!"
```

**Подсказка:** используйте `string.uppercase` и функцию `add_exclamation` из предыдущего упражнения (или оператор `<>`).

### 4. safe_divide (Среднее)

Напишите функцию безопасного целочисленного деления. При делении на ноль возвращайте ошибку.

```gleam
pub fn safe_divide(a: Int, b: Int) -> Result(Int, String)
```

**Примеры:**

```
safe_divide(10, 3) == Ok(3)
safe_divide(10, 0) == Error("деление на ноль")
```

**Подсказка:** используйте case-выражение.

### 5. FizzBuzz (Среднее)

Напишите функцию FizzBuzz: если число делится на 15 → `"FizzBuzz"`, на 3 → `"Fizz"`, на 5 → `"Buzz"`, иначе → строковое представление числа.

```gleam
pub fn fizzbuzz(n: Int) -> String
```

**Примеры:**

```
fizzbuzz(15) == "FizzBuzz"
fizzbuzz(9) == "Fizz"
fizzbuzz(10) == "Buzz"
fizzbuzz(7) == "7"
```

**Подсказка:** используйте case с сопоставлением нескольких значений — `case n % 3, n % 5 { ... }`.

## Заключение

В этой главе мы изучили:

- Функции как значения первого класса и анонимные функции
- Отсутствие каррирования в Gleam и способы частичного применения
- Pipe-оператор `|>` для построения конвейеров
- use-выражения для устранения вложенных callback-ов
- Case-выражения, pattern matching и guards
- Модули `gleam/function`, `gleam/bool` и `gleam/order`

В следующей главе мы познакомимся с пользовательскими типами, generics и основными коллекциями Gleam.
