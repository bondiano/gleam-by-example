# Типы данных и коллекции

> Пользовательские типы, generics, списки, словари, множества и итераторы.

## Цели главы

В этой главе мы:

- Научимся создавать пользовательские типы (custom types)
- Познакомимся с generics и type aliases
- Разберём основные коллекции: List, Dict, Set, Queue
- Изучим ленивые последовательности (Iterator)
- Построим проект — модель файловой системы

## Пользовательские типы

Пользовательские типы (custom types) — основной способ моделирования данных в Gleam. Они похожи на алгебраические типы данных (ADT) из Haskell и OCaml.

### Типы-перечисления

Простейший вариант — перечисление:

```gleam
pub type Color {
  Red
  Green
  Blue
}
```

Тип `Color` имеет три значения: `Red`, `Green`, `Blue`. Используем case для работы с ними:

```gleam
pub fn to_hex(color: Color) -> String {
  case color {
    Red -> "#FF0000"
    Green -> "#00FF00"
    Blue -> "#0000FF"
  }
}
```

### Типы с данными

Варианты могут содержать данные:

```gleam
pub type Shape {
  Circle(radius: Float)
  Rectangle(width: Float, height: Float)
}
```

Здесь `Circle` и `Rectangle` — **конструкторы**: функции, создающие значения типа `Shape`.

Конструкторы можно вызывать с метками или позиционно:

```gleam
// С метками — порядок не важен
let c = Circle(radius: 5.0)
let r = Rectangle(height: 4.0, width: 3.0)

// Позиционно — порядок как в определении типа
let c = Circle(5.0)
let r = Rectangle(3.0, 4.0)
```

Можно комбинировать: часть аргументов позиционно, часть с метками.

### Pattern matching на записях

Pattern matching извлекает данные из конструкторов:

```gleam
pub fn area(shape: Shape) -> Float {
  case shape {
    Circle(radius:) -> 3.14159265358979 *. radius *. radius
    Rectangle(width:, height:) -> width *. height
  }
}
```

В паттерне `Circle(radius:)` используется сокращённый синтаксис: имя переменной совпадает с именем поля. Это эквивалентно `Circle(radius: radius)`.

Чтобы игнорировать часть полей, используйте `..`:

```gleam
pub fn name(shape: Shape) -> String {
  case shape {
    Circle(..) -> "круг"
    Rectangle(..) -> "прямоугольник"
  }
}

// Извлечь только одно поле, остальные проигнорировать
case shape {
  Circle(radius:, ..) -> radius
  Rectangle(width:, ..) -> width
}
```

`..` в паттерне означает «остальные поля не важны». Для отдельных полей можно использовать `_`:

```gleam
case shape {
  Rectangle(_, height) -> height   // игнорируем width
  Circle(radius) -> radius
}
```

### Типы-записи

Тип с единственным вариантом работает как запись (struct/record):

```gleam
pub type User {
  User(name: String, email: String, age: Int)
}

let alice = User(name: "Алиса", email: "alice@example.com", age: 30)

// Доступ к полям через точку
alice.name   // "Алиса"
alice.age    // 30
```

### Доступ к полям (record accessors)

Точечный синтаксис `record.field` работает для типов с одним вариантом без ограничений. Для типов с несколькими вариантами поле доступно через точку только если оно имеет **одинаковое имя, позицию и тип** во всех вариантах:

```gleam
pub type SchoolPerson {
  Teacher(name: String, subject: String)
  Student(name: String)
}

let t = Teacher("Иванов", "Физика")
let s = Student("Петров")

t.name   // "Иванов" — поле name есть в обоих вариантах
s.name   // "Петров" — ок

// t.subject — ✗ ошибка! subject есть только у Teacher
// Для доступа к таким полям используйте pattern matching
```

### Обновление записи

Для создания модифицированной копии записи используется синтаксис `..`:

```gleam
let alice = User(name: "Алиса", email: "alice@example.com", age: 30)
let older = User(..alice, age: 31)
// User(name: "Алиса", email: "alice@example.com", age: 31)
```

