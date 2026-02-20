# Строки, битовые массивы и стандартная библиотека

> «Строки — не байты. Байты — не строки.» — Эрланговская мудрость

<!-- toc -->

## Цели главы

В этой главе мы:

- Детально изучим строки в Gleam: UTF-8, графемы, кодпоинты
- Разберём модуль `gleam/string` — полный обзор функций
- Познакомимся с `string_tree` для эффективной конкатенации
- Изучим битовые массивы (bit arrays) и паттерн-матчинг на них
- Освоим `gleam/regexp` для работы с регулярными выражениями
- Разберём `gleam/uri` для работы с URL
- Познакомимся с `gleam/pair` — утилитами для кортежей

## Строки в Gleam

Строки в Gleam — это **иммутабельные последовательности символов** в кодировке UTF-8. На BEAM-таргете они реализованы как Erlang-бинарники (`binary`), на JavaScript — как JS-строки.

### UTF-8 и графемы

UTF-8 — кодировка переменной длины: символ может занимать от 1 до 4 байтов. Это создаёт важное различие:

```gleam
import gleam/string

// Длина в графемах (пользовательских символах)
string.length("hello")  // 5
string.length("привет") // 6

// Размер в байтах
string.byte_size("hello")  // 5  — ASCII: 1 байт на символ
string.byte_size("привет") // 12 — кириллица: 2 байта на символ
```

**Графема** (grapheme) — то, что пользователь воспринимает как один символ. Функция `string.length` считает графемы, а не байты. Это правильное поведение для большинства задач.

### Кодпоинты

Кодпоинт (codepoint) — числовой код символа в Unicode:

```gleam
// Строка → список кодпоинтов
let cps = string.to_utf_codepoints("Abc")
// [UtfCodepoint(65), UtfCodepoint(98), UtfCodepoint(99)]

// Кодпоинт → число
let assert [cp, ..] = cps
string.utf_codepoint_to_int(cp)  // 65 — код буквы 'A'

// Число → кодпоинт
let assert Ok(cp) = string.utf_codepoint(97)  // 97 = 'a'
string.from_utf_codepoints([cp])  // "a"
```

Кодпоинты полезны при работе с символами на уровне Unicode — например, для шифров или транслитерации.

## gleam/string — полный обзор

Модуль `gleam/string` содержит около 40 функций. Разберём их по группам.

### Базовые

```gleam
string.length("hello")      // 5
string.is_empty("")          // True
string.is_empty("x")        // False
string.reverse("hello")     // "olleh"
string.compare("a", "b")    // order.Lt
string.byte_size("привет")  // 12
```

Базовые функции охватывают наиболее частые операции: проверку длины и пустоты строки, разворот символов и лексикографическое сравнение через `order.Lt`/`order.Eq`/`order.Gt`.

### Регистр

```gleam
string.lowercase("HELLO")    // "hello"
string.uppercase("hello")    // "HELLO"
string.capitalise("hello")   // "Hello"
```

`capitalise` переводит первую букву в верхний регистр, остальные — в нижний.

### Поиск

```gleam
string.contains("hello world", "world")  // True
string.starts_with("hello", "hel")       // True
string.ends_with("file.gleam", ".gleam") // True
```

Функции поиска возвращают `Bool` и позволяют быстро проверить вхождение подстроки без создания лишних промежуточных значений.

### Разбиение

```gleam
// split — по разделителю
string.split("a,b,c", ",")  // ["a", "b", "c"]

// split_once — только первое вхождение
string.split_once("a:b:c", ":")  // Ok(#("a", "b:c"))

// to_graphemes — в список графем
string.to_graphemes("hello")  // ["h", "e", "l", "l", "o"]

// pop_grapheme — отделить первый символ
string.pop_grapheme("hello")  // Ok(#("h", "ello"))
string.pop_grapheme("")       // Error(Nil)
```

Функции разбиения позволяют разложить строку на части: `split` и `split_once` делят по разделителю, а `to_graphemes` и `pop_grapheme` работают с отдельными символами.

### Сборка

