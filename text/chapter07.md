# Type Safety и Parse Don't Validate

> «Parse, don't validate» — Алексис Кинг

<!-- toc -->

## Цели главы

В этой главе мы:

- Поймём паттерн «Parse, Don't Validate»
- Изучим непрозрачные типы (opaque types) и smart constructors
- Разберём фантомные типы (phantom types) для типобезопасных контрактов
- Освоим `gleam_json` для кодирования и декодирования JSON
- Детально изучим `gleam/dynamic/decode`
- Применим Railway-Oriented Programming для композиции парсинга и валидации
- Построим PokeAPI-клиент, объединив все концепции

## Parse, Don't Validate

«Parse, Don't Validate» — паттерн проектирования, предложенный Алексис Кинг. Суть: вместо **проверки** данных с последующим использованием «сырых» типов, **парсите** неструктурированные данные в структурированные типы.

### Проблема: валидация

```gleam
// ❌ Плохо: проверяем, но тип остаётся String
pub fn send_email(to: String) -> Result(Nil, String) {
  case string.contains(to, "@") {
    True -> do_send(to)
    False -> Error("invalid email")
  }
}

// Ничто не мешает вызвать do_send с невалидным email
fn do_send(to: String) -> Result(Nil, String) { ... }
```

Проблема валидации: даже если мы проверили строку, тип `String` не несёт никакой информации о том, прошла ли она проверку — любой код может обойти валидацию и передать произвольную строку напрямую.

### Решение: парсинг

```gleam
// ✓ Хорошо: парсим String → Email, дальше работаем с Email
pub opaque type Email {
  Email(String)
}

pub fn parse_email(s: String) -> Result(Email, String) {
  case string.contains(s, "@") {
    True -> Ok(Email(s))
    False -> Error("некорректный email")
  }
}

pub fn send_email(to: Email) -> Result(Nil, String) {
  // Гарантированно валидный email!
  do_send(email_to_string(to))
}
```

Разница: `send_email` принимает `Email`, а не `String`. Единственный способ получить `Email` — через `parse_email`, которая проверяет формат. **Тип гарантирует валидность.**

## Контрактное программирование через типы

Непрозрачные типы (opaque types) реализуют **контракты** — предусловия, которые невозможно нарушить:

### Непрозрачные типы (opaque types)

`opaque type` скрывает конструктор от внешнего кода. Значение можно создать только через функции модуля:

```gleam
// В модуле positive.gleam
pub opaque type Positive {
  Positive(Int)
}

pub fn new(n: Int) -> Result(Positive, String) {
  case n > 0 {
    True -> Ok(Positive(n))
    False -> Error("число должно быть положительным")
  }
}

pub fn value(p: Positive) -> Int {
  let Positive(n) = p
  n
}

pub fn add(a: Positive, b: Positive) -> Positive {
  // Безопасно: сумма двух положительных всегда положительна
  Positive(value(a) + value(b))
}
```

Внешний код не может создать `Positive(-5)` — только через `new`, который проверяет инвариант. Все функции внутри модуля могут доверять, что `Positive` содержит положительное число.

### Smart constructors

Smart constructor — функция, создающая значение с проверкой:

```gleam
pub opaque type Age {
  Age(Int)
}

pub fn age(n: Int) -> Result(Age, String) {
  case n {
    _ if n < 0 -> Error("возраст не может быть отрицательным")
    _ if n > 150 -> Error("возраст слишком большой")
    _ -> Ok(Age(n))
  }
}

pub fn age_value(a: Age) -> Int {
  let Age(n) = a
  n
}
```

Паттерн:

1. `opaque type` скрывает конструктор
2. Smart constructor проверяет инварианты
3. Аксессоры дают доступ к данным
4. Все функции модуля доверяют инварианту

### Когда использовать opaque types?

- Email, URL, телефонный номер — форматированные строки
- Положительные числа, проценты, возраст — числа с ограничениями
- Идентификаторы — UUID, OrderId, UserId
- Токены — JWT, API-ключи

## Фантомные типы

Фантомный тип (phantom type) — параметр типа, который **не используется** в данных, но проверяется компилятором:

```gleam
pub opaque type Currency(unit) {
  Currency(amount: Int)
}

// Типы-метки (пустые, без значений)
pub type USD
pub type EUR

pub fn usd(amount: Int) -> Currency(USD) {
  Currency(amount)
}

pub fn eur(amount: Int) -> Currency(EUR) {
  Currency(amount)
}

pub fn add(a: Currency(unit), b: Currency(unit)) -> Currency(unit) {
  Currency(a.amount + b.amount)
}
```