Исходная запись `alice` не изменяется — создаётся новая копия с обновлённым полем.

## Labelled fields

Поля конструкторов в Gleam могут быть именованными (labelled). Это улучшает читаемость:

```gleam
pub type Point {
  Point(x: Float, y: Float)
}

// С метками — порядок не важен
let point = Point(y: 4.0, x: 3.0)

// Позиционно — порядок как в определении
let point = Point(3.0, 4.0)

// В pattern matching
case point {
  Point(x:, y:) -> x +. y
}
```

Метки при вызове опциональны — можно передавать аргументы и позиционно.

## Type aliases

Type alias — альтернативное имя для существующего типа:

```gleam
pub type Name = String
pub type Age = Int
pub type Coordinate = #(Float, Float)
```

Alias не создаёт новый тип — это просто синоним для удобства. `Name` и `String` полностью взаимозаменяемы.

## Generics

Типы могут быть параметризованы другими типами:

```gleam
pub type Pair(a, b) {
  Pair(first: a, second: b)
}
```

`a` и `b` — параметры типа. При использовании они подставляются конкретными типами:

```gleam
let pair_of_ints: Pair(Int, Int) = Pair(first: 1, second: 2)
let mixed: Pair(String, Bool) = Pair(first: "hello", second: True)
```

Функции тоже могут быть обобщёнными:

```gleam
pub fn swap(pair: Pair(a, b)) -> Pair(b, a) {
  Pair(first: pair.second, second: pair.first)
}
```

Gleam выводит параметры типов автоматически — явно указывать их нужно редко.

### Пример: тип Box

```gleam
pub type Box(a) {
  Box(value: a)
  Empty
}

pub fn map_box(box: Box(a), f: fn(a) -> b) -> Box(b) {
  case box {
    Box(value:) -> Box(value: f(value))
    Empty -> Empty
  }
}
```

`Box(a)` — контейнер, который может содержать значение типа `a` или быть пустым. Функция `map_box` применяет функцию к содержимому, не раскрывая контейнер.

## Constants

Константы объявляются на уровне модуля:

```gleam
const pi = 3.14159265358979
const max_retries = 3
const greeting = "Привет!"
```

Константы вычисляются на этапе компиляции. В них можно использовать только литералы и другие константы — вызовы функций запрещены.

Константы можно использовать в паттернах:

```gleam
const admin_email = "admin@example.com"

pub fn is_admin(email: String) -> Bool {
  case email {
    e if e == admin_email -> True
    _ -> False
  }
}
```

## Кортежи

Кортежи (tuples) — упорядоченные коллекции фиксированного размера с элементами разных типов:

```gleam
let point = #(3.0, 4.0)           // #(Float, Float)
let person = #("Алиса", 30)       // #(String, Int)
let triple = #(1, "hello", True)  // #(Int, String, Bool)
```

Доступ к элементам — через `.0`, `.1`, `.2`:

```gleam
point.0   // 3.0
point.1   // 4.0
person.0  // "Алиса"
```

Pattern matching на кортежах:

```gleam
let #(x, y) = point
// x = 3.0, y = 4.0

case person {
  #(name, age) if age >= 18 -> name <> " — взрослый"
  #(name, _) -> name <> " — ребёнок"
}
```

Кортежи удобны для возврата нескольких значений из функции. Для более сложных структур лучше использовать custom types с именованными полями.

## Списки

Списки — основная коллекция в Gleam. Это **связные списки** (linked lists): эффективное добавление/удаление в начало, но медленный доступ по индексу.

### Создание списков

```gleam
let empty = []
let numbers = [1, 2, 3, 4, 5]
let strings = ["привет", "мир"]
```

Все элементы списка должны быть одного типа.

### Добавление в начало

Оператор `..` добавляет элемент(ы) в начало списка:

```gleam
let numbers = [1, 2, 3]
let more = [0, ..numbers]   // [0, 1, 2, 3]
```