```gleam
// append — конкатенация двух строк
string.append("hello", " world")  // "hello world"

// concat — конкатенация списка строк
string.concat(["hello", " ", "world"])  // "hello world"

// join — конкатенация с разделителем
string.join(["a", "b", "c"], ", ")  // "a, b, c"

// repeat — повторение строки
string.repeat("ha", 3)  // "hahaha"
```

Оператор `<>` тоже конкатенирует строки: `"hello" <> " world"`.

### Обрезка

```gleam
// trim — убрать пробелы с обоих сторон
string.trim("  hello  ")        // "hello"
string.trim_start("  hello  ")  // "hello  "
string.trim_end("  hello  ")    // "  hello"

// pad — дополнить до заданной длины
string.pad_start("42", 5, "0")  // "00042"
string.pad_end("hi", 10, ".")   // "hi........"
```

Функции обрезки убирают лишние пробелы с одного или обоих концов строки, а `pad_start`/`pad_end` дополняют строку до нужной длины заданным символом.

### Слайсы

```gleam
// slice — подстрока по позиции и длине
string.slice("hello world", 6, 5)  // "world"

// crop — подстрока от первого вхождения до конца
string.crop("hello world", "world")  // "world"

// drop_start / drop_end — отбросить символы
string.drop_start("hello", 2)  // "llo"
string.drop_end("hello", 2)    // "hel"

// first / last — первый/последний символ
string.first("hello")  // Ok("h")
string.last("hello")   // Ok("o")
string.first("")        // Error(Nil)
```

Функции срезов позволяют извлекать подстроки по позиции и длине (`slice`), от первого вхождения до конца (`crop`), а также получать или отбрасывать крайние символы.

### Замена

```gleam
string.replace("hello world", "world", "gleam")
// "hello gleam"

// Заменяет ВСЕ вхождения
string.replace("abcabc", "a", "x")
// "xbcxbc"
```

`string.replace` заменяет все вхождения подстроки в строке — эквивалент глобального поиска и замены без регулярных выражений.

### Утилиты

```gleam
// inspect — строковое представление любого значения
string.inspect(42)          // "42"
string.inspect([1, 2, 3])   // "[1, 2, 3]"
string.inspect(Ok("hi"))    // "Ok(\"hi\")"

// to_option — пустая строка → None
string.to_option("")      // None
string.to_option("hello") // Some("hello")
```

`string.inspect` полезна при отладке — она превращает любое значение Gleam в читаемую строку. `string.to_option` удобна для преобразования пустых строк в `None` при работе с опциональными значениями.

## String builder (gleam/string_tree)

Конкатенация строк через `<>` создаёт копию на каждом шаге — это O(n) для каждой операции. Для сборки строк из множества частей используйте `string_tree`:

```gleam
import gleam/string_tree

let tree =
  string_tree.new()
  |> string_tree.append("Hello")
  |> string_tree.append(", ")
  |> string_tree.append("world!")
  |> string_tree.to_string
// "Hello, world!"
```

На BEAM `string_tree` реализован как IO-лист (iolist) — дерево строк, которое «разворачивается» в плоскую строку только при необходимости. Это O(1) для каждого `append`.

### Когда использовать string_tree?

- Сборка HTML/JSON/шаблонов из множества частей
- Конкатенация в цикле/свёртке
- Генерация больших текстов

Для простой конкатенации 2-3 строк `<>` достаточно.

### Основные функции

```gleam
// Создание
string_tree.new()                   // пустой
string_tree.from_string("hello")    // из строки
string_tree.from_strings(["a", "b"]) // из списка строк

// Добавление
string_tree.append(tree, " suffix")       // добавить строку
string_tree.prepend(tree, "prefix ")      // добавить в начало
string_tree.append_tree(tree1, tree2)     // объединить деревья

// Преобразование
string_tree.to_string(tree)    // → String
string_tree.byte_size(tree)    // размер в байтах
string_tree.is_empty(tree)     // пусто ли

// Утилиты
string_tree.join([tree1, tree2], ", ")  // объединить с разделителем
string_tree.reverse(tree)              // развернуть
```