Обратите внимание: `Currency(unit)` содержит только `Int`, но параметр `unit` отличает доллары от евро **на уровне типов**:

```gleam
let price = usd(100)
let tax = usd(20)
let total = add(price, tax)    // ✓ Ok: Currency(USD) + Currency(USD)

let euros = eur(50)
// add(price, euros)            // ✗ Ошибка компиляции!
// Expected Currency(USD), got Currency(EUR)
```

Компилятор не даст сложить доллары с евро — ошибка обнаруживается **до запуска** программы.

### Ещё примеры фантомных типов

```gleam
// Статус: проверенный vs непроверенный
pub type Verified
pub type Unverified

pub opaque type Document(status) {
  Document(content: String)
}

pub fn create(content: String) -> Document(Unverified) {
  Document(content:)
}

pub fn verify(doc: Document(Unverified)) -> Result(Document(Verified), String) {
  // ... проверка ...
  Ok(Document(content: doc.content))
}

pub fn publish(doc: Document(Verified)) -> Nil {
  // Можно публиковать только проверенные документы!
  ...
}
```

Фантомный тип `Document(status)` кодирует состояние документа прямо в сигнатуре типа: `publish` принимает только `Document(Verified)`, и компилятор не позволит передать непроверенный документ без явного вызова `verify`.

## gleam_json — кодирование и декодирование

Библиотека `gleam_json` предоставляет функции для работы с JSON.

### Кодирование (JSON → строка)

```gleam
import gleam/json

// Примитивы
json.string("hello")       // "hello"
json.int(42)               // 42
json.float(3.14)           // 3.14
json.bool(True)            // true
json.null()                // null

// Nullable — Some → значение, None → null
json.nullable(Some("hi"), json.string)  // "hi"
json.nullable(None, json.string)        // null

// Массивы
json.array([1, 2, 3], json.int)        // [1, 2, 3]
json.preprocessed_array([json.int(1), json.string("hi")])
// [1, "hi"]

// Объекты
json.object([
  #("name", json.string("Алиса")),
  #("age", json.int(30)),
  #("active", json.bool(True)),
])
// {"name":"Алиса","age":30,"active":true}

// Преобразование в строку
json.object([#("x", json.int(1))])
|> json.to_string
// "{\"x\":1}"

// С форматированием
json.object([#("x", json.int(1))])
|> json.to_string_tree
|> string_tree.to_string
```

Модуль `gleam/json` предоставляет строительные блоки для всех JSON-типов: примитивы конструируются отдельными функциями, объекты и массивы — через `json.object` и `json.array`, а итоговая строка получается вызовом `json.to_string`.

### Кодирование пользовательских типов

```gleam
pub type User {
  User(name: String, age: Int, email: String)
}

pub fn user_to_json(user: User) -> json.Json {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
    #("email", json.string(user.email)),
  ])
}

// Использование
User("Алиса", 30, "alice@example.com")
|> user_to_json
|> json.to_string
// {"name":"Алиса","age":30,"email":"alice@example.com"}
```

Для каждого пользовательского типа создаётся функция-кодировщик, которая отображает поля Gleam-структуры в пары ключ-значение JSON — такой подход легко масштабируется на вложенные типы.

### Декодирование

Декодирование — преобразование JSON-строки обратно в Gleam-типы. Это двухшаговый процесс:

1. **Парсинг**: строка → Dynamic (нетипизированные данные)
2. **Декодирование**: Dynamic → типизированное значение

```gleam
import gleam/dynamic/decode
import gleam/json

// Декодер для User
pub fn user_decoder() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  use email <- decode.field("email", decode.string)
  decode.success(User(name:, age:, email:))
}

// Парсинг JSON-строки
json.parse("{\"name\":\"Алиса\",\"age\":30,\"email\":\"a@b.com\"}", user_decoder())
// Ok(User("Алиса", 30, "a@b.com"))

json.parse("{\"name\":\"Алиса\"}", user_decoder())
// Error(...) — не хватает полей
```

`json.parse` объединяет парсинг строки и применение декодера в один шаг: если JSON некорректен или не соответствует структуре декодера, возвращается `Error` с описанием проблемы.

## gleam/dynamic/decode — полный обзор

