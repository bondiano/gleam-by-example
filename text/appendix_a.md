# Telegram-бот с Telega

> Полноценный Telegram-бот: команды, роутер, middleware, inline-клавиатуры и тестирование.

<!-- toc -->

## Цели главы

В этой главе мы:

- Познакомимся с Telega — библиотекой для Telegram-ботов на Gleam
- Научимся строить роутер для обработки команд и сообщений
- Освоим **Session** — встроенное хранилище данных пользователя
- Изучим **Conversation API** — линейные многошаговые диалоги через `wait_*` функции
- Разберём **Flow API** — персистентные конечные автоматы с навигацией
- Рассмотрим inline-клавиатуры, callback queries и валидацию ввода
- Поймём архитектуру дерева супервизоров бота
- Научимся тестировать бота через `telega/testing`

## Как работают Telegram-боты

Telegram предоставляет два способа получения обновлений от пользователей: **long polling** и **webhooks**. Выбор между ними — один из первых архитектурных решений при создании бота.

### Long Polling — активное получение

Бот постоянно спрашивает сервера Telegram: "есть новые сообщения?". Если сообщений нет, то соединение остаётся открытым до 30 секунд (по умолчанию), затем запрос повторяется. Это **pull-модель**: бот сам забирает обновления.

**Плюсы:**

- Простая настройка — не нужен публичный URL или SSL-сертификат
- Работает на локальной машине (для разработки)
- Последовательная обработка сообщений — нет конкуренции за данные
- Предсказуемое поведение, проще отлаживать

**Минусы:**

- Выше нагрузка на сеть — постоянные запросы даже когда сообщений нет
- Бот должен работать 24/7, нельзя "спать" между сообщениями
- Не подходит для serverless-платформ (AWS Lambda, Cloudflare Workers)

### Webhook — реактивное получение

Telegram отправляет POST-запрос на ваш сервер при каждом новом обновлении. Это **push-модель**: сервер сообщает боту о событиях, бот не опрашивает.

**Плюсы:**

- Меньше нагрузки — запросы только при реальных событиях
- Подходит для serverless — функция "просыпается" только при сообщении
- Масштабируется автоматически на облачных платформах
- Экономия ресурсов (и денег) при низкой активности

**Минусы:**

- Требуется публичный URL с валидным SSL-сертификатом
- Сложнее отлаживать локально
- Конкурентная обработка — несколько обновлений могут прийти одновременно
- **Критично:** Telegram ждёт ответа в течение ~10 секунд. Если обработчик не успевает, обновление отправляется повторно, что приводит к дублированию сообщений

**Важно для webhook:** Долгие операции (запросы к внешним API, тяжёлые вычисления) нужно выносить в фоновую очередь. Отвечайте Telegram'у быстро, обрабатывайте асинхронно.

### Что выбрать?

| Сценарий | Рекомендация |
| -------- | ------------ |
| Локальная разработка | Long polling |
| Простой бот на VPS/dedicated сервере | Long polling (проще) |
| Serverless (Lambda, Workers) | Webhook (единственный вариант) |
| Высокая нагрузка, авто-масштабирование | Webhook |
| Бот с сессиями и состоянием | Long polling (меньше race conditions) |

**Рекомендация для начинающих:** Начните с long polling — он проще и надёжнее. Переходите на webhook только если есть конкретные причины (serverless, экономия).

Telega фокусируется на polling-режиме. HTTP-клиент вынесен в отдельный пакет `telega_httpc`, а запуск бота создаёт полное дерево супервизоров автоматически.

## Первый бот

Установите зависимости:

```toml
[dependencies]
telega = ">= 1.0.0 and < 2.0.0"
telega_httpc = ">= 1.0.0 and < 2.0.0"
```

`telega` — основная библиотека бота, `telega_httpc` — HTTP-адаптер для взаимодействия с Telegram API. Они разделены, чтобы при необходимости можно было подставить свой HTTP-клиент.

Простейший эхо-бот — ключевые моменты:

```gleam
import gleam/erlang/process
import telega
import telega/reply
import telega/router
import telega_httpc

pub fn main() {
  // Роутер с одним обработчиком — любой текст отзывается эхом
  let bot_router =
    router.new("echo_bot")
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx:, text:)
      Ok(ctx)
    })

  // Создаём HTTP-клиент и бота в режиме polling
  let client = telega_httpc.new(token: "YOUR_BOT_TOKEN")

  let assert Ok(_bot) =
    telega.new_for_polling(api_client: client)
    |> telega.with_router(bot_router)
    |> telega.init_for_polling_nil_session()

  // Бот запущен — дерево супервизоров управляет polling
  process.sleep_forever()
}
```

Разберём по шагам:

1. `telega_httpc.new(token:)` создаёт HTTP-клиент с токеном бота
2. `telega.new_for_polling(api_client:)` создаёт конфигурацию бота для polling-режима
3. `telega.with_router(bot_router)` подключает роутер с обработчиками
4. `telega.init_for_polling_nil_session()` запускает полное дерево супервизоров (без пользовательских сессий)

После `init_for_polling_nil_session()` бот уже работает: polling-процесс опрашивает Telegram, а `process.sleep_forever()` не даёт main-процессу завершиться.

<details>
<summary>Полный код echo_bot.gleam</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/echo_bot.gleam)

</details>

Бот отвечает тем же текстом на любое текстовое сообщение — добавим обработку команд через роутер.

## Архитектура: дерево супервизоров

Вызов `telega.init_for_polling_nil_session()` (или `telega.init_for_polling()` при использовании сессий) запускает не просто один процесс, а целое **дерево супервизоров** на базе OTP (см. главу 8). Понимание этой архитектуры поможет при отладке и масштабировании бота.

### Структура дерева

```
TelegaRootSupervisor (OneForOne)
├── ChatInstanceFactory
│   └── ChatInstance (для каждого chat_id)
│       └── FSM: ROUTING <-> WAITING
├── Bot (управляет конфигурацией и роутером)
└── Polling (long polling процесс)
```

**TelegaRootSupervisor** — корневой супервизор стратегии `OneForOne`. Если один дочерний процесс падает, перезапускается только он, не затрагивая остальные.

**ChatInstanceFactory** — фабрика, создающая отдельный процесс (ChatInstance) для каждого чата. Когда от пользователя приходит первое сообщение, фабрика порождает новый процесс. Последующие сообщения от того же пользователя направляются в его существующий процесс.

**ChatInstance** — процесс, привязанный к конкретному чату. Внутри работает конечный автомат с двумя состояниями:

- **ROUTING** — обычный режим. Входящее обновление проходит через роутер и обрабатывается подходящим хендлером.
- **WAITING** — режим ожидания. Бот вызвал `wait_text`, `wait_number` или другую wait-функцию. Следующее сообщение от пользователя не проходит через роутер, а передаётся напрямую в ожидающий хендлер.

**Bot** — процесс, хранящий конфигурацию бота (роутер, настройки сессий, middleware).

**Polling** — процесс, выполняющий long polling запросы к Telegram API. Получает обновления и направляет их в соответствующие ChatInstance через фабрику.

### Изоляция чатов