`string_tree` предоставляет те же операции, что и `gleam/string`, но без промежуточных копий: каждый `append` и `prepend` работает за O(1), а итоговая строка собирается один раз при вызове `to_string`.

## Битовые массивы

Битовые массивы (bit arrays) — последовательности байтов. Они используются для работы с бинарными данными: файлами, сетевыми протоколами, кодеками.

### Создание

```gleam
// Литерал
let bytes = <<1, 2, 3>>  // три байта

// Из строки
let text = <<"hello":utf8>>  // строка как UTF-8 байты

// Числа с указанием размера
let big = <<1024:16>>        // 16-битное число (2 байта)
let small = <<42:8>>         // 8-битное число (1 байт)

// Конкатенация
let combined = <<bytes:bits, text:bits>>
```

Литерал `<<...>>` позволяет задавать байты напрямую, встраивать строки как UTF-8, указывать разрядность чисел и конкатенировать несколько битовых массивов в один.

### gleam/bit_array — API

```gleam
import gleam/bit_array

// Конвертация строка ↔ байты
bit_array.from_string("hello")        // <<"hello":utf8>>
bit_array.to_string(<<"hello":utf8>>) // Ok("hello")

// Размер
bit_array.byte_size(<<1, 2, 3>>)  // 3

// Срез
bit_array.slice(<<1, 2, 3, 4, 5>>, 1, 3)  // Ok(<<2, 3, 4>>)

// Конкатенация
bit_array.concat([<<1, 2>>, <<3, 4>>])  // <<1, 2, 3, 4>>

// Проверка UTF-8
bit_array.is_utf8(<<"hello":utf8>>)  // True
bit_array.is_utf8(<<255, 254>>)      // False

// Base64
bit_array.base64_encode(<<"hello":utf8>>, True)
// "aGVsbG8="
bit_array.base64_decode("aGVsbG8=")
// Ok(<<"hello":utf8>>)

// Base16 (hex)
bit_array.base16_encode(<<255, 0, 127>>)
// "FF007F"
bit_array.base16_decode("FF007F")
// Ok(<<255, 0, 127>>)

// Inspect — для отладки
bit_array.inspect(<<72, 101>>)  // "<<72, 101>>"
```

Модуль `gleam/bit_array` предоставляет инструменты для преобразования бинарных данных: конвертацию строк, срезы, конкатенацию, кодирование в base64 и base16, а также проверку валидности UTF-8.

## Pattern matching на bit arrays

Одна из самых мощных возможностей Gleam (унаследованная от Erlang) — паттерн-матчинг на битовых массивах:

```gleam
import gleam/int

pub fn classify_ip(data: BitArray) -> String {
  case data {
    // IPv4: 4 байта
    <<a:8, b:8, c:8, d:8>> -> {
      "IPv4: "
      <> int.to_string(a) <> "."
      <> int.to_string(b) <> "."
      <> int.to_string(c) <> "."
      <> int.to_string(d)
    }
    _ -> "unknown"
  }
}

classify_ip(<<192, 168, 1, 1>>)
// "IPv4: 192.168.1.1"
```

Паттерн-матчинг на битовых массивах позволяет деструктурировать бинарные данные прямо в `case`-выражении, указывая точный размер каждого сегмента в битах — без ручного смещения и побитовых операций.

### Размеры сегментов

```gleam
case data {
  // Фиксированный размер в битах
  <<header:16, payload:bytes>> -> ...

  // Магические байты
  <<0x89, "PNG":utf8, rest:bytes>> -> "PNG file"

  // Конкретные значения байтов
  <<0xCA, 0xFE, rest:bytes>> -> ...
}
```

Доступные спецификаторы сегментов:

- `:8`, `:16`, `:32`, `:64` — размер в битах
- `:bytes` — остаток как байты
- `:bits` — остаток как биты
- `:utf8` — UTF-8 строка
- `:float` — 64-битное число с плавающей точкой

### Пример: простой парсер бинарного формата