Это операция за O(1) — самый эффективный способ добавления.

### Pattern matching на списках

```gleam
pub fn describe(xs: List(Int)) -> String {
  case xs {
    [] -> "пустой список"
    [x] -> "один элемент: " <> int.to_string(x)
    [first, ..rest] -> {
      "первый: " <> int.to_string(first)
      <> ", остальных: " <> int.to_string(list.length(rest))
    }
  }
}
```

Паттерн `[first, ..rest]` разбивает список на голову (`first`) и хвост (`rest`). Паттерн `[x]` совпадает со списком из одного элемента.

## Модуль gleam/list

Модуль `gleam/list` — один из самых богатых в стандартной библиотеке. Разберём основные функции по категориям.

### Трансформация

```gleam
import gleam/list

// map — применить функцию к каждому элементу
list.map([1, 2, 3], fn(x) { x * 2 })
// [2, 4, 6]

// filter — оставить элементы, удовлетворяющие предикату
list.filter([1, 2, 3, 4, 5], fn(x) { x % 2 == 0 })
// [2, 4]

// filter_map — map + filter за один проход
list.filter_map([1, 2, 3, 4], fn(x) {
  case x % 2 == 0 {
    True -> Ok(x * 10)
    False -> Error(Nil)
  }
})
// [20, 40]

// flat_map — map, возвращающий список, + flatten
list.flat_map([1, 2, 3], fn(x) { [x, x * 10] })
// [1, 10, 2, 20, 3, 30]
```

### Свёртки

Свёртка (fold) — самая мощная операция на списках. Она проходит список, накапливая результат:

```gleam
// fold — свёртка слева
list.fold([1, 2, 3, 4], 0, fn(acc, x) { acc + x })
// 10

// reduce — свёртка без начального значения
list.reduce([1, 2, 3], fn(acc, x) { acc + x })
// Ok(6)

// reduce на пустом списке возвращает Error(Nil)
list.reduce([], fn(acc, x) { acc + x })
// Error(Nil)
```

Разница между `fold` и `reduce`: `fold` принимает начальное значение аккумулятора, `reduce` использует первый элемент списка.

### Поиск

```gleam
// find — первый элемент, удовлетворяющий предикату
list.find([1, 2, 3, 4], fn(x) { x > 2 })
// Ok(3)

// contains — проверка наличия элемента
list.contains([1, 2, 3], 2)  // True

// any / all — есть ли хотя бы один / все ли
list.any([1, 2, 3], fn(x) { x > 2 })  // True
list.all([1, 2, 3], fn(x) { x > 0 })  // True
```

### Сортировка

```gleam
import gleam/int

// sort — сортировка с функцией сравнения
list.sort([3, 1, 4, 1, 5], int.compare)
// [1, 1, 3, 4, 5]

// unique — убрать дубликаты (сохраняя порядок)
list.unique([1, 2, 3, 2, 1, 4])
// [1, 2, 3, 4]

// reverse
list.reverse([1, 2, 3])
// [3, 2, 1]
```

### Комбинирование

```gleam
// append — соединить два списка
list.append([1, 2], [3, 4])
// [1, 2, 3, 4]

// flatten — развернуть список списков
list.flatten([[1, 2], [3], [4, 5]])
// [1, 2, 3, 4, 5]

// zip — попарно объединить элементы
list.zip([1, 2, 3], ["a", "b", "c"])
// [#(1, "a"), #(2, "b"), #(3, "c")]

// intersperse — вставить элемент между каждой парой
list.intersperse([1, 2, 3], 0)
// [1, 0, 2, 0, 3]
```

### Разбиение

```gleam
// take / drop — взять / отбросить N элементов
list.take([1, 2, 3, 4, 5], 3)   // [1, 2, 3]
list.drop([1, 2, 3, 4, 5], 2)   // [3, 4, 5]

// split — разделить на два списка
list.split([1, 2, 3, 4, 5], 3)
// #([1, 2, 3], [4, 5])

// partition — разделить по предикату
list.partition([1, 2, 3, 4, 5], fn(x) { x % 2 == 0 })
// #([2, 4], [1, 3, 5])

// chunk — группировка последовательных элементов
list.chunk([1, 1, 2, 2, 2, 3], fn(x) { x })
// [[1, 1], [2, 2, 2], [3]]
```