Ключевое свойство архитектуры — **изоляция**. Каждый чат обрабатывается в собственном процессе. Это означает:

- Крэш обработчика одного пользователя не влияет на остальных
- Состояние сессии и wait-функций принадлежит конкретному чату
- Сообщения от разных пользователей обрабатываются параллельно
- Супервизор автоматически перезапустит упавший ChatInstance

Это поведение наследуется от BEAM VM и модели акторов Erlang/OTP. Если вы прочитали главу 8 про процессы и супервизоры, архитектура Telega покажется знакомой.

### Жизненный цикл обновления

1. Polling-процесс получает пакет обновлений от Telegram API
2. Каждое обновление направляется в ChatInstanceFactory по `chat_id`
3. Фабрика находит существующий ChatInstance или создаёт новый
4. ChatInstance проверяет своё состояние:
   - **ROUTING**: обновление проходит через middleware и роутер
   - **WAITING**: обновление передаётся в ожидающую wait-функцию
5. Обработчик выполняется, отправляет ответы через `reply.*`
6. Если обработчик вызывает `wait_*`, ChatInstance переходит в состояние WAITING

Понимание этого цикла особенно важно при работе с Conversation API: когда обработчик вызывает `telega.wait_text(...)`, ChatInstance переключается в WAITING и ждёт следующего сообщения, а не нового вызова роутера.

## Router — маршрутизация обновлений

`telega/router` — основной модуль для создания роутера. Роутер регистрирует обработчики для разных типов обновлений, а `telega.with_router` подключает его к боту:

```gleam
import telega/reply
import telega/router

let bot_router =
  router.new("my_bot")
  |> router.on_command("start", fn(ctx, _command) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Привет! /help для помощи.")
    Ok(ctx)
  })
```

`router.new("name")` создаёт именованный роутер. Каждый `|> router.on_command(...)` добавляет обработчик и возвращает обновлённый роутер — чистая цепочка без мутаций.

<details>
<summary>Полные примеры router_example.gleam</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/router_example.gleam)

</details>

### Команды

```gleam
import telega/reply
import telega/router

fn build_router() {
  router.new("my_bot")
  // /start
  |> router.on_command("start", fn(ctx, _command) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Добро пожаловать!")
    Ok(ctx)
  })
  // /help
  |> router.on_command("help", fn(ctx, _command) {
    let assert Ok(_) =
      reply.with_text(
        ctx:,
        text: "Доступные команды:\n/start — начало\n/help — помощь\n/echo — повторить текст",
      )
    Ok(ctx)
  })
}
```

Каждый обработчик — обычная функция `fn(ctx, command) -> Result(ctx, error)`. `_command` — параметр с данными команды (`command.command`, `command.payload`), здесь он не нужен. Все хендлеры регистрируются цепочкой через `|>`.

### Обработка текстовых сообщений

```gleam
// Любой текст — text передаётся как аргумент обработчика
|> router.on_any_text(fn(ctx, text) {
  let assert Ok(_) =
    reply.with_text(ctx:, text: "Вы написали: " <> text)
  Ok(ctx)
})

// Только если текст точно совпадает с "ping"
|> router.on_text(router.Exact("ping"), fn(ctx, _text) {
  let assert Ok(_) = reply.with_text(ctx:, text: "pong!")
  Ok(ctx)
})
```

Текст сообщения передаётся вторым аргументом обработчика — не нужно обращаться к `ctx` чтобы его получить. `router.on_text` принимает паттерн: `Exact`, `Prefix`, `Contains` или `Suffix`.

### Композиция роутеров

Telega предоставляет три способа комбинировать роутеры: `merge`, `compose` и `scope`.

#### merge — объединение команд

`router.merge(first, second)` складывает команды, callbacks и routes двух роутеров в один. Если есть конфликт (одинаковая команда), побеждает первый роутер:

```gleam
let admin_router =
  router.new("admin")
  |> router.on_command("ban", fn(ctx, _cmd) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Пользователь заблокирован")
    Ok(ctx)
  })
  |> router.on_command("stats", fn(ctx, _cmd) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Статистика бота")
    Ok(ctx)
  })

let user_router =
  router.new("user")
  |> router.on_command("start", fn(ctx, _cmd) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
    Ok(ctx)
  })

// Один роутер обрабатывает /start, /ban, /stats
router.merge(user_router, admin_router)
```

`merge` удобен когда у вас логически разделённые группы команд (пользовательские, административные, модераторские), которые нужно объединить.

#### compose — последовательная цепочка

`router.compose(first, second)` создаёт цепочку: обновление пробуется на первом роутере, если не совпало — на втором. Каждый роутер сохраняет свои middleware:

```gleam
let commands_router =
  router.new("commands")
  |> router.on_command("start", fn(ctx, _cmd) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
    Ok(ctx)
  })

let fallback_router =
  router.new("fallback")
  |> router.on_any_text(fn(ctx, text) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Не понимаю: " <> text)
    Ok(ctx)
  })

// Сначала пробуем commands_router, потом fallback_router
router.compose(commands_router, fallback_router)
```

В отличие от `merge`, `compose` сохраняет независимость middleware каждого роутера. Это важно, когда admin-роутер должен проверять права доступа, а user-роутер — нет.

#### scope — условная маршрутизация

`router.scope(router, predicate)` оборачивает роутер предикатом. Обновления попадают в роутер только если предикат возвращает `True`:

```gleam
let admin_router =
  router.new("admin")
  |> router.on_command("ban", handle_ban)

// admin_router обрабатывает обновления только от администраторов
let scoped = router.scope(admin_router, fn(ctx) {
  list.contains(admin_ids, ctx.chat_id)
})
```

<details>
<summary>Полные примеры композиции</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/composition_example.gleam)

</details>

## Reply — отправка ответов

Модуль `telega/reply` предоставляет функции для отправки различных типов сообщений:

```gleam
import telega/reply

// Текстовое сообщение
let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")

// Текст с HTML-форматированием
let assert Ok(_) = reply.with_html(ctx:, text: "<b>Жирный</b> текст")

// Текст с Markdown
let assert Ok(_) = reply.with_markdown(ctx:, text: "*Жирный* текст")
```

Обратите внимание на **именованные аргументы**: `reply.with_text(ctx:, text: "...")`. Все функции reply используют labeled args для ясности. Функции возвращают `Result(Message, TelegaError)` — нужно обработать результат или использовать `assert Ok`.

Все функции `reply.*` отправляют ответ в тот же чат, из которого пришло обновление: `ctx` содержит идентификатор чата и клиент бота.

### Клавиатуры: Inline vs Reply

Telegram предоставляет два типа клавиатур, которые работают принципиально по-разному:

#### Inline-клавиатуры (кнопки под сообщением)

Inline-клавиатуры отображаются **под конкретным сообщением** внутри чата. При нажатии кнопки отправляется **callback query** — невидимое для пользователя событие. В чате не появляется новое сообщение, только действие.

**Когда использовать:**

- Навигация по меню (настройки, пагинация)
- Действия без текстового ответа (лайк/дизлайк, выбор опции)
- Игровые элементы управления
- Подтверждения (Да/Нет для удаления)