```gleam
import gleam/bit_array
import gleam/result

pub type Packet {
  Packet(version: Int, payload: BitArray)
}

pub fn parse_packet(data: BitArray) -> Result(Packet, Nil) {
  case data {
    <<version:8, len:16, payload:bytes>> if bit_array.byte_size(payload) >= len ->
      Ok(Packet(version:, payload: bit_array.slice(payload, 0, len) |> result.unwrap(<<>>)))
    _ -> Error(Nil)
  }
}
```

Формат использует структуру TLV (Type-Length-Value):

- Первый байт (`version:8`) — версия протокола
- Следующие 2 байта (`len:16`) — длина полезной нагрузки (big-endian, до 65535)
- Остаток (`payload:bytes`) — данные произвольной длины

Гард `if bit_array.byte_size(payload) >= len` защищает от обрезанных пакетов: если данных меньше, чем заявлено в заголовке, возвращаем `Error(Nil)`. Затем `bit_array.slice` извлекает ровно `len` байтов — всё, что после, игнорируется (возможно, это следующий пакет).

## Bytes builder (gleam/bytes_tree)

Аналог `string_tree`, но для байтов:

```gleam
import gleam/bytes_tree

let tree =
  bytes_tree.new()
  |> bytes_tree.append(<<1, 2, 3>>)
  |> bytes_tree.append(<<4, 5>>)
  |> bytes_tree.to_bit_array
// <<1, 2, 3, 4, 5>>
```

`bytes_tree` используется при построении бинарных протоколов и HTTP-ответов (Wisp использует его для тел ответов).

### Основные функции

```gleam
bytes_tree.new()                        // пустой
bytes_tree.from_bit_array(<<1, 2>>)     // из BitArray
bytes_tree.from_string("hello")         // из строки (UTF-8)
bytes_tree.from_string_tree(st)         // из StringTree
bytes_tree.append(tree, <<3, 4>>)       // добавить байты
bytes_tree.append_string(tree, "text")  // добавить строку
bytes_tree.prepend(tree, <<0>>)         // добавить в начало
bytes_tree.concat([tree1, tree2])       // объединить список
bytes_tree.to_bit_array(tree)           // → BitArray
bytes_tree.byte_size(tree)              // размер в байтах
```

`bytes_tree` предлагает тот же набор операций, что и `string_tree`, но работает с `BitArray` вместо строк — удобно при сборке бинарных пакетов или HTTP-тел из нескольких фрагментов.

## Регулярные выражения (gleam/regexp)

Модуль `gleam/regexp` предоставляет поддержку регулярных выражений:

```gleam
import gleam/regexp

// Компиляция и проверка
let assert Ok(re) = regexp.from_string("^[a-z]+$")
regexp.check(re, "hello")  // True
regexp.check(re, "Hello")  // False
regexp.check(re, "123")    // False
```

Функция `regexp.check` проверяет, совпадает ли строка с регулярным выражением: сначала регулярное выражение компилируется один раз через `from_string`, а затем многократно применяется без повторной компиляции.

### Компиляция

```gleam
// from_string — простая компиляция
regexp.from_string("[0-9]+")  // Ok(Regexp) или Error(CompileError)

// compile — с опциями
regexp.compile("[a-z]+", regexp.Options(
  case_insensitive: True,
  multi_line: False,
))
// Ok(Regexp) — регистронезависимый поиск
```

`from_string` компилирует регулярное выражение и возвращает `Result` — ошибка компиляции (неверный синтаксис) обрабатывается явно, а `compile` позволяет задать дополнительные флаги, такие как регистронезависимость.

### Поиск совпадений

```gleam
let assert Ok(re) = regexp.from_string("(\\w+)@(\\w+)")

// scan — найти все совпадения
regexp.scan(re, "alice@example bob@test")
// [
//   Match(content: "alice@example", submatches: [Some("alice"), Some("example")]),
//   Match(content: "bob@test", submatches: [Some("bob"), Some("test")]),
// ]
```

Тип `Match` содержит:

- `content` — полное совпадение
- `submatches` — список захваченных групп (в скобках), каждая `Option(String)`

### Разбиение и замена