### Key-value списки

Списки кортежей можно использовать как простые словари:

```gleam
let entries = [#("name", "Алиса"), #("city", "Москва")]

list.key_find(entries, "name")   // Ok("Алиса")
list.key_find(entries, "phone")  // Error(Nil)
list.key_set(entries, "city", "Петербург")
// [#("name", "Алиса"), #("city", "Петербург")]
```

### group — группировка

```gleam
list.group(["cat", "car", "dog", "day"], fn(w) {
  string.slice(w, 0, 1)
})
// dict.from_list([
//   #("c", ["cat", "car"]),
//   #("d", ["dog", "day"]),
// ])
```

`list.group` возвращает `Dict` — словарь, который мы рассмотрим далее.

## Dict

`Dict(key, value)` — словарь (хеш-таблица). Ключи уникальны.

```gleam
import gleam/dict

// Создание
let d = dict.from_list([#("a", 1), #("b", 2), #("c", 3)])

// Вставка и получение
let d = dict.insert(d, "d", 4)
dict.get(d, "a")      // Ok(1)
dict.get(d, "z")      // Error(Nil)

// Проверка
dict.has_key(d, "a")  // True
dict.size(d)          // 4

// Удаление
let d = dict.delete(d, "b")
```

### Трансформации Dict

```gleam
// map_values — преобразовать значения
dict.map_values(d, fn(_key, value) { value * 10 })

// filter — отфильтровать пары
dict.filter(d, fn(_key, value) { value > 2 })

// merge — объединить два словаря (правый приоритетнее)
let d1 = dict.from_list([#("a", 1), #("b", 2)])
let d2 = dict.from_list([#("b", 20), #("c", 30)])
dict.merge(d1, d2)
// dict.from_list([#("a", 1), #("b", 20), #("c", 30)])

// fold — свёртка по парам ключ-значение
dict.fold(d, 0, fn(acc, _key, value) { acc + value })

// keys и values
dict.keys(d)    // список ключей
dict.values(d)  // список значений

// to_list — преобразование в список кортежей
dict.to_list(d)
// [#("a", 1), #("c", 3), #("d", 4)]
```

### upsert — вставка с обновлением

```gleam
// Если ключ есть — обновить, если нет — вставить
dict.upsert(d, "a", fn(existing) {
  case existing {
    Some(n) -> n + 1
    None -> 1
  }
})
```

## Set

`Set(a)` — неупорядоченное множество уникальных элементов:

```gleam
import gleam/set

let s1 = set.from_list([1, 2, 3, 4])
let s2 = set.from_list([3, 4, 5, 6])

set.contains(s1, 2)         // True
set.size(s1)                // 4

// Теоретико-множественные операции
set.union(s1, s2)           // {1, 2, 3, 4, 5, 6}
set.intersection(s1, s2)    // {3, 4}
set.difference(s1, s2)      // {1, 2}

set.is_subset(
  set.from_list([1, 2]),
  s1,
)  // True

// Добавление и удаление
let s = set.insert(s1, 5)   // {1, 2, 3, 4, 5}
let s = set.delete(s1, 1)   // {2, 3, 4}
```

Set полезен для проверки уникальности, удаления дубликатов и теоретико-множественных операций.

## Queue

`Queue(a)` — двусторонняя очередь с эффективными операциями на обоих концах:

```gleam
import gleam/queue

let q = queue.from_list([1, 2, 3])

// Добавление
let q = queue.push_back(q, 4)    // [1, 2, 3, 4]
let q = queue.push_front(q, 0)   // [0, 1, 2, 3, 4]

// Извлечение
queue.pop_front(q)   // Ok(#(0, остаток))
queue.pop_back(q)    // Ok(#(4, остаток))

// Проверки
queue.is_empty(q)    // False
queue.length(q)      // 5
```