**Пример:**

```gleam
import telega/keyboard
import telega/reply

fn send_settings_menu(ctx) {
  let lang_cb = keyboard.string_callback_data("lang")
  let notification_cb = keyboard.string_callback_data("notification")
  let close_cb = keyboard.string_callback_data("close")

  let assert Ok(kb) =
    keyboard.inline_builder()
    |> keyboard.inline_text(
      "🌍 Изменить язык",
      keyboard.pack_callback(callback_data: lang_cb, data: "open"),
    )
  let assert Ok(kb) =
    kb
    |> keyboard.inline_text(
      "🔔 Уведомления",
      keyboard.pack_callback(callback_data: notification_cb, data: "open"),
    )
  let kb = kb |> keyboard.inline_next_row()  // Новая строка кнопок
  let assert Ok(kb) =
    kb
    |> keyboard.inline_text(
      "❌ Закрыть",
      keyboard.pack_callback(callback_data: close_cb, data: "close"),
    )
  let kb = keyboard.inline_build(kb)

  let assert Ok(_) =
    reply.with_markup(
      ctx:,
      text: "⚙️ Настройки:",
      markup: keyboard.inline_to_markup(kb),
    )
  Ok(ctx)
}
```

Построение inline-клавиатуры:

- `keyboard.inline_builder()` — создаёт билдер
- `keyboard.inline_text(builder, text, callback)` — добавляет кнопку, возвращает `Result(InlineKeyboardBuilder, String)` (валидирует длину callback data)
- `keyboard.string_callback_data(id)` — создаёт идентификатор callback-данных
- `keyboard.pack_callback(callback_data:, data:)` — упаковывает данные в `KeyboardCallback`
- `keyboard.inline_next_row()` — начинает новую строку кнопок
- `keyboard.inline_build(builder)` — завершает построение
- `keyboard.inline_to_markup(kb)` — конвертирует в формат для `reply.with_markup`

Кнопки расположатся так:

```
[🌍 Изменить язык] [🔔 Уведомления]
         [❌ Закрыть]
```

#### Reply-клавиатуры (замена системной клавиатуры)

Reply-клавиатуры **заменяют стандартную клавиатуру пользователя**. При нажатии кнопки отправляется обычное **текстовое сообщение**, видимое в чате. Текст кнопки = текст сообщения.

**Когда использовать:**

- Множественный выбор с видимыми ответами
- Анкеты и опросы (ответы должны быть в истории чата)
- Быстрый ввод типичных команд (/start, /help)
- Когда важна прозрачность — пользователь видит что отправил

**Пример:**

```gleam
import telega/keyboard
import telega/reply

fn ask_confirmation(ctx) {
  let kb =
    keyboard.builder()
    |> keyboard.text("✅ Да")
    |> keyboard.text("❌ Нет")
    |> keyboard.next_row()
    |> keyboard.text("❓ Не уверен")
    |> keyboard.build()

  let assert Ok(_) =
    reply.with_markup(
      ctx:,
      text: "Подтвердите действие:",
      markup: keyboard.to_markup(kb),
    )
  Ok(ctx)
}
```

Функции Reply-клавиатуры:

- `keyboard.builder()` — создаёт билдер
- `keyboard.text(text)` — добавляет текстовую кнопку
- `keyboard.next_row()` — начинает новую строку
- `keyboard.build()` — завершает построение
- `keyboard.to_markup()` — конвертирует для `reply.with_markup`

#### Ключевые отличия

| Аспект | Inline-клавиатура | Reply-клавиатура |
|--------|-------------------|-------------------|
| **Расположение** | Под сообщением | Вместо системной клавиатуры |
| **Что отправляется** | Callback query (невидимо) | Текстовое сообщение (видимо) |
| **Текст кнопки vs данные** | Можно разделить: текст "Да", данные "confirm_yes" | Одно и то же: кнопка "Да" отправит сообщение "Да" |
| **Видимость в чате** | Ничего не добавляется | Появляется новое сообщение |
| **Обработка** | `router.on_callback` или `wait_callback_query` | `router.on_text` или `wait_text` |

**Важно:** Эти клавиатуры взаимоисключающие — нельзя использовать обе в одном сообщении. При редактировании сообщения нельзя изменить тип клавиатуры.

### Обработка inline-клавиатур

Callback queries обрабатываются через роутер или через Conversation API:

```gleam
router.new("settings_bot")
|> router.on_callback(router.Exact("lang"), fn(ctx, _data, query_id) {
  // Обязательно отвечаем на callback query
  let assert Ok(_) =
    reply.answer_callback_query(
      ctx:,
      parameters: AnswerCallbackQueryParameters(
        callback_query_id: query_id,
        text: Some("Открываю..."),
        show_alert: None,
        url: None,
        cache_time: None,
      ),
    )
  show_language_menu(ctx)
})
```

Обработчик callback принимает три аргумента — `ctx`, `data` и `query_id`. Для ответа на callback query используйте `reply.answer_callback_query(ctx:, parameters:)` с типом `AnswerCallbackQueryParameters`.

**Критично:** Всегда вызывайте `reply.answer_callback_query` — иначе Telegram показывает бесконечную загрузку на кнопке.

### Обработка reply-клавиатур

Reply-клавиатуры обрабатываются как обычный текст:

```gleam
router.new("quiz_bot")
|> router.on_text(router.Exact("✅ Да"), fn(ctx, _) {
  let assert Ok(_) =
    reply.with_text(ctx:, text: "Отлично! Продолжаем.")
  Ok(ctx)
})
```

<details>
<summary>Полные примеры клавиатур</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/keyboard_example.gleam)

</details>

## Session — встроенные сессии

Представьте: пользователь выбрал язык интерфейса — русский. Отправил команду `/start`, получил приветствие. Через час пишет `/help` — и бот снова отвечает по-русски. Как бот "помнит" выбор пользователя?

Каждое сообщение в Telegram — изолированное событие. Без дополнительного механизма бот забывает всё между обновлениями. **Сессии** решают эту проблему: это персональная память под каждого пользователя, где бот хранит данные между сообщениями.

### Зачем нужны сессии?

Типичные примеры:

- **Настройки пользователя:** язык, часовой пояс, формат даты
- **Контекст:** последняя команда, текущий раздел меню
- **Временные данные:** выбранные фильтры, параметры поиска
- **Счётчики:** сколько раз пользователь выполнил действие

**Важно:** Сессии в Telega живут в памяти BEAM-процесса (внутри ChatInstance) и **не переживают перезапуск бота** по умолчанию. Для персистентных данных используйте `SessionSettings` с сохранением или Flow API с Storage.

### Создаём тип сессии

Сессия — это обычный Gleam-тип. Определите что ваш бот должен помнить о каждом пользователе:

```gleam
pub type MusicBotSession {
  MusicBotSession(
    language: String,           // Язык интерфейса
    favorite_genre: Option(String),  // Любимый жанр (может быть не задан)
    plays_count: Int,           // Сколько треков прослушано
  )
}

// Значения по умолчанию для новых пользователей
pub fn default_session() -> MusicBotSession {
  MusicBotSession(
    language: "ru",
    favorite_genre: None,
    plays_count: 0,
  )
}
```