```gleam
let assert Ok(re) = regexp.from_string("[,;\\s]+")

// split — разбить строку по регулярному выражению
regexp.split(re, "a, b; c  d")
// ["a", "b", "c", "d"]

// replace — заменить совпадения
let assert Ok(digits) = regexp.from_string("[0-9]")
regexp.replace(digits, "h3ll0 w0rld", "*")
// "h*ll* w*rld"
```

`regexp.split` разбивает строку по регулярному выражению (удобно для разделителей переменной длины), а `regexp.replace` заменяет все совпадения на указанную строку.

### Практический пример: парсинг логов

```gleam
pub type LogEntry {
  LogEntry(level: String, message: String)
}

pub fn parse_log(line: String) -> Result(LogEntry, Nil) {
  let assert Ok(re) = regexp.from_string("\\[(\\w+)\\] (.+)")
  case regexp.scan(re, line) {
    [regexp.Match(_, [Some(level), Some(message)])] ->
      Ok(LogEntry(level:, message:))
    _ -> Error(Nil)
  }
}

parse_log("[ERROR] connection timeout")
// Ok(LogEntry(level: "ERROR", message: "connection timeout"))
```

Разберём по шагам:

1. Регулярное выражение `\[(\w+)\] (.+)` содержит две **группы захвата** (в скобках): `(\w+)` — одно или более «словесных» символов (уровень лога), и `(.+)` — всё после пробела (сообщение)
2. `regexp.scan` возвращает список `Match` — мы ожидаем ровно одно совпадение
3. Паттерн `[regexp.Match(_, [Some(level), Some(message)])]` деструктурирует результат: `_` — полное совпадение (нам не нужно), `Some(level)` и `Some(message)` — захваченные группы
4. Если строка не соответствует формату — попадаем в `_ -> Error(Nil)`

## URI (gleam/uri)

Модуль `gleam/uri` для работы с URL и URI:

```gleam
import gleam/uri

// Парсинг
let assert Ok(u) = uri.parse("https://example.com:8080/path?key=value#section")
u.scheme    // Some("https")
u.host      // Some("example.com")
u.port      // Some(8080)
u.path      // "/path"
u.query     // Some("key=value")
u.fragment  // Some("section")

// Сборка обратно в строку
uri.to_string(u)
// "https://example.com:8080/path?key=value#section"
```

`uri.parse` разбирает URL на составные части (схема, хост, порт, путь, параметры, фрагмент), возвращая `Result`, а `uri.to_string` собирает URI обратно в строку из этих полей.

### Query-параметры

```gleam
// Парсинг query string
uri.parse_query("name=Alice&age=30")
// Ok([#("name", "Alice"), #("age", "30")])

// Сборка query string
uri.query_to_string([#("search", "gleam lang"), #("page", "1")])
// "search=gleam+lang&page=1"
```

`uri.parse_query` разбирает строку параметров в список пар ключ-значение, а `uri.query_to_string` выполняет обратное преобразование с автоматическим percent-кодированием пробелов и спецсимволов.

### Кодирование

```gleam
// Percent-encoding
uri.percent_encode("hello world!")  // "hello%20world%21"
uri.percent_decode("hello%20world") // Ok("hello world")

// Сегменты пути
uri.path_segments("/api/v1/users")
// ["api", "v1", "users"]
```

`uri.percent_encode` и `uri.percent_decode` кодируют/декодируют спецсимволы в компонентах URI, а `uri.path_segments` разбивает путь на отдельные сегменты — удобно для маршрутизации.

### Origin и merge

```gleam
// origin — схема + хост + порт
let assert Ok(u) = uri.parse("https://example.com:8080/path")
uri.origin(u)  // Ok("https://example.com:8080")

// merge — разрешение относительного URI
let assert Ok(base) = uri.parse("https://example.com/a/b")
let assert Ok(relative) = uri.parse("../c")
uri.merge(base, relative)
// Ok(Uri(... path: "/c" ...))
```

`uri.origin` извлекает схему, хост и порт из URI — именно эту часть проверяют при CORS-запросах. `uri.merge` разрешает относительный URI относительно базового по правилам RFC 3986.