Queue реализована на двух списках и обеспечивает амортизированное O(1) для всех операций. Она полезна, когда нужно эффективно добавлять и извлекать элементы с обоих концов.

## Iterator

`Iterator(a)` — ленивая последовательность. В отличие от списка, элементы вычисляются по требованию:

```gleam
import gleam/iterator

// Создание из списка
let it = iterator.from_list([1, 2, 3])

// Бесконечные итераторы
let ones = iterator.repeat(1)        // 1, 1, 1, ...
let nats = iterator.range(1, 1000)   // 1, 2, ..., 1000

// Ленивые трансформации (не вычисляются сразу!)
let doubled = iterator.map(nats, fn(x) { x * 2 })
let evens = iterator.filter(nats, fn(x) { x % 2 == 0 })

// Материализация — здесь элементы вычисляются
iterator.to_list(iterator.take(doubled, 5))
// [2, 4, 6, 8, 10]
```

### unfold — создание итератора из функции

```gleam
// Числа Фибоначчи
let fibs = iterator.unfold(
  #(0, 1),
  fn(state) {
    let #(a, b) = state
    iterator.Next(element: a, accumulator: #(b, a + b))
  },
)

iterator.to_list(iterator.take(fibs, 8))
// [0, 1, 1, 2, 3, 5, 8, 13]
```

`unfold` принимает начальное состояние и функцию, которая на каждом шаге возвращает элемент и новое состояние. `iterator.Next` продолжает генерацию, `iterator.Done` завершает.

### iterate — бесконечная итерация

```gleam
// Степени двойки
let powers = iterator.iterate(1, fn(x) { x * 2 })
iterator.to_list(iterator.take(powers, 10))
// [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]
```

### Когда использовать Iterator вместо List

- Данные слишком большие, чтобы уместиться в памяти
- Нужны только первые N элементов из потенциально большой последовательности
- Вычисление каждого элемента дорогое

## Проект: модель файловой системы

Соберём изученные концепции, построив модель файловой системы. Определим рекурсивный тип — узел, который может быть файлом или директорией:

```gleam
pub type FSNode {
  File(name: String, size: Int)
  Directory(name: String, children: List(FSNode))
}
```

Это **рекурсивный тип**: `Directory` содержит `List(FSNode)`, то есть может хранить другие файлы и директории.

Создадим тестовое дерево:

```gleam
let fs = Directory("project", [
  File("README.md", 1024),
  Directory("src", [
    File("main.gleam", 2048),
    File("utils.gleam", 512),
  ]),
  Directory("test", [
    File("main_test.gleam", 1536),
  ]),
])
```

Это соответствует структуре:

```
project/
├── README.md          (1024 bytes)
├── src/
│   ├── main.gleam     (2048 bytes)
│   └── utils.gleam    (512 bytes)
└── test/
    └── main_test.gleam (1536 bytes)
```

Тип `FSNode` определён в `exercises/chapter04/src/chapter04.gleam` — вы импортируете его в решениях. Все упражнения этой главы работают с этим типом, постепенно наращивая сложность: от простого обхода дерева до группировки данных с помощью `Dict`.

## Упражнения

Решения пишите в файле `exercises/chapter04/test/my_solutions.gleam`. Тип `FSNode` уже импортирован. Запускайте тесты:

```sh
$ cd exercises/chapter04
$ gleam test
```

### 1. total_size (Лёгкое)

Вычислите общий размер узла файловой системы. Для файла — его размер, для директории — сумма размеров всех вложенных узлов (рекурсивно).

```gleam
pub fn total_size(node: FSNode) -> Int
```

**Примеры:**

```
total_size(File("a.txt", 100)) == 100
total_size(sample_fs) == 5120  // 1024 + 2048 + 512 + 1536
total_size(Directory("empty", [])) == 0
```