Каждый пользователь получает свою копию этих данных. Изменения в сессии пользователя A не влияют на пользователя B — это гарантируется изоляцией процессов ChatInstance.

### Подключаем сессии к боту

Сессии подключаются через `telega.with_session_settings` и `telega.init_for_polling`:

```gleam
import telega
import telega/bot
import telega/router
import telega_httpc

pub fn build_bot(token: String) {
  let client = telega_httpc.new(token:)
  let bot_router =
    router.new("music_bot")
    |> router.on_command("start", handle_start)
    |> router.on_command("lang", handle_change_language)

  let assert Ok(bot) =
    telega.new_for_polling(api_client: client)
    |> telega.with_router(bot_router)
    |> telega.with_session_settings(bot.SessionSettings(
      persist_session: fn(_key, session) { Ok(session) },
      get_session: fn(_key) { Ok(None) },
      default_session: default_session,
    ))
    |> telega.init_for_polling()

  bot
}
```

`SessionSettings` содержит три функции:

- `default_session` — фабрика для новых пользователей. Вызывается при первом сообщении от `chat_id`
- `persist_session` — вызывается после каждого обновления сессии для сохранения (в памяти, в БД и т.д.)
- `get_session` — вызывается при создании ChatInstance для восстановления сессии

В примере выше `persist_session` и `get_session` — заглушки (in-memory). Для продакшена замените их на функции, работающие с базой данных.

Обратите внимание: вместо `init_for_polling_nil_session()` используется `init_for_polling()` — когда сессии настроены, нужен обычный `init`.

### Читаем данные из сессии

Сессия доступна через `ctx.session` в любом обработчике:

```gleam
import telega/bot.{type Context}
import telega/reply

fn handle_stats(ctx: Context(MusicBotSession, Nil), _command) {
  let plays = ctx.session.plays_count
  let genre = ctx.session.favorite_genre |> option.unwrap("не выбран")

  let message =
    "Ваша статистика:\n"
    <> "Прослушано треков: " <> int.to_string(plays) <> "\n"
    <> "Любимый жанр: " <> genre

  let assert Ok(_) = reply.with_text(ctx:, text: message)
  Ok(ctx)
}
```

Обратите внимание на сигнатуру: `Context(MusicBotSession, Nil)`. Первый параметр типа — тип сессии. Компилятор проверит, что вы обращаетесь только к существующим полям.

### Обновляем сессию

Сессии **иммутабельны** — создаём обновлённую версию и сохраняем через `bot.next_session`:

```gleam
fn handle_play_track(ctx: Context(MusicBotSession, Nil), _command) {
  // Увеличиваем счётчик через spread-синтаксис
  let updated =
    MusicBotSession(..ctx.session, plays_count: ctx.session.plays_count + 1)

  let assert Ok(_) = reply.with_text(ctx:, text: "Трек начал играть!")
  bot.next_session(ctx:, session: updated)
}
```

`bot.next_session(ctx:, session:)` использует именованные аргументы. **Spread-синтаксис** `..ctx.session` копирует все поля, затем перезаписываем только нужные.

<details>
<summary>Полные примеры работы с сессиями</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/session_example.gleam)

</details>

### Когда использовать сессии (и когда нет)

Session — это инструмент для быстрого доступа к пользовательским данным **в памяти**. Выбирайте правильный инструмент для задачи:

| Задача | Решение | Почему |
|--------|---------|--------|
| Язык интерфейса | Session | Читается в каждом обработчике, редко меняется |
| Счётчик действий (статистика) | Session | Быстрые обновления, можно потерять при перезапуске |
| Текущий раздел меню | Session | Временный контекст навигации |
| Форма регистрации (имя, email, возраст) | Conversation API | Многошаговый диалог с валидацией |
| Товары в корзине | База данных | Критичные данные, нельзя потерять |
| Незавершённое бронирование | Flow + Storage | Нужна персистентность + навигация "назад" |
| История заказов | База данных | Долгосрочное хранение |

**Эмпирическое правило:**

- Session — для **эфемерных** данных, которые можно пересоздать или потерять без последствий
- База данных — для **критичных** данных, которые нельзя потерять
- Conversation/Flow — для **процессов** с несколькими шагами

## Conversation API — линейные диалоги

Conversation API позволяет писать многошаговые диалоги как последовательность операций. Обработчик "приостанавливается" на каждой функции `wait_*` и автоматически продолжается при получении нужного сообщения.

### Базовая концепция

Традиционный обработчик обрабатывает одно обновление за раз. Conversation API позволяет собирать несколько сообщений подряд:

```gleam
import telega
import telega/bot.{type Context}
import telega/reply

// Традиционный подход — одно сообщение
fn handle_echo(ctx, text) {
  reply.with_text(ctx:, text: "Вы написали: " <> text)
}

// Conversation API — последовательность сообщений
fn handle_name_conversation(ctx: Context(Nil, Nil), _command) {
  let assert Ok(_) = reply.with_text(ctx:, text: "Как вас зовут?")
  use ctx, name <- telega.wait_text(ctx:, or: None, timeout: None)

  let assert Ok(_) = reply.with_text(ctx:, text: "Сколько вам лет?")
  use ctx, age_str <- telega.wait_text(ctx:, or: None, timeout: None)

  let assert Ok(_) =
    reply.with_text(
      ctx:,
      text: "Привет, " <> name <> "! Вам " <> age_str <> " лет.",
    )
  Ok(ctx)
}
```

Каждый `use ctx, value <- telega.wait_*` приостанавливает выполнение. BEAM сохраняет состояние процесса (ChatInstance переходит в состояние WAITING), и обработчик продолжается, когда пользователь отправляет следующее сообщение.

### Функции ожидания

**Базовые wait-функции:**

```gleam
import telega

// Любое текстовое сообщение
use ctx, text <- telega.wait_text(ctx:, or: None, timeout: None)

// Число с проверкой диапазона
use ctx, age <- telega.wait_number(
  ctx:,
  min: Some(13),
  max: Some(120),
  or: None,
  timeout: None,
)

// Email с regex-валидацией
use ctx, email <- telega.wait_email(ctx:, or: None, timeout: None)
```

Все `wait_*` функции принимают:

- `ctx:` — текущий контекст
- `or:` — обработчик для неожиданных сообщений (`Some(handler)` или `None`)
- `timeout:` — тайм-аут в миллисекундах (`Some(60_000)` или `None`)

### Forms API — валидация ввода

Conversation API включает функции с автоматической валидацией:

```gleam
import telega
import telega/bot

// Число с проверкой диапазона
use ctx, age <- telega.wait_number(
  ctx:,
  min: Some(13),
  max: Some(120),
  or: Some(bot.HandleText(fn(ctx, _) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Введите число от 13 до 120")
    Ok(ctx)
  })),
  timeout: None,
)

// Email с regex-валидацией
use ctx, email <- telega.wait_email(
  ctx:,
  or: Some(bot.HandleText(fn(ctx, _) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Некорректный email. Попробуйте снова.")
    Ok(ctx)
  })),
  timeout: None,
)

// Типобезопасный выбор из вариантов
pub type Plan {
  Free
  Premium
}

use ctx, plan <- telega.wait_choice(
  ctx:,
  options: [#("Бесплатный", Free), #("Премиум", Premium)],
  or: None,
  timeout: None,
)
```