## gleam/pair

Утилиты для работы с кортежами из двух элементов:

```gleam
import gleam/pair

pair.first(#("hello", 42))   // "hello"
pair.second(#("hello", 42))  // 42

pair.swap(#("a", 1))         // #(1, "a")

pair.map_first(#("hello", 42), string.uppercase)
// #("HELLO", 42)

pair.map_second(#("hello", 42), fn(n) { n * 2 })
// #("hello", 84)

pair.new("key", "value")     // #("key", "value")
```

`pair` удобен в пайплайнах, когда нужно трансформировать один элемент кортежа:

```gleam
entries
|> list.map(pair.map_second(_, int.to_string))
```

Такой стиль позволяет избежать анонимных функций вида `fn(pair) { #(pair.0, transform(pair.1)) }` — функции `pair.map_first` и `pair.map_second` передаются в `list.map` напрямую.

## Проект: HTML builder

Соберём изученные модули в проекте — мини-библиотека для генерации HTML. Это практичный пример: такие билдеры используются внутри веб-фреймворков (например, Wisp отдаёт `string_tree` как тело ответа).

```gleam
import gleam/list
import gleam/string
import gleam/string_tree

/// Экранирование спецсимволов HTML.
/// Без этого строка вроде "<script>" станет рабочим тегом — это XSS-уязвимость.
pub fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

/// Рендер одного атрибута: ` key="value"` (с экранированием значения)
fn render_attr(attr: #(String, String)) -> String {
  " " <> attr.0 <> "=\"" <> escape_html(attr.1) <> "\""
}

/// Создание HTML-тега с атрибутами и содержимым
pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String {
  let attrs_str =
    attrs
    |> list.map(render_attr)
    |> string.concat
  "<" <> name <> attrs_str <> ">" <> children <> "</" <> name <> ">"
}

/// Сборка нескольких элементов через string_tree — O(1) на каждый append
pub fn render(elements: List(String)) -> String {
  elements
  |> list.fold(string_tree.new(), fn(tree, el) {
    string_tree.append(tree, el)
  })
  |> string_tree.to_string
}
```

Пример использования:

```gleam
let page =
  render([
    tag("h1", [], "Привет, Gleam!"),
    tag("p", [#("class", "intro")], "Это параграф."),
    tag("a", [#("href", "https://gleam.run")], "Сайт Gleam"),
  ])
// "<h1>Привет, Gleam!</h1><p class=\"intro\">Это параграф.</p><a href=\"https://gleam.run\">Сайт Gleam</a>"
```

Проект демонстрирует:

- `string.replace` — цепочка замен для экранирования
- `list.map` + `string.concat` — сборка атрибутов
- `string_tree` — эффективная конкатенация множества элементов
- Безопасность: экранирование пользовательского ввода для защиты от XSS

В упражнениях вы расширите этот билдер: добавите списки, таблицы и автолинковку.

## Упражнения

Все упражнения продолжают проект HTML builder — вы будете расширять его новыми возможностями.

Решения пишите в файле `exercises/chapter06/test/my_solutions.gleam`. Запускайте тесты:

```sh
cd exercises/chapter06
gleam test
```

Каждое упражнение добавляет новую функцию в HTML-билдер. Начните с первого и двигайтесь по порядку.

### 1. escape_html (Среднее)

Реализуйте экранирование HTML-спецсимволов. Это основа безопасного HTML — без экранирования пользовательский ввод вроде `<script>` превращается в рабочий код (XSS-атака).

```gleam
pub fn escape_html(text: String) -> String
```

Нужно заменить 5 символов:

- `&` → `&amp;` (важно заменить **первым**, иначе сломаете остальные замены)
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&#39;`

**Примеры:**

```text
escape_html("<script>alert('xss')</script>")
// "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"

escape_html("Tom & Jerry")
// "Tom &amp; Jerry"
```

**Подсказка:** цепочка вызовов `string.replace`.

### 2. tag (Среднее)