Модуль `gleam/dynamic/decode` предоставляет типобезопасные декодеры для работы с нетипизированными данными.

### Примитивные декодеры

```gleam
import gleam/dynamic/decode

decode.string    // Decoder(String)
decode.int       // Decoder(Int)
decode.float     // Decoder(Float)
decode.bool      // Decoder(Bool)
decode.bit_array // Decoder(BitArray)
decode.dynamic   // Decoder(Dynamic) — пропускает как есть
```

Примитивные декодеры — это готовые значения типа `Decoder(T)`, которые извлекают соответствующий тип из динамических данных и возвращают ошибку, если тип не совпадает.

### Поля объектов

```gleam
// field — обязательное поле
use name <- decode.field("name", decode.string)

// optional_field — может отсутствовать
use nickname <- decode.optional_field("nickname", None, decode.string)

// subfield — вложенное поле (путь)
use city <- decode.subfield(["address", "city"], decode.string)

// at — по индексу в массиве
use first <- decode.at([0], decode.string)
```

`decode.field` извлекает обязательное поле объекта, `decode.optional_field` возвращает `None` если поле отсутствует, а `decode.subfield` позволяет обращаться к глубоко вложенным полям по пути из ключей.

### Коллекции

```gleam
// list — массив
decode.list(decode.int)  // Decoder(List(Int))

// dict — объект как словарь
decode.dict(decode.string, decode.int)  // Decoder(Dict(String, Int))

// optional — nullable значение
decode.optional(decode.string)  // Decoder(Option(String))
```

Декодеры коллекций оборачивают декодер элемента: `decode.list` применяет его к каждому элементу массива, `decode.dict` — к ключам и значениям объекта, `decode.optional` обрабатывает `null` как `None`.

### Комбинаторы

```gleam
// one_of — попробовать несколько декодеров
decode.one_of(decode.string, [
  decode.int |> decode.map(int.to_string),
])
// Попробует string, если не получится — int → string

// then — зависимый декодер
use type_name <- decode.field("type", decode.string)
decode.then(fn() {
  case type_name {
    "circle" -> circle_decoder()
    "rect" -> rect_decoder()
    _ -> decode.failure(UnknownShape, "Shape")
  }
})

// success — декодер, который всегда успешен
decode.success(42)  // Decoder(Int) — всегда вернёт 42

// failure — декодер, который всегда неуспешен
decode.failure(MyError, "expected something else")
```

Комбинаторы позволяют строить гибкие декодеры: `decode.one_of` перебирает альтернативы по порядку, `decode.then` создаёт зависимые декодеры на основе уже декодированного значения, а `decode.map` трансформирует результат без изменения структуры.

### Пример: вложенная структура

```gleam
pub type Address {
  Address(city: String, street: String)
}

pub type Person {
  Person(name: String, age: Int, address: Address)
}

pub fn address_decoder() -> decode.Decoder(Address) {
  use city <- decode.field("city", decode.string)
  use street <- decode.field("street", decode.string)
  decode.success(Address(city:, street:))
}

pub fn person_decoder() -> decode.Decoder(Person) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  use address <- decode.field("address", address_decoder())
  decode.success(Person(name:, age:, address:))
}

// Парсинг
let json_str = "{
  \"name\": \"Алиса\",
  \"age\": 30,
  \"address\": {\"city\": \"Москва\", \"street\": \"Тверская\"}
}"
json.parse(json_str, person_decoder())
// Ok(Person("Алиса", 30, Address("Москва", "Тверская")))
```

Вложенные структуры декодируются путём передачи одного декодера в качестве аргумента другому: `decode.field("address", address_decoder())` автоматически применит `address_decoder` к значению поля `"address"`.

### Рекурсивные декодеры

Для рекурсивных структур используйте `decode.recursive`:

```gleam
pub type Tree {
  Leaf(value: Int)
  Node(left: Tree, right: Tree)
}

pub fn tree_decoder() -> decode.Decoder(Tree) {
  decode.one_of(leaf_decoder(), [node_decoder()])
}

fn leaf_decoder() -> decode.Decoder(Tree) {
  use value <- decode.field("value", decode.int)
  decode.success(Leaf(value:))
}

fn node_decoder() -> decode.Decoder(Tree) {
  use left <- decode.field("left", decode.recursive(tree_decoder))
  use right <- decode.field("right", decode.recursive(tree_decoder))
  decode.success(Node(left:, right:))
}
```