`wait_number` парсит текст в `Int` и проверяет диапазон. `wait_email` проверяет формат через regex. `wait_choice` автоматически создаёт inline-клавиатуру и возвращает типобезопасное значение.

### Обработка ошибок и тайм-аутов

Параметр `or:` обрабатывает неожиданные сообщения:

```gleam
use ctx, age <- telega.wait_number(
  ctx:,
  min: Some(18),
  max: Some(100),
  or: Some(bot.HandleAny(fn(ctx, update) {
    case update {
      bot.TextMessage(text) -> {
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Это не число. Попробуйте снова.")
        // Ждём ввод повторно
        telega.wait_number(ctx:, min: Some(18), max: Some(100), or: None, timeout: None)
      }
      bot.CommandMessage("cancel", _) -> {
        let assert Ok(_) = reply.with_text(ctx:, text: "Отменено.")
        Ok(ctx)
      }
      _ -> {
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Отправьте число или /cancel")
        telega.wait_number(ctx:, min: Some(18), max: Some(100), or: None, timeout: None)
      }
    }
  })),
  timeout: Some(60_000),  // 60 секунд
)
```

Если пользователь не ответит за `timeout` миллисекунд, диалог автоматически отменяется.

### Пример: форма регистрации

Ключевые моменты:

```gleam
fn handle_register(ctx: Context(Nil, Nil), _command) {
  let assert Ok(_) =
    reply.with_text(ctx:, text: "Давайте зарегистрируемся! Как вас зовут?")
  use ctx, name <- telega.wait_text(ctx:, or: None, timeout: Some(120_000))

  let assert Ok(_) = reply.with_text(ctx:, text: "Сколько вам лет?")
  use ctx, age <- telega.wait_number(
    ctx:, min: Some(13), max: Some(120), or: ..., timeout: Some(60_000),
  )

  let assert Ok(_) = reply.with_text(ctx:, text: "Ваш email?")
  use ctx, email <- telega.wait_email(ctx:, or: ..., timeout: Some(60_000))

  let assert Ok(_) = reply.with_text(ctx:, text: "Выберите тарифный план:")
  use ctx, plan <- telega.wait_choice(
    ctx:,
    options: [#("Бесплатный", Free), #("Премиум", Premium)],
    or: None,
    timeout: Some(60_000),
  )

  // Сохраняем в БД...
  let assert Ok(_) =
    reply.with_text(ctx:, text: "Регистрация завершена!")
  Ok(ctx)
}
```

Весь диалог — одна функция без явного FSM. Валидация встроена, ошибки обрабатываются через `or:`, тайм-ауты предотвращают зависание.

<details>
<summary>Полный пример формы регистрации</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/conversation_example.gleam)

</details>

### Когда использовать Conversation API

**Используйте Conversation API когда:**

- Линейный диалог (2-5 шагов)
- Валидация с повтором при ошибке
- Не нужна навигация "назад"
- Не требуется персистентность (пользователь может начать заново)
- Простая форма сбора данных

**НЕ используйте Conversation API когда:**

- Сложное ветвление логики (много условных переходов)
- Нужна кнопка "Назад" или произвольные переходы между шагами
- Состояние должно сохраниться при перезапуске бота
- Диалог переиспользуется в нескольких местах (используйте Flow + Subflows)

В этих случаях используйте **Flow API**.

## Конечные автоматы (FSM) в ботах

Conversation API удобен для линейных диалогов, но у него есть ограничения:

- Нет навигации "назад" или произвольных переходов между шагами
- Состояние теряется при перезапуске бота (нет персистентности)
- Логика переходов неявная — сложно увидеть всю картину диалога
- Сложно переиспользовать части диалога в разных местах

Конечные автоматы (Finite State Machines, FSM) решают эти проблемы. FSM — это модель, где есть конечное число **состояний** и **переходы** между ними по событиям:

```
Y(t) = f(X(t), Y(t-1))
```

Состояние в момент `t` зависит от входа и предыдущего состояния. Важное свойство: у FSM нет "ленты" для хранения промежуточных вычислений — только управляющие состояния. Это делает автоматы простыми и предсказуемыми.

### Зачем явно выделять состояния?

Классическая ситуация в коде без FSM:

```gleam
type UserSession {
  UserSession(
    is_waiting_name: Bool,
    is_waiting_phone: Bool,
    is_waiting_email: Bool,
    has_confirmed: Bool,
    is_cancelled: Bool,
    // ... и так далее
  )
}
```

Мозг не справляется отслеживать все возможные комбинации. А теперь представьте: один тип, в котором видны **все** возможные состояния:

```gleam
type RegistrationState {
  Idle
  AwaitingName
  AwaitingPhone
  AwaitingEmail
  Confirming
  Completed
  Cancelled
}
```

Сразу понятно, в каких состояниях может находиться регистрация. Компилятор проверит, что все варианты обработаны.

Что даёт явный FSM:

- **Ясность** — вся логика переходов в одном месте
- **Меньше багов** — нельзя случайно попасть в невозможное состояние
- **Проще поддерживать** — новый разработчик сразу видит картину
- **Персистентность** — состояние можно сохранить в БД и восстановить

### State explosion и statecharts

Главная боль классических FSM — *взрыв состояний*. Добавляете один новый аспект, а количество состояний растёт экспоненциально.

Пример — форма валидации:

1. Начинаем с двух состояний: `Valid`, `Invalid`
2. Добавили `Enabled`, `Disabled` — уже 4 состояния
3. Добавили `Dirty`, `Pristine` — 8 состояний

В 1987 году Дэвид Харел придумал **statecharts** — это FSM на стероидах:

- **Параллельные регионы** — независимые аспекты моделируются отдельно
- **Иерархия** — состояния могут быть вложенными
- **Guards** — условия на переходах

Telega Flow API реализует эти идеи для Telegram-ботов.

## Flows API — персистентные FSM

`telega/flow` — это набор модулей для построения сложных диалогов как FSM. В отличие от Conversation API, Flow даёт:

- **Персистентность** — состояние сохраняется в storage
- **Навигацию** — можно вернуться назад или перейти к любому шагу
- **Типизированные шаги** — шаги задаются через ADT, а конвертеры `step_to_string`/`string_to_step` требуют обработки всех вариантов. Однако компилятор не проверяет, что для каждого варианта вызван `add_step` — пропущенный шаг приведёт к ошибке в runtime
- **Композицию** — можно встраивать одни flows в другие (subflows)

### Создание Flow

Flow API состоит из нескольких модулей: `flow/builder`, `flow/action`, `flow/registry`, `flow/storage`, `flow/handler`, `flow/instance`, `flow/types`. Flow строится через builder:

```gleam
import telega/flow/builder
import telega/flow/action
import telega/flow/storage

type RegistrationStep {
  Welcome
  CollectName
  CollectPhone
  CollectEmail
  Confirm
}

fn step_to_string(step: RegistrationStep) -> String {
  case step {
    Welcome -> "welcome"
    CollectName -> "collect_name"
    CollectPhone -> "collect_phone"
    CollectEmail -> "collect_email"
    Confirm -> "confirm"
  }
}

fn string_to_step(s: String) -> Result(RegistrationStep, Nil) {
  case s {
    "welcome" -> Ok(Welcome)
    "collect_name" -> Ok(CollectName)
    "collect_phone" -> Ok(CollectPhone)
    "collect_email" -> Ok(CollectEmail)
    "confirm" -> Ok(Confirm)
    _ -> Error(Nil)
  }
}

pub fn create_registration_flow(storage) {
  builder.new("registration", storage, step_to_string, string_to_step)
  |> builder.add_step(Welcome, welcome_handler)
  |> builder.add_step(CollectName, collect_name_handler)
  |> builder.add_step(CollectPhone, collect_phone_handler)
  |> builder.add_step(CollectEmail, collect_email_handler)
  |> builder.add_step(Confirm, confirm_handler)
  |> builder.build(initial: Welcome)
}
```

`builder.new` требует функции-конвертеры `step_to_string` и `string_to_step` — они нужны для сериализации состояния в storage.

Каждый обработчик шага возвращает действие (action):

```gleam
fn collect_name_handler(ctx, instance) {
  case flow_instance.get_data(instance, "name") {
    Some(name) -> {
      // Валидируем и переходим дальше
      action.goto(CollectPhone)
    }
    None -> {
      let assert Ok(_) =
        reply.with_text(ctx:, text: "Как вас зовут?")
      action.wait("name")
    }
  }
}
```

### Действия (actions)

Действия определены в модуле `flow/action`:

```gleam
import telega/flow/action

// Перейти к следующему шагу
action.next

// Перейти к конкретному шагу
action.goto(CollectPhone)

// Ожидать ввода пользователя
action.wait("input_key")

// Завершить flow
action.complete

// Отменить flow
action.cancel
```

### Storage — персистентность

Conversation API хранит состояние диалога в памяти процесса ChatInstance. Если бот перезапустится — диалог потеряется. Flow решает эту проблему через **storage** — абстракцию над хранилищем состояния.

При создании Flow через `builder.new` передаётся storage — объект, который умеет сохранять и загружать `FlowInstance`. Flow автоматически вызывает storage после каждого перехода между шагами.

```gleam
import telega/flow/storage

// Для разработки — in-memory (ETS, не переживает перезапуск VM)
let mem_storage = storage.memory()
```

Для реального решения нужно реализовать storage с сохранением в базу данных (PostgreSQL, SQLite). Интерфейс storage определяет четыре операции: `save`, `load`, `delete` и `list_by_user` — этого достаточно, чтобы Flow мог восстановить диалог после перезапуска бота.

### Регистрация Flow в роутере

Flow регистрируются через реестр:

```gleam
import telega/flow/registry

let registration_flow = create_registration_flow(storage)

let flow_reg =
  registry.new()
  |> registry.register(registry.OnCommand("register"), registration_flow)

let bot_router =
  router.new("my_bot")
  |> router.on_command("help", handle_help)
  |> registry.apply_to_router(flow_reg)
```

Когда пользователь отправляет `/register`, запускается `registration_flow`. Если у пользователя уже есть активный flow, он продолжается с того места, где остановился.

### Когда использовать Flow

| Сценарий | Подход |
|----------|--------|
| Простая команда или эхо | Router |
| Хранение настроек пользователя | Session |
| Линейный диалог (2-5 шагов) | Conversation API |
| Диалог с валидацией | Conversation API (wait_number, wait_email) |
| Диалог с ветвлениями и возвратом назад | Flow |
| Персистентность между перезапусками | Flow + Storage |
| Переиспользуемые части диалога | Flow + Subflows |

Flow — это более высокий уровень абстракции. Он строится поверх тех же примитивов (Handler, Context, wait_*), но добавляет FSM-модель с персистентностью и навигацией.

## Middleware

Telega предоставляет систему middleware для обработчиков обновлений. Middleware оборачивают **обработчики бота** — функции типа `fn(Context, Data) -> Result(Context, Error)`.

Middleware применяются через `router.use_middleware`:

```gleam
import telega/router

let bot_router =
  router.new("my_bot")
  |> router.use_middleware(fn(handler) {
    fn(ctx, data) {
      // Логируем перед обработкой
      io.println("Обработка обновления...")
      // Вызываем оригинальный обработчик
      let result = handler(ctx, data)
      // Логируем после обработки
      io.println("Обработка завершена")
      result
    }
  })
  |> router.on_command("start", handle_start)
  |> router.on_any_text(handle_text)
```

Middleware — это функция, которая принимает обработчик и возвращает обёрнутый обработчик. Это стандартный паттерн "декоратор".

### Пример: фильтрация по пользователям

```gleam
fn admin_only_middleware(handler) {
  fn(ctx, data) {
    let admin_ids = [123_456_789, 987_654_321]
    case list.contains(admin_ids, ctx.chat_id) {
      True -> handler(ctx, data)
      False -> {
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Доступ запрещён")
        Ok(ctx)
      }
    }
  }
}

let admin_router =
  router.new("admin")
  |> router.use_middleware(admin_only_middleware)
  |> router.on_command("ban", handle_ban)
  |> router.on_command("stats", handle_stats)
```

### Пример: обработка ошибок

```gleam
fn error_recovery_middleware(handler) {
  fn(ctx, data) {
    case handler(ctx, data) {
      Ok(ctx) -> Ok(ctx)
      Error(err) -> {
        io.println("Handler error: " <> string.inspect(err))
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Произошла ошибка. Попробуйте позже.")
        Ok(ctx)
      }
    }
  }
}
```

### Композиция middleware

Middleware применяются в порядке вызова:

```gleam
let bot_router =
  router.new("my_bot")
  |> router.use_middleware(logging_middleware)        // 1. Логирование
  |> router.use_middleware(admin_only_middleware)     // 2. Фильтр
  |> router.use_middleware(error_recovery_middleware) // 3. Обработка ошибок
  |> router.on_command("ban", handle_ban)
```

Обновление проходит через цепочку middleware сверху вниз: логирование -> фильтр -> обработка ошибок -> обработчик.

## Обработка ошибок

В Gleam нет исключений — все ошибки передаются через `Result`. Это касается и Telega:

### Уровни ошибок

**1. Ошибки reply:** Каждая функция `reply.*` возвращает `Result(Message, TelegaError)`. Если Telegram API недоступен или токен невалиден, вы получите `Error`:

```gleam
fn handle_start(ctx, _cmd) {
  case reply.with_text(ctx:, text: "Привет!") {
    Ok(_message) -> Ok(ctx)
    Error(err) -> {
      io.println("Не удалось отправить сообщение: " <> string.inspect(err))
      Error(err)
    }
  }
}
```

В примерах мы часто используем `let assert Ok(_) = reply.with_text(...)` для краткости. В продакшене обрабатывайте ошибки явно или используйте middleware для recovery.