**Подсказка:** используйте case для разделения на `File` и `Directory`. Для директории пройдите `children` с помощью `list.fold`, рекурсивно вызывая `total_size`.

### 2. all_files (Лёгкое)

Соберите имена всех файлов в дереве в плоский список. Порядок — обход в глубину (depth-first).

```gleam
pub fn all_files(node: FSNode) -> List(String)
```

**Примеры:**

```
all_files(sample_fs)
== ["README.md", "main.gleam", "utils.gleam", "main_test.gleam"]

all_files(File("only.txt", 10))
== ["only.txt"]
```

**Подсказка:** для файла верните список из одного имени. Для директории используйте `list.flat_map` — она применит `all_files` к каждому дочернему узлу и объединит результаты.

### 3. find_by_extension (Среднее)

Найдите все файлы с заданным расширением.

```gleam
pub fn find_by_extension(node: FSNode, ext: String) -> List(String)
```

**Примеры:**

```
find_by_extension(sample_fs, ".gleam")
== ["main.gleam", "utils.gleam", "main_test.gleam"]

find_by_extension(sample_fs, ".md")
== ["README.md"]

find_by_extension(sample_fs, ".rs")
== []
```

**Подсказка:** похоже на `all_files`, но для файла проверяйте `string.ends_with(name, ext)`. Если не совпадает — возвращайте пустой список.

### 4. largest_file (Среднее)

Найдите самый большой файл в дереве. Верните пару `#(имя, размер)` или `Error(Nil)`, если файлов нет.

```gleam
pub fn largest_file(node: FSNode) -> Result(#(String, Int), Nil)
```

**Примеры:**

```
largest_file(sample_fs) == Ok(#("main.gleam", 2048))
largest_file(Directory("empty", [])) == Error(Nil)
```

**Подсказка:** сначала соберите все файлы как пары `#(имя, размер)` (напишите вспомогательную функцию, аналогичную `all_files`). Затем используйте `list.reduce` для поиска максимума — она вернёт `Error(Nil)` для пустого списка.

### 5. count_by_extension (Среднее)

Подсчитайте количество файлов каждого типа (по расширению). Результат — список пар `#(расширение, количество)`, отсортированный по расширению. Считайте, что все файлы имеют расширение формата `.xxx`.

```gleam
pub fn count_by_extension(node: FSNode) -> List(#(String, Int))
```

**Примеры:**

```
count_by_extension(sample_fs)
== [#(".gleam", 3), #(".md", 1)]
```

**Подсказка:** используйте `all_files` для сбора имён, извлеките расширение через `string.split(name, ".")`, сгруппируйте с `list.group`, посчитайте длины через `dict.map_values`, преобразуйте в отсортированный список.

### 6. group_by_directory (Сложное)

Сгруппируйте файлы по директории, в которой они непосредственно находятся. Результат — список пар `#(имя_директории, список_файлов)`, отсортированный по имени директории. Директории без прямых файлов-потомков не включаются.

```gleam
pub fn group_by_directory(node: FSNode) -> List(#(String, List(String)))
```

**Примеры:**

```
group_by_directory(sample_fs)
== [
  #("project", ["README.md"]),
  #("src", ["main.gleam", "utils.gleam"]),
  #("test", ["main_test.gleam"]),
]
```

**Подсказка:** напишите вспомогательную рекурсивную функцию: для директории отфильтруйте прямых детей-файлов через `list.filter_map`, рекурсивно обработайте поддиректории, объедините результаты. В конце отсортируйте по имени.

## Заключение

В этой главе мы изучили:

- Пользовательские типы — основу моделирования данных в Gleam
- Generics для создания обобщённых типов и функций
- Списки и богатый модуль `gleam/list`
- Dict, Set и Queue для различных задач
- Iterator для ленивых вычислений

Эти инструменты покрывают подавляющее большинство задач по работе с данными. В следующей главе мы глубже разберём рекурсию, свёртки и обработку ошибок через `Result` и `Option`.