`decode.recursive` нужен, чтобы избежать бесконечной рекурсии при создании декодера — он откладывает вычисление до момента использования.

## Railway-Oriented Programming — практика

Объединим всё в ROP-цепочку: сырые данные → парсинг → декодирование → валидация → доменный тип:

```gleam
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/result
import gleam/string

pub opaque type ValidUser {
  ValidUser(name: String, age: Int, email: String)
}

pub fn valid_user_name(u: ValidUser) -> String { u.name }
pub fn valid_user_age(u: ValidUser) -> Int { u.age }
pub fn valid_user_email(u: ValidUser) -> String { u.email }

type RawUser {
  RawUser(name: String, age: Int, email: String)
}

fn raw_user_decoder() -> decode.Decoder(RawUser) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  use email <- decode.field("email", decode.string)
  decode.success(RawUser(name:, age:, email:))
}

pub fn parse_valid_user(json_str: String) -> Result(ValidUser, String) {
  // 1. Парсинг JSON
  use raw <- result.try(
    json.parse(json_str, raw_user_decoder())
    |> result.map_error(fn(_) { "некорректный JSON" }),
  )
  // 2. Валидация имени
  use _ <- result.try(case string.length(raw.name) >= 2 {
    True -> Ok(Nil)
    False -> Error("имя слишком короткое")
  })
  // 3. Валидация email
  use _ <- result.try(case string.contains(raw.email, "@") {
    True -> Ok(Nil)
    False -> Error("некорректный email")
  })
  // 4. Валидация возраста
  use _ <- result.try(case raw.age >= 0 && raw.age <= 150 {
    True -> Ok(Nil)
    False -> Error("некорректный возраст")
  })
  // 5. Создание доменного типа
  Ok(ValidUser(name: raw.name, age: raw.age, email: raw.email))
}
```

Каждый шаг может вернуть ошибку, и цепочка `result.try` прервётся на первом `Error`. Результат — либо полностью валидный `ValidUser`, либо описание ошибки.

## Проект: PokeAPI клиент

