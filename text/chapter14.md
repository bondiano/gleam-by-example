# Заключение и следующие шаги

Поздравляем! Вы завершили курс "Gleam by Example" и прошли путь от основ функционального программирования до создания production-ready приложений на платформе BEAM и в браузере.

<!-- toc -->

## Путь, который мы прошли

За 13 глав вы освоили:

### Основы Gleam (главы 1-6)

- **Функциональное программирование**: иммутабельность, pattern matching, функции высшего порядка
- **Система типов**: статическая типизация, вывод типов, Result и Option
- **Коллекции**: списки, кортежи, словари, множества
- **Рекурсия и свёртки**: рекурсивные алгоритмы, list.fold
- **Обработка ошибок**: паттерн Result, монадический style, Railway-Oriented Programming
- **Битовые массивы**: работа с бинарными данными, парсинг протоколов

### Продвинутые концепции (главы 7-9)

- **Type Safety**: Parse Don't Validate, opaque types, phantom types
- **Валидация данных**: gleam/dynamic/decode, типобезопасный парсинг JSON
- **Erlang FFI**: интеграция с BEAM экосистемой, работа с файлами, процессами
- **JavaScript FFI**: фронтенд-разработка, DOM API, промисы, localStorage

### Production-ready разработка (главы 10-13)

- **Процессы и OTP**: акторы, супервизоры, fault tolerance
- **Тестирование**: модульные тесты, Property-Based Testing с qcheck, snapshot testing
- **Веб-разработка**: HTTP-серверы на Wisp, REST API, PostgreSQL, middleware
- **Фронтенд**: Lustre framework, MVU-архитектура, SSR, компоненты

### Практические навыки

- Построили PokeAPI-клиент с типобезопасным парсингом
- Создали TODO API с PostgreSQL-хранилищем
- Разработали Lustre-приложение с server-side rendering
- Написали Telegram-бота с FSM и персистентностью

## Что дальше изучать

### Углублённые темы Gleam

#### 1. Реализация OTP behaviours

Gleam поддерживает стандартные OTP-паттерны:

```gleam
import gleam/otp/supervisor
import gleam/otp/task

// Supervisor с несколькими workers
pub fn start() {
  supervisor.start(fn(children) {
    children
    |> supervisor.add(supervisor.worker(start_db_pool))
    |> supervisor.add(supervisor.worker(start_api_server))
    |> supervisor.add(supervisor.worker(start_background_jobs))
  })
}
```

**Ресурсы:**

- Документация gleam_otp: https://hexdocs.pm/gleam_otp/
- Примеры OTP-приложений: https://github.com/gleam-lang/otp

#### 2. Генераторы кода и макросы

Хотя Gleam не поддерживает макросы напрямую, можно использовать codegen для повторяющихся паттернов:

```gleam
// Генерация SQL-запросов через Squirrel
// https://github.com/giacomocavalieri/squirrel
```

#### 3. Производительность и профилирование

BEAM предоставляет мощные инструменты профилирования:

```bash
# Профилирование через :observer
gleam run -m erlang -- -s observer start

# Flamegraphs для production
# https://github.com/gleam-lang/gleam_erlang_profiler
```

### Экосистема BEAM

#### Распределённые системы

BEAM создан для распределённых приложений:

```gleam
// Подключение к удалённым нодам
import gleam/erlang/node

pub fn connect_cluster() {
  node.connect("app@server1.example.com")
  node.connect("app@server2.example.com")
}
```

**Изучите:**

- Distributed Erlang: http://www.erlang.org/doc/reference_manual/distributed.html
- libcluster для автоматического обнаружения нод
- Horde для распределённых супервизоров

#### Горячая перезагрузка кода

BEAM позволяет обновлять код без остановки приложения:

```bash
# Compile и загрузить новый код
gleam build
# Релиз-менеджер загрузит модули без downtime
```

**Ресурсы:**

- https://www.erlang.org/doc/design_principles/release_handling

#### Observability

Мониторинг production-систем:

```gleam
import telemetry

pub fn track_request(duration: Int) {
  telemetry.emit("http.request", [#("duration", duration)])
}
```

**Инструменты:**

- Telemetry для метрик: https://hexdocs.pm/telemetry/
- Phoenix LiveDashboard (адаптируется для Gleam-приложений)
- Grafana + Prometheus для визуализации

### Специализация

#### Real-time приложения

WebSockets, Server-Sent Events, Phoenix Channels:

```gleam
import mist/websocket

pub fn handle_websocket(req) {
  websocket.upgrade(req, fn(conn) {
    // Обработка WebSocket-сообщений
    websocket.send(conn, "Hello from Gleam!")
  })
}
```

**Проекты:**

- Чат-приложение с WebSocket
- Live dashboard с SSE
- Multiplayer-игра

#### Embedded системы (Nerves)

Gleam работает на Raspberry Pi и других embedded-устройствах через Nerves:

```bash
# Установка Nerves
mix archive.install hex nerves_bootstrap

# Создание Nerves-проекта с Gleam
mix nerves.new my_app --target rpi4
```

**Ресурсы:**

- https://nerves-project.org/
- Gleam + Nerves примеры: https://github.com/nerves-project

#### CLI утилиты