Создайте HTML-тег с именем, атрибутами и содержимым. Значения атрибутов должны быть экранированы через вашу функцию `escape_html`.

```gleam
pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String
```

**Примеры:**

```text
tag("p", [], "Hello")
// "<p>Hello</p>"

tag("a", [#("href", "https://gleam.run")], "Gleam")
// "<a href=\"https://gleam.run\">Gleam</a>"

tag("div", [#("class", "box"), #("id", "main")], "content")
// "<div class=\"box\" id=\"main\">content</div>"
```

**Подсказка:** для каждого атрибута `#(key, value)` сформируйте строку `key="value"`, затем соедините через `string.concat`.

### 3. build_list (Среднее)

Постройте HTML-список из элементов. Параметр `ordered` определяет тип: `<ol>` или `<ul>`.

```gleam
pub fn build_list(items: List(String), ordered: Bool) -> String
```

**Примеры:**

```text
build_list(["яблоко", "банан", "вишня"], False)
// "<ul><li>яблоко</li><li>банан</li><li>вишня</li></ul>"

build_list(["первый", "второй"], True)
// "<ol><li>первый</li><li>второй</li></ol>"
```

**Подсказка:** оберните каждый элемент в `<li>...</li>`, соедините, оберните в `<ul>` или `<ol>`. Можете использовать вашу функцию `tag`.

### 4. linkify (Средне-сложное)

Найдите URL в тексте с помощью регулярного выражения и оберните их в `<a>` теги.

```gleam
pub fn linkify(text: String) -> String
```

Считайте URL-ом любую подстроку, начинающуюся с `https://` или `http://`, за которой следуют один или более непробельных символов.

**Примеры:**

```text
linkify("Смотрите https://gleam.run — отличный язык")
// "Смотрите <a href=\"https://gleam.run\">https://gleam.run</a> — отличный язык"

linkify("нет ссылок тут")
// "нет ссылок тут"

linkify("два: http://a.com и https://b.org конец")
// "два: <a href=\"http://a.com\">http://a.com</a> и <a href=\"https://b.org\">https://b.org</a> конец"
```

**Подсказка:** используйте `regexp.scan` с паттерном `https?://\\S+`, чтобы найти все URL. Затем пройдите по совпадениям и замените каждый URL на `<a href="...">...</a>` через `string.replace`.

### 5. build_table (Сложное)

Постройте HTML-таблицу из заголовков и строк данных. Используйте `string_tree` для эффективной сборки.

```gleam
pub fn build_table(
  headers: List(String),
  rows: List(List(String)),
) -> String
```

**Примеры:**

```text
build_table(
  ["Имя", "Возраст"],
  [["Алиса", "30"], ["Боб", "25"]],
)
// "<table><thead><tr><th>Имя</th><th>Возраст</th></tr></thead><tbody><tr><td>Алиса</td><td>30</td></tr><tr><td>Боб</td><td>25</td></tr></tbody></table>"
```

**Подсказка:** разбейте задачу на части — сначала функция для одной строки (`<tr><td>...</td></tr>`), затем соберите `<thead>` из заголовков (с `<th>`) и `<tbody>` из строк данных. Используйте `string_tree` и `list.fold` для сборки.

## Заключение

В этой главе мы изучили:

- **Строки** — UTF-8, графемы, кодпоинты и богатый API `gleam/string`
- **String builder** (`gleam/string_tree`) — эффективная конкатенация через IO-списки
- **Битовые массивы** — бинарные данные, `<<>>` синтаксис, base64/base16
- **Pattern matching на bit arrays** — мощный инструмент для парсинга бинарных протоколов
- **Bytes builder** (`gleam/bytes_tree`) — эффективная сборка байтов
- **Regex** (`gleam/regexp`) — регулярные выражения для поиска и замены
- **URI** (`gleam/uri`) — парсинг и сборка URL
- **Pair** (`gleam/pair`) — утилиты для кортежей

В следующей главе мы перейдём к FFI, JSON и типобезопасному парсингу — научимся взаимодействовать с Erlang, обрабатывать JSON-данные и проектировать надёжные API через непрозрачные и фантомные типы.