**2. Ошибки обработчиков:** Если обработчик возвращает `Error`, ChatInstance логирует ошибку. Процесс не падает — следующее сообщение будет обработано нормально.

**3. Крэши процессов:** Если обработчик паникует (например, `let assert Ok(_)` на `Error`), ChatInstance перезапускается супервизором. Сессия и состояние wait-функций теряются, но бот продолжает работать.

### Стратегии обработки

```gleam
// Стратегия 1: assert (для некритичных ботов)
fn handle_start(ctx, _cmd) {
  let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
  Ok(ctx)
}

// Стратегия 2: use + result.try (для production)
fn handle_start(ctx, _cmd) {
  use _msg <- result.try(reply.with_text(ctx:, text: "Привет!"))
  Ok(ctx)
}

// Стратегия 3: middleware (глобально)
let bot_router =
  router.new("my_bot")
  |> router.use_middleware(error_recovery_middleware)
  |> router.on_command("start", handle_start)
```

Рекомендация: используйте `assert` при разработке и прототипировании, `result.try` или middleware в production-коде.

## Тестирование бота

Telega включает полноценный **testing toolkit** в модулях `telega/testing/*`. Он позволяет тестировать бота без реального Telegram-соединения.

### Conversation DSL

Основной инструмент тестирования — `telega/testing/conversation`. Он предоставляет декларативный DSL для описания разговора с ботом:

```gleam
import telega/testing/conversation

pub fn start_command_test() {
  conversation.conversation_test()
  |> conversation.send("/start")
  |> conversation.expect_reply("Привет!")
  |> conversation.run(my_router, fn() { Nil })
}
```

Разберём по шагам:

1. `conversation.conversation_test()` создаёт пустую тест-цепочку
2. `conversation.send("текст")` симулирует отправку сообщения от пользователя
3. `conversation.expect_reply("текст")` ожидает точный ответ от бота
4. `conversation.run(router, session_factory)` запускает тест с указанным роутером

`session_factory` — функция, создающая начальную сессию. Для ботов без сессий передайте `fn() { Nil }`.

### Методы проверки ответов

```gleam
// Точное совпадение ответа
|> conversation.expect_reply("Привет!")

// Ответ содержит подстроку
|> conversation.expect_reply_containing("Привет")

// Ответ содержит inline-клавиатуру с указанными кнопками
|> conversation.expect_keyboard(buttons: ["Список", "Добавить"])
```

`expect_reply_containing` особенно полезен, когда текст ответа может меняться (например, содержит дату или имя пользователя), но ключевые слова остаются.

### Тестирование многошаговых диалогов

Conversation DSL поддерживает цепочки send/expect для тестирования wait-функций:

```gleam
pub fn register_flow_test() {
  conversation.conversation_test()
  |> conversation.send("/register")
  |> conversation.expect_reply_containing("зовут")  // Бот спрашивает имя
  |> conversation.send("Alice")                       // Пользователь отвечает
  |> conversation.expect_reply_containing("Alice")    // Бот подтверждает
  |> conversation.run(register_router, fn() { Nil })
}
```

Этот тест проверяет полный цикл: команда -> вопрос -> ответ -> подтверждение. Под капотом `conversation.run` создаёт mock-окружение, которое симулирует ChatInstance с его FSM (ROUTING -> WAITING -> ROUTING).

### Тестирование inline-клавиатур

```gleam
pub fn menu_keyboard_test() {
  conversation.conversation_test()
  |> conversation.send("/menu")
  |> conversation.expect_keyboard(buttons: ["Список", "Добавить"])
  |> conversation.run(menu_router, fn() { Nil })
}
```

`expect_keyboard(buttons:)` проверяет, что бот отправил сообщение с inline-клавиатурой, содержащей кнопки с указанными текстами.

### Тестирование чистой логики

Помимо conversation DSL, не забывайте тестировать чистые функции отдельно:

```gleam
import gleeunit/should

pub fn format_task_list_test() {
  format_task_list([
    Task(text: "Купить молоко", done: False),
    Task(text: "Написать тесты", done: True),
  ])
  |> should.equal("Ваши задачи:\n1. ☐ Купить молоко\n2. ✅ Написать тесты")
}
```

Чистые функции (парсинг команд, форматирование, state machine переходы) тестируются стандартным gleeunit без Telega testing toolkit. Это быстрее и проще.

### Паттерны тестирования

**Разделяйте логику и побочные эффекты.** Выносите бизнес-логику в чистые функции (парсинг, валидация, форматирование), а обработчики бота делайте тонкими — только вызовы reply и wait:

```gleam
// Чистая функция — легко тестировать
pub fn parse_command(text: String) -> BotCommand { ... }

// Тонкий обработчик — тестируется через conversation DSL
fn handle_command(ctx, cmd) {
  case parse_command(cmd.text) {
    CmdStart -> reply.with_text(ctx:, text: "Привет!")
    CmdHelp -> reply.with_text(ctx:, text: help_text())
    _ -> reply.with_text(ctx:, text: "Неизвестная команда")
  }
}
```

**Тестируйте каждый роутер отдельно.** Если вы используете `router.merge`, тестируйте admin_router и user_router по отдельности, а затем один интеграционный тест для merged_router.

**Используйте `expect_reply_containing` для хрупких текстов.** Если ответ бота может незначительно меняться (форматирование, пунктуация), проверяйте ключевые слова через `expect_reply_containing`, а не точное совпадение.

<details>
<summary>Полные примеры тестирования</summary>