Gleam отлично подходит для command-line инструментов:

```gleam
import glint

pub fn main() {
  glint.new()
  |> glint.add_command("build", build_command)
  |> glint.add_command("test", test_command)
  |> glint.run(argv)
}
```

**Библиотеки:**

- glint: https://hexdocs.pm/glint/ (CLI framework)
- shellout: выполнение shell-команд
- gleam_json: парсинг конфигурационных файлов

## Ресурсы сообщества

### Официальные каналы

- **Discord**: https://discord.gg/gleam (самое активное сообщество, ~10k участников)
- **GitHub Discussions**: https://github.com/gleam-lang/gleam/discussions
- **Форум**: https://gleam.run/community/

### Обучающие материалы

- **Awesome Gleam**: https://github.com/gleam-lang/awesome-gleam (каталог библиотек)
- **Gleam Weekly newsletter**: https://gleam.run/news/
- **Exercism Gleam track**: https://exercism.org/tracks/gleam (интерактивные упражнения)
- **YouTube**: Gleam Programming Language канал (конференции, туториалы)

### Блоги и статьи

- **Официальный блог**: https://gleam.run/news/
- **Hayleigh Thompson**: https://hayleigh.dev/ (maintainer Lustre)
- **Louis Pilfold**: https://lpil.uk/ (создатель Gleam)

### Книги и курсы

- **"Learn You Some Erlang"**: классика для понимания BEAM (применимо к Gleam)
- **"Designing for Scalability with Erlang/OTP"**: паттерны для production-систем

## Как внести вклад

Gleam — молодой и активно развивающийся язык. Сообщество приветствует вклад на любом уровне.

### Вклад в Gleam

- **Открыть issue/PR в Gleam**: https://github.com/gleam-lang/gleam
  - Баг-репорты
  - Feature requests
  - Улучшения документации
  - Исправления в компиляторе (написан на Rust)

### Написать библиотеку

Экосистема Gleam активно растёт. Популярные направления:

- **Парсеры**: JSON, TOML, YAML, XML
- **HTTP-клиенты**: обёртки над hackney/httpc
- **База данных**: драйверы для MySQL, SQLite, Redis
- **Утилиты**: работа с датами, валидация, крипто

**Как начать:**

```bash
gleam new my_awesome_lib
cd my_awesome_lib
gleam add gleam_stdlib

# Опубликовать на Hex.pm
gleam publish
```

### Перевести документацию

Русскоязычное сообщество Gleam растёт. Можно:

- Перевести официальную документацию
- Написать туториалы на русском
- Создать обучающие видео

### Поделиться опытом

- Написать статью о миграции проекта на Gleam
- Выступить на митапе/конференции
- Создать open-source проект и рассказать о нём

## Практические проекты для закрепления

Теперь, когда вы знаете Gleam, закрепите знания на реальных проектах:

### Уровень 1: Библиотеки и утилиты

1. **URL-парсер** (практика: parse don't validate, opaque types)
2. **Markdown → HTML конвертер** (практика: рекурсия, pattern matching)
3. **CSV-парсер** (практика: bit arrays, Result-based error handling)

### Уровень 2: Веб-приложения

1. **URL shortener** (практика: Wisp, PostgreSQL, валидация)
2. **Pastebin-клон** (практика: файлы, кэш, syntax highlighting)
3. **RSS-агрегатор** (практика: HTTP-клиенты, cron-задачи, атомы)

### Уровень 3: Real-time системы

1. **WebSocket чат** (практика: mist/websocket, процессы, state)
2. **Live quiz платформа** (практика: SSE, Lustre, временные ограничения)
3. **Multiplayer game** (практика: game loop, синхронизация, latency)

### Уровень 4: Распределённые системы

1. **Distributed task queue** (практика: OTP, распределённые акторы, supervisor trees)
2. **Multi-node чат** (практика: distributed Erlang, node.connect)
3. **Metrics aggregator** (практика: telemetry, time series, persistence)

## Заключительные мысли

Gleam сочетает элегантность функциональных языков с мощью платформы BEAM. Вы получили:

- **Type safety** без runtime-overhead
- **Конкурентность** через легковесные процессы
- **Fault tolerance** благодаря OTP
- **Универсальность**: backend, frontend, CLI, embedded

Ключевые принципы, которые стоит помнить:

1. **"Parse, Don't Validate"** — делайте невалидные состояния непредставимыми
2. **"Let It Crash"** — не бойтесь падений, используйте супервизоры
3. **"Immutability by Default"** — иммутабельность упрощает рассуждения о коде
4. **"Railway-Oriented Programming"** — композируйте операции через Result

Gleam только начинает свой путь. Присоединяйтесь к сообществу, стройте классные проекты, делитесь знаниями. Удачи в ваших Gleam-приключениях! ✨

---

**Дополнительные ресурсы:**

- Gleam Language Tour: https://tour.gleam.run/
- Gleam Standard Library: https://hexdocs.pm/gleam_stdlib/
- Awesome Gleam: https://github.com/gleam-lang/awesome-gleam
- Discord: https://discord.gg/gleam

*Спасибо, что прочли эту книгу. Надеемся, она была полезна! Если у вас есть предложения, откройте issue на GitHub.*