Объединим все концепции в практическом проекте — клиенте для [PokeAPI](https://pokeapi.co/). API возвращает JSON с информацией о покемонах.

### Доменная модель

```gleam
pub type Pokemon {
  Pokemon(
    id: Int,
    name: String,
    height: Int,
    weight: Int,
    types: List(String),
  )
}
```

Доменная модель описывает только те поля PokeAPI-ответа, которые нужны приложению — id, название, размеры и список типов — игнорируя всё остальное.

### Декодер

PokeAPI возвращает вложенную структуру. Типы покемона находятся в `types[].type.name`:

```json
{
  "id": 25,
  "name": "pikachu",
  "height": 4,
  "weight": 60,
  "types": [
    {"slot": 1, "type": {"name": "electric", "url": "..."}}
  ]
}
```

Декодер:

```gleam
import gleam/dynamic/decode

pub fn pokemon_decoder() -> decode.Decoder(Pokemon) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use height <- decode.field("height", decode.int)
  use weight <- decode.field("weight", decode.int)
  use types <- decode.field("types", decode.list(type_name_decoder()))
  decode.success(Pokemon(id:, name:, height:, weight:, types:))
}

fn type_name_decoder() -> decode.Decoder(String) {
  use name <- decode.subfield(["type", "name"], decode.string)
  decode.success(name)
}
```

`pokemon_decoder` компонует несколько `decode.field` через `use`-синтаксис, а вспомогательный `type_name_decoder` использует `decode.subfield` для навигации по вложенной структуре `types[].type.name`.

### HTTP-запрос (для `gleam run`, не для тестов)

В реальном приложении запрос делается через `gleam_httpc`:

```gleam
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result

pub fn fetch_pokemon(name: String) -> Result(Pokemon, String) {
  let url = "https://pokeapi.co/api/v2/pokemon/" <> name

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { "некорректный URL" }),
  )
  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(_) { "ошибка HTTP-запроса" }),
  )
  use pokemon <- result.try(
    json.parse(resp.body, pokemon_decoder())
    |> result.map_error(fn(_) { "ошибка декодирования JSON" }),
  )
  Ok(pokemon)
}
```

> **Примечание:** в тестах мы **не** делаем реальных HTTP-запросов. Вместо этого используем захардкоженный JSON-ответ. Это стандартная практика — тесты должны быть быстрыми и детерминированными.

### Парсинг без сети (для тестов)

```gleam
pub fn parse_pokemon(json_str: String) -> Result(Pokemon, Nil) {
  json.parse(json_str, pokemon_decoder())
  |> result.map_error(fn(_) { Nil })
}
```

`parse_pokemon` — упрощённая версия без HTTP-запроса: она принимает уже готовую JSON-строку и применяет декодер, что делает функцию удобной для тестирования с захардкоженными данными.

## Упражнения

Все упражнения этой главы складываются в мини-проект **PokeDex CLI** — консольное приложение для работы с данными о покемонах. Каждое упражнение — это строительный блок реального приложения.

Решения пишите в файле `exercises/chapter07/test/my_solutions.gleam`. Запускайте тесты:

```sh
cd exercises/chapter07
gleam test
```

Запускайте тесты после каждого упражнения — они проверяют корректность реализации и подскажут, что ещё нужно доделать.

### 1. PokemonId — opaque type + smart constructor (Лёгкое)

Создайте непрозрачный тип `PokemonId` для валидного ID покемона (диапазон 1–1025, как в реальной PokéAPI).

```gleam
pub opaque type PokemonId {
  PokemonId(Int)
}

pub fn pokemon_id_new(id: Int) -> Result(PokemonId, String)
pub fn pokemon_id_value(id: PokemonId) -> Int
pub fn pokemon_id_to_path(id: PokemonId) -> String
```

**Примеры:**

```text
pokemon_id_new(25) |> result.is_ok == True
pokemon_id_new(0) |> result.is_error == True
pokemon_id_new(1026) |> result.is_error == True
pokemon_id_to_path(pokemon_id_new(25) |> result.unwrap(..))
== "/api/v2/pokemon/25"
```

**Подсказка:** `pokemon_id_to_path` формирует строку `"/api/v2/pokemon/" <> int.to_string(id)`.

### 2. pokemon_decoder — расширенный декодер (Среднее)

Расширьте тип `Pokemon` полями `abilities` и `stats`, затем реализуйте декодер для реального формата PokeAPI.

```gleam
pub type PokemonStat {
  PokemonStat(name: String, base_value: Int)
}

pub type Pokemon {
  Pokemon(
    id: Int, name: String, height: Int, weight: Int,
    types: List(String),
    abilities: List(String),
    stats: List(PokemonStat),
  )
}

pub fn pokemon_decoder() -> decode.Decoder(Pokemon)
pub fn parse_pokemon(json_str: String) -> Result(Pokemon, Nil)
```

Структура JSON PokeAPI:

```json
{
  "types": [{"slot": 1, "type": {"name": "electric", "url": "..."}}],
  "abilities": [{"ability": {"name": "static", "url": ""}, "is_hidden": false, "slot": 1}],
  "stats": [{"base_stat": 35, "effort": 0, "stat": {"name": "hp", "url": ""}}]
}
```

**Подсказка:** создайте три вспомогательных декодера — `type_name_decoder` (через `decode.subfield(["type", "name"], ...)`), `ability_name_decoder` (через `decode.subfield(["ability", "name"], ...)`), `stat_decoder` (поле `"base_stat"` + subfield `["stat", "name"]`).

### 3. pokemon_to_json — кодирование в JSON (Среднее)

Закодируйте `Pokemon` в компактный JSON-формат (для кеширования, не в формате PokeAPI).

```gleam
pub fn stat_to_json(stat: PokemonStat) -> json.Json
pub fn pokemon_to_json(pokemon: Pokemon) -> json.Json
```

**Формат:** плоский объект с полями `id`, `name`, `height`, `weight`, `types` (массив строк), `abilities` (массив строк), `stats` (массив объектов `{name, base_value}`).

**Подсказка:** используйте `json.object`, `json.string`, `json.int`, `json.array`.

### 4. search_results_decoder — пагинированный список (Среднее)

Декодируйте ответ PokeAPI для списка покемонов с пагинацией.

```gleam
pub type NamedResource {
  NamedResource(name: String, url: String)
}

pub type SearchResults {
  SearchResults(
    count: Int,
    next: Option(String),
    previous: Option(String),
    results: List(NamedResource),
  )
}

pub fn decode_search_results(json_str: String) -> Result(SearchResults, Nil)
```

Поля `next` и `previous` — nullable (`null` на первой/последней странице).

**Подсказка:** используйте `decode.optional(decode.string)` для nullable-полей. Это **не** `decode.optional_field` — поле всегда присутствует, но его значение может быть `null`.

### 5. DamageMultiplier — фантомные типы (Среднее-Сложное)

Реализуйте типобезопасный множитель урона с фантомными типами `Physical` / `Special`. Компилятор не позволит перемножить физический и специальный множители.

```gleam
pub type Physical
pub type Special

pub opaque type DamageMultiplier(category) {
  DamageMultiplier(Float)
}

pub fn physical(value: Float) -> Result(DamageMultiplier(Physical), String)
pub fn special(value: Float) -> Result(DamageMultiplier(Special), String)
pub fn multiplier_value(m: DamageMultiplier(a)) -> Float
pub fn combine(a: DamageMultiplier(cat), b: DamageMultiplier(cat)) -> DamageMultiplier(cat)
pub fn apply_damage(base: Int, m: DamageMultiplier(a)) -> Int
```

**Примеры:**

```text
physical(1.5) |> result.unwrap(..) |> multiplier_value == 1.5
physical(-0.5) |> result.is_error == True
// combine умножает два множителя:
combine(physical(1.5), physical(2.0)) |> multiplier_value == 3.0
// apply_damage: base * multiplier, округлено вниз
apply_damage(100, physical(1.5)) == 150
// combine(physical(1.5), special(2.0)) — ошибка компиляции!
```

Фантомный тип не позволяет перемножить физический и специальный множители, а `combine` соединяет два множителя одной категории, перемножая их значения.

### 6. format_pokemon_card — CLI-вывод (Среднее)

Отформатируйте покемона для красивого вывода в CLI.

```gleam
pub fn format_pokemon_card(pokemon: Pokemon) -> String
pub fn format_stat_bar(stat: PokemonStat) -> String
```

**format_pokemon_card** возвращает:

```text
#025 Pikachu
Тип: electric
Способности: static, lightning-rod
```

- ID дополняется нулями до 3 цифр (`#006`, `#025`), но 4-значные не обрезаются (`#1025`)
- Имя покемона с заглавной буквы (`pikachu` → `Pikachu`)

**format_stat_bar** возвращает:

```text
hp              [##.............] 35
```

- Имя стата — 16 символов (дополнено пробелами справа)
- Бар — 15 символов: `#` — заполненные, `.` — пустые
- Масштаб: 0–255 → 0–15 символов (используйте `float.round`)
- Значение в конце

**Подсказка:** для zero-padding используйте `string.repeat("0", pad) <> int.to_string(id)`.

### 7. build_pokedex_entry — ROP-цепочка (Сложное)

Постройте полный конвейер: JSON-строка → покемон → валидация → отформатированная карточка.

```gleam
pub type PokedexError {
  InvalidJson
  InvalidPokemonId
  MissingTypes
  MissingAbilities
}

pub fn build_pokedex_entry(json_str: String) -> Result(String, PokedexError)
```

Цепочка (используйте `result.try`):

1. Распарсить JSON в `Pokemon` → ошибка `InvalidJson`
2. Проверить `id` в диапазоне 1–1025 → ошибка `InvalidPokemonId`
3. Проверить `types` не пуст → ошибка `MissingTypes`
4. Проверить `abilities` не пуст → ошибка `MissingAbilities`
5. Отформатировать через `format_pokemon_card`

**Примеры:**

```text
build_pokedex_entry(pikachu_json) |> result.is_ok == True
build_pokedex_entry("not json") == Error(InvalidJson)
build_pokedex_entry(pokemon_with_id_99999) == Error(InvalidPokemonId)
```

**Подсказка:** каждый шаг — `use _ <- result.try(...)`, как в примере с `parse_valid_user`.

## Заключение

В этой главе мы изучили фундаментальные принципы типобезопасного программирования в Gleam:

- **Parse, Don't Validate** — превращение проверок в гарантии типов
- **Opaque types и smart constructors** — сокрытие реализации и поддержание инвариантов
- **Phantom types** — безопасность на уровне типов без накладных расходов
- **gleam_json и gleam/dynamic/decode** — типобезопасная работа с JSON
- **Railway-Oriented Programming** — композиция парсинга, декодирования и валидации

Эти паттерны — основа надёжных систем. Компилятор становится союзником: он не даст передать невалидный email, сложить доллары с евро или опубликовать непроверенный документ.

В следующих главах мы изучим, как взаимодействовать с Erlang и JavaScript платформами через FFI, расширяя возможности Gleam за счёт богатых экосистем обеих платформ.