[Просмотреть на GitHub](https://github.com/bondiano/gleam-by-example/blob/master/exercises/appendix_a/src/examples/testing_example.gleam)

</details>

## Деплой

### Переменные окружения

```bash
export TELEGRAM_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
```

Токен передаётся через переменную окружения — ни один секрет не хранится в коде. Приложение читает его через `os.get_env` при старте.

### Запуск в production

Polling-бот запускается как обычное Erlang/OTP-приложение:

```bash
gleam build
gleam run
```

Дерево супервизоров, созданное `init_for_polling_nil_session()`, автоматически управляет всеми процессами. При крэше отдельного ChatInstance супервизор перезапустит его. Polling-процесс при ошибке сети переподключится автоматически.

Для продакшена на VPS/сервере:

```bash
# Компилируем release
gleam export erlang-shipment

# Запускаем
./build/erlang-shipment/entrypoint.sh run
```

Erlang-shipment создаёт автономный пакет, который можно запустить без установки Gleam/Erlang на целевом сервере.

### Мониторинг

Так как бот работает на BEAM, доступны стандартные инструменты мониторинга Erlang/OTP:

- **observer** — визуальный монитор процессов, памяти, сообщений
- **logger** — встроенное логирование Erlang (настраивается через middleware)
- **telemetry** — метрики (если подключить зависимость)

## Упражнения

Код упражнений находится в `exercises/appendix_a/`.

```bash
cd exercises/appendix_a
gleam test
```

---

**Упражнение A.1** (Лёгкое): Парсинг команд бота

```gleam
pub type BotCommand {
  CmdStart
  CmdHelp
  CmdList
  CmdAdd(title: String)
  CmdDone(index: Int)
  CmdUnknown(text: String)
}

pub fn parse_command(text: String) -> BotCommand {
  todo
}
```

Распарсите текст сообщения:

- `"/start"` -> `CmdStart`
- `"/help"` -> `CmdHelp`
- `"/list"` -> `CmdList`
- `"/add Buy milk"` -> `CmdAdd("Buy milk")`
- `"/done 3"` -> `CmdDone(3)`
- `"/done abc"` -> `CmdUnknown("/done abc")` (нельзя парсить число)
- всё остальное -> `CmdUnknown(text)`

*Подсказка*: `case string.trim(text) { "/add " <> title -> CmdAdd(title) ... }`, `int.parse(n)` для проверки числа.

---

**Упражнение A.2** (Лёгкое): Форматирование одной задачи

```gleam
pub type Task {
  Task(text: String, done: Bool)
}

pub fn format_task(t: Task) -> String {
  todo
}
```

- `Task("Buy milk", False)` -> `"☐ Buy milk"`
- `Task("Write tests", True)` -> `"✅ Write tests"`

---

**Упражнение A.3** (Лёгкое): Форматирование списка задач

```gleam
pub fn format_task_list(tasks: List(Task)) -> String {
  todo
}
```

- `[]` -> `"Список задач пуст. Добавьте: /add <задача>"`
- `[task...]` -> `"Ваши задачи:\n1. ☐ Buy milk\n2. ✅ Write tests"`

*Подсказка*: `list.index_map`, `string.join`.

---

**Упражнение A.4** (Среднее): State machine для многошагового диалога

```gleam
pub type ConvState {
  Idle
  AwaitingTitle
}

pub fn conversation_step(state: ConvState, input: String) -> #(ConvState, String) {
  todo
}
```

Реализуйте переходы:

- `Idle + "/add"` -> `#(AwaitingTitle, "Введите название задачи:")`
- `Idle + "/help"` -> `#(Idle, "Доступные команды:\n/list — список задач\n/add — добавить задачу\n/help — помощь")`
- `Idle + другое` -> `#(Idle, "Не понимаю. /help — список команд.")`
- `AwaitingTitle + title` -> `#(Idle, "✅ Задача «title» добавлена!")`

*Подсказка*: `case state, string.trim(input) { Idle, "/add" -> ... }`.

---

**Упражнение A.5** (Среднее): Полный dispatch команд

```gleam
pub fn dispatch(cmd: BotCommand, tasks: List(Task)) -> #(List(Task), String) {
  todo
}
```

Обработайте все команды:

- `CmdStart` -> `#(tasks, "Привет! Я TODO-бот.\n/help — список команд")`
- `CmdHelp` -> `#(tasks, "Команды:\n/list — список задач\n/add <задача> — добавить\n/done <номер> — выполнено")`
- `CmdList` -> `#(tasks, форматированный список)`
- `CmdAdd(title)` -> `#([...tasks, Task(title, False)], "✅ Задача «title» добавлена!")`
- `CmdDone(n)` -> задача `n-1` помечается `done=True`; если нет -> `"Нет задачи с номером n"`
- `CmdUnknown(t)` -> `#(tasks, "Не понимаю: t. /help — список команд")`

*Подсказка*: используйте `format_task_list` из упражнения A.3.

---

**Упражнение A.6** (Среднее): Greeting-роутер

```gleam
pub fn build_greeting_router() -> Router(Nil, Nil) {
  todo
}
```

Создайте роутер с двумя командами:

- `/start` -> ответ содержит "Привет"
- `/help` -> ответ содержит "/start"

Тест проверяет через `telega/testing/conversation` DSL.

*Подсказка*: `router.new("greeting") |> router.on_command("start", ...)`, `reply.with_text(ctx:, text: "...")`.

---

**Упражнение A.7** (Среднее): Echo-роутер

```gleam
pub fn build_echo_router() -> Router(Nil, Nil) {
  todo
}
```

Создайте роутер-эхо: повторяет любой текст обратно с префиксом "Эхо: ".

Пример: "hello" -> "Эхо: hello"

*Подсказка*: `router.on_any_text(fn(ctx, text) { ... })`.

---

**Упражнение A.8** (Среднее): Register-роутер с многошаговым диалогом

```gleam
pub fn build_register_router() -> Router(Nil, Nil) {
  todo
}
```

Создайте роутер с многошаговым диалогом:

- `/register` -> бот спрашивает "Как вас зовут?"
- пользователь отвечает -> бот отвечает "Добро пожаловать, <имя>!"

*Подсказка*: `telega.wait_text(ctx:, or: None, timeout: None)`.

---

**Упражнение A.9** (Сложное): Menu-роутер с inline-клавиатурой

```gleam
pub fn build_menu_router() -> Router(Nil, Nil) {
  todo
}
```

Создайте роутер с inline-клавиатурой:

- `/menu` -> отправляет сообщение "Выберите действие:" с inline-кнопками "Список" и "Добавить"

Тест проверяет через `conversation.expect_keyboard(buttons: ["Список", "Добавить"])`.

*Подсказка*: `keyboard.inline_builder() |> keyboard.inline_text(...)`, `keyboard.string_callback_data("id")`, `keyboard.pack_callback(callback_data:, data:)`.

---

**Упражнение A.10** (Среднее): Merged-роутер

```gleam
pub fn build_merged_router() -> Router(Nil, Nil) {
  todo
}
```

Создайте два роутера и объедините их через `router.merge`:

- admin_router: `/ban` -> ответ содержит "заблокирован"
- user_router: `/start` -> ответ содержит "Привет"

*Подсказка*: `router.merge(first, second)`.

## Итоги

Мы построили Telegram-бота, который объединяет концепции из предыдущих глав:

- **Типобезопасность** — Gleam ловит ошибки на этапе компиляции
- **Router** — декларативная маршрутизация команд и сообщений
- **Композиция роутеров** — merge, compose, scope для модульной архитектуры
- **Session** — встроенное хранение данных пользователя через `SessionSettings`
- **Conversation API** — линейные многошаговые диалоги через `wait_*` функции
- **Flow API** — персистентные FSM с навигацией и композицией
- **Middleware** — кроссрежущая логика через `router.use_middleware`
- **Testing toolkit** — тестирование через conversation DSL без реального Telegram
- **Дерево супервизоров** — изоляция чатов, автоматический перезапуск (глава 8)
- **Result и use** — обработка ошибок без исключений (глава 5)

Telega — зрелая библиотека с продуманной архитектурой. Бот на Gleam работает на BEAM и наследует всю его отказоустойчивость: крэш обработчика одного сообщения не убивает весь сервер. Каждый чат обрабатывается в изолированном процессе, Conversation API делает код диалогов линейным и понятным, а Flow API добавляет персистентность и навигацию для сложных сценариев.

## Ресурсы

- [HexDocs — telega](https://hexdocs.pm/telega/)
- [HexDocs — telega_httpc](https://hexdocs.pm/telega_httpc/)
- [Telega — GitHub](https://github.com/bondiano/telega-gleam)
- [Telegram Bot API](https://core.telegram.org/bots/api)
