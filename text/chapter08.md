# Процессы и OTP

> «Сделайте так, чтобы всё было процессом» — Джо Армстронг, создатель Erlang

## Цели главы

В этой главе мы:

- Поймём модель акторов — фундамент конкурентности на BEAM
- Научимся создавать процессы и обмениваться сообщениями
- Освоим `Subject` и `Selector` для типобезопасной коммуникации
- Изучим акторы (`gleam/otp/actor`) — основную абстракцию OTP
- Разберём паттерн запрос-ответ (`actor.call`)
- Познакомимся с мониторингом и связыванием процессов
- Узнаем про супервизоры и стратегии перезапуска
- Прочувствуем философию «Let it crash»

## Модель акторов

Модель акторов — концептуальная модель конкурентных вычислений, предложенная Карлом Хьюиттом в 1973 году. Это не абстрактная теория — именно она лежит в основе Erlang, Elixir и Gleam.

### Что такое актор?

**Актор** — примитивная единица вычислений. Каждый актор:

- Имеет **собственное приватное состояние** — никто другой не может его прочитать или изменить напрямую
- Имеет **почтовый ящик (mailbox)** — очередь входящих сообщений
- Обрабатывает сообщения **по одному, последовательно**

Когда актор получает сообщение, он может выполнить **три действия**:

1. **Создать новых акторов** — породить дочерние процессы
2. **Отправить сообщения** другим акторам
3. **Изменить своё состояние** — определить, как обрабатывать следующее сообщение

### Ключевые свойства

**Изоляция.** Акторы не имеют общей памяти. Единственный способ взаимодействия — отправка сообщений. Это устраняет целые классы ошибок: гонки данных (data races), мёртвые блокировки (deadlocks), нужду в мьютексах и семафорах.

**Асинхронность.** Отправка сообщения — неблокирующая операция. Отправитель не ждёт, пока получатель обработает сообщение. Сообщение попадает в mailbox и ждёт своей очереди.

**Последовательная обработка.** Хотя миллионы акторов работают параллельно, каждый конкретный актор обрабатывает сообщения строго по порядку. Внутри актора нет конкурентности — это упрощает рассуждения о корректности.

**Отказоустойчивость.** Если актор упал — ничего страшного. Его состояние изолировано, другие акторы не пострадали. Специальный актор-*супервизор* заметит падение и перезапустит упавшего.

### Аналогия: почтовая служба

Представьте, что каждый актор — это сотрудник в офисе с персональным почтовым ящиком. Сотрудники не ходят друг к другу за стол — они кладут записки в почтовый ящик получателя. Каждый сотрудник проверяет свой ящик и обрабатывает записки по одной. Если сотрудник заболел (упал), менеджер (супервизор) нанимает нового и ставит на то же место.

## BEAM: виртуальная машина для конкурентности

BEAM (Bogdan/Björn's Erlang Abstract Machine) — виртуальная машина, на которой работает Gleam (при компиляции в Erlang-таргет). BEAM была создана Ericsson в 1998 году и с тех пор используется в телекоммуникациях, мессенджерах (WhatsApp, Discord) и системах реального времени.

### Процессы BEAM

Процессы BEAM — это **не** потоки операционной системы. Это чрезвычайно легковесные сущности:

| Характеристика | Процессы BEAM | Потоки ОС |
|----------------|---------------|-----------|
| Начальный размер | ~300 байт | ~1 МБ стека |
| Количество | миллионы | тысячи |
| Создание | микросекунды | миллисекунды |
| Планировщик | BEAM (вытесняющий) | ОС |
| Изоляция памяти | полная (свой heap) | общая память |
| GC | per-process (не stop-the-world) | общий |

### Вытесняющая многозадачность

BEAM использует **вытесняющую** (preemptive) многозадачность. Каждому процессу выделяется квота «редукций» (~4000 операций). Когда квота израсходована, планировщик переключается на другой процесс. Это гарантирует:

- **Ни один процесс не может заблокировать систему** — даже бесконечный цикл не остановит другие процессы
- **Soft real-time** — время отклика предсказуемо
- **Справедливость** — все процессы получают процессорное время

### Распределённость

Процессы BEAM могут общаться не только внутри одной машины, но и через сеть. BEAM поддерживает кластеры узлов (nodes), где процесс на узле A может отправить сообщение процессу на узле B так же просто, как локальному. Для этого используется модуль `gleam/erlang/node`.

## Процессы в Gleam

Gleam предоставляет типобезопасные обёртки над процессами BEAM через модуль `gleam/erlang/process`.

### Subject — типизированный канал

`Subject(message)` — ключевой тип для коммуникации между процессами. Subject — это типизированный канал, через который можно **отправлять** и **получать** сообщения определённого типа.

```gleam
import gleam/erlang/process

pub fn main() {
  // Создаём Subject для строковых сообщений
  let subject: process.Subject(String) = process.new_subject()

  // Отправляем сообщение
  process.send(subject, "привет!")

  // Получаем сообщение (таймаут 1000 мс)
  let assert Ok(message) = process.receive(subject, 1000)
  // message == "привет!"
}
```

Важные свойства Subject:

- **Типизированный** — `Subject(String)` принимает только строки, `Subject(Int)` — только числа
- **Принадлежит процессу** — каждый Subject «принадлежит» процессу, который его создал. Только этот процесс может *получать* из него сообщения
- **Передаваемый** — Subject можно передать другому процессу, чтобы тот мог *отправлять* в него сообщения

### Создание процессов

Для создания нового процесса используется `process.start`:

```gleam
import gleam/erlang/process
import gleam/io

pub fn main() {
  // Создаём Subject для получения результата
  let subject = process.new_subject()

  // Запускаем новый процесс
  // Второй аргумент: True = связанный (linked) процесс
  process.start(fn() {
    // Этот код выполняется в ДРУГОМ процессе
    let result = expensive_computation()
    process.send(subject, result)
  }, True)

  // Ждём результат в текущем процессе
  let assert Ok(result) = process.receive(subject, 5000)
  io.println("Результат: " <> result)
}

fn expensive_computation() -> String {
  process.sleep(100)  // Имитация долгой работы
  "42"
}
```

Здесь `process.start(fn, linked)` создаёт новый процесс, который выполняет переданную функцию. Второй аргумент определяет, будет ли новый процесс **связан** с родительским (подробнее о связывании — ниже).

### Пример: параллельные вычисления

Запустим несколько процессов одновременно и соберём результаты:

```gleam
import gleam/erlang/process
import gleam/int
import gleam/list

pub fn parallel_sum(numbers: List(Int)) -> Int {
  let subject = process.new_subject()

  // Запускаем процесс для каждого числа
  list.each(numbers, fn(n) {
    process.start(fn() {
      // Каждый процесс вычисляет квадрат
      process.send(subject, n * n)
    }, True)
  })

  // Собираем результаты
  let length = list.length(numbers)
  collect_results(subject, length, 0)
}

fn collect_results(
  subject: process.Subject(Int),
  remaining: Int,
  acc: Int,
) -> Int {
  case remaining {
    0 -> acc
    _ -> {
      let assert Ok(value) = process.receive(subject, 5000)
      collect_results(subject, remaining - 1, acc + value)
    }
  }
}
```

> **Важно:** порядок получения результатов **не гарантирован**. Процессы работают параллельно, и кто первый вычислит — тот первый отправит сообщение. Для суммы это не важно, но для упорядоченных результатов нужна дополнительная логика.

### receive с таймаутом

`process.receive(subject, timeout_ms)` возвращает `Result`:

```gleam
case process.receive(subject, 100) {
  Ok(message) -> io.println("Получено: " <> message)
  Error(Nil) -> io.println("Таймаут: сообщение не пришло за 100 мс")
}
```

Таймаут в миллисекундах. Если сообщение не пришло за указанное время — возвращается `Error(Nil)`. Для бесконечного ожидания используйте `process.receive_forever(subject)`.

## Selector — мультиплексирование сообщений

Что если процесс ждёт сообщения из нескольких источников? Например, и от пользователя, и от таймера? Для этого есть `Selector`.

`Selector(payload)` позволяет ждать сообщения от **нескольких** Subject одновременно, возвращая первое пришедшее:

```gleam
import gleam/erlang/process
import gleam/int

pub fn main() {
  let string_subject = process.new_subject()
  let int_subject = process.new_subject()

  // Отправляем сообщения разных типов
  process.send(int_subject, 42)
  process.send(string_subject, "hello")

  // Создаём Selector, который принимает оба типа → String
  let selector =
    process.new_selector()
    |> process.select(string_subject)
    |> process.select_map(int_subject, int.to_string)

  // Получаем первое доступное сообщение
  case process.selector_receive(selector, 100) {
    Ok(value) -> value  // Строка — либо "hello", либо "42"
    Error(Nil) -> "таймаут"
  }
}
```

Ключевые функции:

- `process.new_selector()` — создаёт пустой селектор
- `process.select(selector, subject)` — добавляет Subject (тип должен совпадать с payload)
- `process.select_map(selector, subject, fn)` — добавляет Subject с преобразованием типа
- `process.selector_receive(selector, timeout)` — ждёт сообщение из любого добавленного Subject
- `process.merge_selector(a, b)` — объединяет два селектора

Selector полезен, когда актор должен реагировать на разные типы событий: пользовательские сообщения, таймеры, сигналы от других процессов.

## Паттерн запрос-ответ

Часто нужен синхронный вызов: отправить запрос и дождаться ответа. Функция `process.call` реализует этот паттерн:

```gleam
import gleam/erlang/process

pub fn main() {
  let server = process.new_subject()

  // Запускаем «сервер» в отдельном процессе
  process.start(fn() { server_loop(server, 0) }, True)

  // Синхронный вызов: отправляем запрос, ждём ответ
  let count = process.call(server, 1000, fn(reply_to) {
    GetCount(reply_to:)
  })
  // count == 0
}

pub type ServerMsg {
  Increment
  GetCount(reply_to: process.Subject(Int))
}

fn server_loop(
  subject: process.Subject(ServerMsg),
  state: Int,
) -> Nil {
  case process.receive_forever(subject) {
    Increment -> server_loop(subject, state + 1)
    GetCount(reply_to:) -> {
      process.send(reply_to, state)
      server_loop(subject, state)
    }
  }
}
```

`process.call(subject, timeout, make_request)` делает три вещи:

1. Создаёт временный Subject для ответа
2. Вызывает `make_request(reply_subject)` и отправляет результат серверу
3. Ждёт ответ на временном Subject

Если ответ не пришёл за `timeout` миллисекунд — процесс падает (crash). Для более мягкой обработки таймаута используйте ручной `receive`.

## Акторы — процессы с состоянием

Паттерн «процесс + состояние + цикл обработки сообщений» настолько частый, что для него есть готовая абстракция — **актор** из `gleam/otp/actor`.

### Зачем нужны акторы?

Сравните ручной цикл обработки:

```gleam
// Ручная реализация — много шаблонного кода
fn server_loop(subject, state) {
  case process.receive_forever(subject) {
    msg1 -> server_loop(subject, handle_msg1(state, msg1))
    msg2 -> server_loop(subject, handle_msg2(state, msg2))
  }
}
```

И актор:

```gleam
// Актор — только логика обработки
fn handle_message(state, message) {
  case message {
    msg1 -> actor.continue(handle_msg1(state, msg1))
    msg2 -> actor.continue(handle_msg2(state, msg2))
  }
}
```

Актор берёт на себя:

- Создание процесса и Subject
- Цикл получения сообщений
- Обработку инициализации
- Интеграцию с OTP (супервизоры, hot reload)

### Создание актора

Актор создаётся через builder-паттерн:

```gleam
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result

pub type CounterMsg {
  Increment
  Decrement
  GetCount(reply_to: Subject(Int))
}

fn handle_counter(state: Int, message: CounterMsg) -> actor.Next(Int, CounterMsg) {
  case message {
    Increment -> actor.continue(state + 1)
    Decrement -> actor.continue(state - 1)
    GetCount(reply_to) -> {
      process.send(reply_to, state)
      actor.continue(state)
    }
  }
}

pub fn start_counter() -> Result(Subject(CounterMsg), actor.StartError) {
  actor.new(0)                          // начальное состояние
  |> actor.on_message(handle_counter)   // обработчик сообщений
  |> actor.start                        // запуск процесса
  |> result.map(fn(started) { started.data })  // извлекаем Subject
}
```

Разберём по шагам:

1. **`actor.new(0)`** — создаёт builder с начальным состоянием `0`
2. **`actor.on_message(handle_counter)`** — устанавливает функцию обработки. Сигнатура: `fn(state, message) -> actor.Next(state, message)`
3. **`actor.start`** — запускает процесс, возвращает `Result(Started(data), StartError)`, где `data` — Subject для отправки сообщений актору
4. **`result.map(fn(started) { started.data })`** — извлекаем Subject из `Started`

### Обработка сообщений

Функция-обработчик возвращает `actor.Next(state, message)`, указывая, что делать дальше:

```gleam
// Продолжить работу с новым состоянием
actor.continue(new_state)

// Остановить актор (нормальное завершение)
actor.stop()

// Остановить актор с ошибкой
actor.stop_abnormal("причина ошибки")
```

### actor.send — fire-and-forget

Для отправки сообщения без ожидания ответа:

```gleam
pub fn main() {
  let assert Ok(counter) = start_counter()

  // Отправляем сообщения — не ждём ответа
  actor.send(counter, Increment)
  actor.send(counter, Increment)
  actor.send(counter, Increment)
  actor.send(counter, Decrement)
}
```

`actor.send` — это просто псевдоним для `process.send`. Сообщение попадает в mailbox актора и будет обработано, когда до него дойдёт очередь.

### actor.call — запрос с ответом

Для синхронных запросов используйте `actor.call`:

```gleam
pub fn main() {
  let assert Ok(counter) = start_counter()

  actor.send(counter, Increment)
  actor.send(counter, Increment)

  // Синхронный запрос — ждём ответ (таймаут 1000 мс)
  let count = actor.call(counter, waiting: 1000, sending: GetCount)
  // count == 2
}
```

`actor.call(subject, waiting: timeout, sending: make_message)` работает так:

1. Создаёт временный Subject для ответа
2. Вызывает `make_message(reply_subject)` — создаёт сообщение с каналом ответа
3. Отправляет это сообщение актору
4. Ждёт ответ

Если конструктор сообщения принимает ровно один аргумент (Subject ответа), можно передать его напрямую:

```gleam
// Эквивалентные записи:
actor.call(counter, waiting: 1000, sending: GetCount)
actor.call(counter, waiting: 1000, sending: fn(reply) { GetCount(reply) })
```

### Полный пример: актор-стек

```gleam
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result

pub type StackMsg(a) {
  Push(value: a)
  Pop(reply_to: Subject(Result(a, Nil)))
  Size(reply_to: Subject(Int))
}

fn handle_stack(
  stack: List(a),
  message: StackMsg(a),
) -> actor.Next(List(a), StackMsg(a)) {
  case message {
    Push(value) -> actor.continue([value, ..stack])

    Pop(reply_to) -> {
      case stack {
        [] -> {
          process.send(reply_to, Error(Nil))
          actor.continue([])
        }
        [top, ..rest] -> {
          process.send(reply_to, Ok(top))
          actor.continue(rest)
        }
      }
    }

    Size(reply_to) -> {
      process.send(reply_to, list.length(stack))
      actor.continue(stack)
    }
  }
}

pub fn start_stack() -> Result(Subject(StackMsg(a)), actor.StartError) {
  actor.new([])
  |> actor.on_message(handle_stack)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

// Удобные обёртки
pub fn push(stack: Subject(StackMsg(a)), value: a) -> Nil {
  actor.send(stack, Push(value))
}

pub fn pop(stack: Subject(StackMsg(a))) -> Result(a, Nil) {
  actor.call(stack, waiting: 1000, sending: Pop)
}

pub fn size(stack: Subject(StackMsg(a))) -> Int {
  actor.call(stack, waiting: 1000, sending: Size)
}
```

Обратите внимание на паттерн: **приватный тип сообщений + публичные обёртки**. Пользователь актора вызывает `push(stack, 42)`, а не `actor.send(stack, Push(42))`. Это скрывает детали протокола.

### Именованные акторы

По умолчанию для взаимодействия с актором нужен его Subject. Но иногда удобно обращаться к актору по **имени** — например, если это глобальный сервис (кеш, конфигурация, счётчик метрик).

```gleam
import gleam/erlang/process
import gleam/otp/actor

pub fn start_named_counter(
  name: process.Name(CounterMsg),
) -> Result(Subject(CounterMsg), actor.StartError) {
  actor.new(0)
  |> actor.named(name)
  |> actor.on_message(handle_counter)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn main() {
  // Создаём уникальное имя
  let counter_name = process.new_name("global_counter")

  // Запускаем именованный актор
  let assert Ok(_) = start_named_counter(counter_name)

  // Получаем Subject по имени — из любого места программы
  let subject = process.named_subject(counter_name)
  actor.send(subject, Increment)
}
```

Именованные акторы полезны, когда Subject нельзя передать напрямую — например, в распределённых системах или при интеграции с Erlang-кодом.

## Мониторинг и связывание

Что происходит, когда процесс падает? BEAM предоставляет два механизма обнаружения сбоев.

### link — связывание процессов

**Связывание** (link) создаёт двунаправленную связь между процессами. Если один из связанных процессов падает — второй тоже падает:

```gleam
import gleam/erlang/process

pub fn main() {
  // process.start с True создаёт связанный процесс
  let _pid = process.start(fn() {
    process.sleep(100)
    panic as "Я упал!"
  }, True)  // True = linked

  // Через 100 мс дочерний процесс упадёт,
  // и текущий процесс тоже упадёт (они связаны)
  process.sleep(200)
}
```

Связывание обеспечивает **домен отказа** (failure domain): группа связанных процессов либо все работают, либо все падают. Это полезно, когда процессы зависят друг от друга.

### monitor — наблюдение за процессами

**Мониторинг** — однонаправленное наблюдение. Наблюдатель получает сообщение о падении, но сам не падает:

```gleam
import gleam/erlang/process
import gleam/io

pub fn main() {
  // Запускаем несвязанный процесс
  let pid = process.start(fn() {
    process.sleep(100)
    panic as "Авария!"
  }, False)  // False = unlinked

  // Начинаем мониторинг
  let monitor = process.monitor(pid)

  // Создаём Selector для получения Down-сообщений
  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })

  // Ждём сообщение о падении
  case process.selector_receive(selector, 500) {
    Ok(_down) -> io.println("Процесс упал, но мы живы!")
    Error(Nil) -> io.println("Таймаут")
  }
}
```

Мониторинг полезен, когда нужно **реагировать** на падение, не разделяя судьбу упавшего процесса.

### trap_exits — перехват сигналов завершения

`trap_exits` позволяет связанному процессу **перехватить** сигнал завершения вместо того, чтобы самому упасть:

```gleam
import gleam/erlang/process

pub fn main() {
  // Включаем перехват сигналов завершения
  process.trap_exits(True)

  // Запускаем связанный процесс, который упадёт
  let _pid = process.start(fn() {
    process.sleep(50)
    panic as "Ошибка"
  }, True)

  // Вместо падения получаем ExitMessage
  let selector =
    process.new_selector()
    |> process.select_trapped_exits(fn(exit_msg) { exit_msg })

  case process.selector_receive(selector, 200) {
    Ok(process.ExitMessage(pid: _, reason:)) -> {
      case reason {
        process.Normal -> "нормальное завершение"
        process.Killed -> "процесс убит"
        process.Abnormal(_) -> "аварийное завершение"
      }
    }
    Error(Nil) -> "таймаут"
  }
}
```

> **Примечание:** `trap_exits` нужен редко. В большинстве случаев используйте супервизоры вместо ручного перехвата.

## Таймеры

BEAM предоставляет встроенные таймеры для отложенной отправки сообщений.

### send_after

`process.send_after(subject, delay, message)` отправляет сообщение через указанное количество миллисекунд:

```gleam
import gleam/erlang/process

pub fn main() {
  let subject = process.new_subject()

  // Отправить сообщение через 500 мс
  let timer = process.send_after(subject, 500, "Время вышло!")

  // Ждём сообщение
  let assert Ok(msg) = process.receive(subject, 1000)
  // msg == "Время вышло!"
}
```

### cancel_timer

Таймер можно отменить до срабатывания:

```gleam
let timer = process.send_after(subject, 5000, "tick")

// Отменяем таймер
case process.cancel_timer(timer) {
  process.Cancelled(time_remaining:) ->
    io.println("Отменён, оставалось: " <> int.to_string(time_remaining) <> " мс")
  process.TimerNotFound ->
    io.println("Таймер уже сработал или не найден")
}
```

### sleep

`process.sleep(ms)` приостанавливает текущий процесс на указанное время. Это **не** блокирует другие процессы — только текущий:

```gleam
process.sleep(1000)  // Пауза 1 секунда
```

## Супервизоры

Супервизоры — сердце философии «Let it crash». Вместо того чтобы писать защитный код для каждой возможной ошибки, мы позволяем процессам падать и полагаемся на супервизоров для восстановления.

### Философия «Let it crash»

В традиционном программировании ошибки обрабатываются «оборонительно»:

```
// Типичный подход — оборонительное программирование
try {
  resource = acquire()
  try {
    result = process(resource)
  } catch (ProcessingError e) {
    log(e)
    rollback(resource)
    return default
  } finally {
    release(resource)
  }
} catch (AcquireError e) {
  log(e)
  return null
}
```

На BEAM подход другой:

```
// BEAM подход — Let it crash
result = process(acquire())
// Если что-то пошло не так — процесс упадёт
// Супервизор перезапустит его в чистом состоянии
```

**Почему это работает?**

1. **Изоляция** — падение одного процесса не затрагивает другие
2. **Чистый перезапуск** — новый процесс начинает с известного хорошего состояния
3. **Отделение обработки ошибок** — логика восстановления в супервизоре, бизнес-логика — в акторе
4. **Работает для непредвиденных ошибок** — нет нужды предвидеть все возможные сбои

> **Важно:** «Let it crash» не означает «игнорируй ошибки». Ожидаемые ошибки (невалидный ввод, файл не найден) обрабатываются через `Result`. «Let it crash» — для **неожиданных** ситуаций (OOM, битые данные, баги).

### static_supervisor

`gleam/otp/static_supervisor` создаёт дерево надзора:

```gleam
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub fn start_application() -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(supervision.worker(start_counter))
  |> supervisor.add(supervision.worker(start_cache))
  |> supervisor.start
}
```

`supervision.worker(start_fn)` оборачивает функцию запуска актора. Супервизор вызовет эту функцию при старте и при каждом перезапуске.

### Стратегии перезапуска

Супервизор должен знать, что делать при падении дочернего процесса. Три стратегии:

**OneForOne** — перезапускается только упавший процесс:

```
До падения:  [A] [B] [C]
B падает:     [A] [B'] [C]    ← только B перезапущен
```

Используйте, когда дочерние процессы **независимы** друг от друга.

**OneForAll** — при падении одного перезапускаются **все**:

```
До падения:  [A] [B] [C]
B падает:     [A'] [B'] [C']  ← все перезапущены
```

Используйте, когда дочерние процессы **тесно связаны** и не могут работать без друг друга.

**RestForOne** — перезапускаются упавший и все запущенные **после** него:

```
До падения:  [A] [B] [C]
B падает:     [A] [B'] [C']   ← B и C перезапущены, A не тронут
```

Используйте, когда есть **упорядоченная зависимость**: C зависит от B, B зависит от A.

```gleam
// OneForOne — независимые воркеры
supervisor.new(supervisor.OneForOne)

// OneForAll — тесно связанные сервисы
supervisor.new(supervisor.OneForAll)

// RestForOne — цепочка зависимостей: db → cache → web
supervisor.new(supervisor.RestForOne)
|> supervisor.add(supervision.worker(start_database))
|> supervisor.add(supervision.worker(start_cache))
|> supervisor.add(supervision.worker(start_web))
```

### Настройка допуска перезапуска

Чтобы избежать бесконечных циклов перезапуска, можно ограничить частоту:

```gleam
supervisor.new(supervisor.OneForOne)
|> supervisor.restart_tolerance(intensity: 5, period: 60)
// Максимум 5 перезапусков за 60 секунд
// Если больше — супервизор сам завершается
```

### Стратегии перезапуска дочерних процессов

Каждый дочерний процесс имеет собственную стратегию:

```gleam
// Permanent — всегда перезапускать (по умолчанию)
supervision.worker(start_critical_service)
|> supervision.restart(supervision.Permanent)

// Transient — перезапускать только при аварийном завершении
supervision.worker(start_worker)
|> supervision.restart(supervision.Transient)

// Temporary — никогда не перезапускать
supervision.worker(start_one_off_task)
|> supervision.restart(supervision.Temporary)
```

### Деревья супервизоров

В реальных приложениях супервизоры образуют дерево. Корневой супервизор наблюдает за дочерними супервизорами, которые в свою очередь наблюдают за рабочими процессами:

```
                [Корневой супервизор]
                /                   \
    [Супервизор БД]           [Супервизор воркеров]
    /           \              /        |        \
  [Пул         [Кеш]      [Воркер1] [Воркер2] [Воркер3]
   подключений]
```

Если Воркер2 упадёт — Супервизор воркеров перезапустит его. Если Супервизор воркеров сам упадёт — Корневой супервизор перезапустит его вместе со всеми воркерами. Это обеспечивает **поэтапное восстановление**.

## Проект: конкурентный счётчик с супервизором

Объединим все концепции в рабочем проекте. Создадим счётчик с API для инкремента, декремента и получения значения, обёрнутый в супервизор для отказоустойчивости.

### Определение актора

```gleam
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/int
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/result

// Тип сообщений
pub type CounterMsg {
  Increment
  Decrement
  GetCount(reply_to: Subject(Int))
  Reset
}

// Обработчик сообщений
fn handle_counter(
  state: Int,
  message: CounterMsg,
) -> actor.Next(Int, CounterMsg) {
  case message {
    Increment -> actor.continue(state + 1)
    Decrement -> actor.continue(state - 1)
    GetCount(reply_to) -> {
      process.send(reply_to, state)
      actor.continue(state)
    }
    Reset -> actor.continue(0)
  }
}

// Функция запуска актора (для супервизора)
pub fn start_counter() -> actor.StartResult(Subject(CounterMsg)) {
  actor.new(0)
  |> actor.on_message(handle_counter)
  |> actor.start
}

// Удобный API
pub fn increment(counter: Subject(CounterMsg)) -> Nil {
  actor.send(counter, Increment)
}

pub fn decrement(counter: Subject(CounterMsg)) -> Nil {
  actor.send(counter, Decrement)
}

pub fn get_count(counter: Subject(CounterMsg)) -> Int {
  actor.call(counter, waiting: 1000, sending: GetCount)
}

pub fn reset(counter: Subject(CounterMsg)) -> Nil {
  actor.send(counter, Reset)
}
```

### Супервизор

```gleam
pub fn start_supervised() -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.restart_tolerance(intensity: 3, period: 10)
  |> supervisor.add(supervision.worker(start_counter))
  |> supervisor.start
}
```

### Использование

```gleam
pub fn main() {
  let assert Ok(sup) = start_supervised()

  // Получаем Subject счётчика через start_counter напрямую
  let assert Ok(counter) = start_counter()
    |> result.map(fn(started) { started.data })

  increment(counter)
  increment(counter)
  increment(counter)
  decrement(counter)

  let count = get_count(counter)
  io.println("Счётчик: " <> int.to_string(count))
  // Счётчик: 2
}
```

Если процесс счётчика упадёт (из-за бага, OOM или непредвиденной ошибки), супервизор автоматически перезапустит его с начальным состоянием `0`.

## Сравнение с другими языками

| Возможность | Gleam/BEAM | Go | Rust | OCaml |
|-------------|-----------|-----|------|-------|
| Конкурентность | Процессы (акторы) | Goroutines + каналы | tokio tasks + каналы | Eio fibers |
| Изоляция | Полная (свой heap) | Общая память | Ownership + Send/Sync | Общая память |
| Планировщик | Вытесняющий | Кооперативный | Кооперативный | Кооперативный |
| Отказоустойчивость | Супервизоры (OTP) | Нет встроенной | Нет встроенной | Нет встроенной |
| Типобезопасность сообщений | Subject(msg) | chan T | mpsc::Sender<T> | Нет |
| Распределённость | Встроенная (nodes) | Нет | Нет | Нет |

Ключевое преимущество BEAM — **вытесняющий планировщик** и **встроенная отказоустойчивость** через деревья супервизоров. Другие языки требуют внешних фреймворков для аналогичного поведения.

## Упражнения

Все упражнения этой главы работают с процессами и акторами. Решения пишите в файле `exercises/chapter08/test/my_solutions.gleam`. Запускайте тесты:

```sh
$ cd exercises/chapter08
$ gleam test
```

### 1. echo_actor — эхо-актор (Лёгкое)

Создайте актор, который возвращает полученное сообщение обратно отправителю.

```gleam
pub type EchoMsg {
  Echo(value: String, reply_to: process.Subject(String))
}

pub fn start_echo() -> Result(process.Subject(EchoMsg), actor.StartError)
pub fn send_echo(actor: process.Subject(EchoMsg), message: String) -> String
```

**Примеры:**

```
send_echo(actor, "hello") == "hello"
send_echo(actor, "мир") == "мир"
```

**Подсказка:** состояние актора не используется — передайте `Nil`. Для `send_echo` используйте `actor.call`.

### 2. accumulator — актор-аккумулятор (Лёгкое)

Создайте актор, который накапливает сумму целых чисел.

```gleam
pub type AccMsg {
  Add(value: Int)
  GetTotal(reply_to: process.Subject(Int))
}

pub fn start_accumulator() -> Result(process.Subject(AccMsg), actor.StartError)
pub fn accumulate(actor: process.Subject(AccMsg), value: Int) -> Nil
pub fn get_total(actor: process.Subject(AccMsg)) -> Int
```

**Примеры:**

```
accumulate(actor, 10)
accumulate(actor, 20)
accumulate(actor, 30)
get_total(actor) == 60
```

**Подсказка:** начальное состояние — `0`. `accumulate` использует `actor.send` (fire-and-forget), `get_total` — `actor.call`.

### 3. spawn_compute — вычисление в процессе (Лёгкое)

Реализуйте функцию, которая запускает произвольное вычисление в отдельном процессе и возвращает результат в вызывающий процесс.

```gleam
pub fn spawn_compute(f: fn() -> a) -> a
```

**Примеры:**

```
spawn_compute(fn() { 42 }) == 42
spawn_compute(fn() { "hello" }) == "hello"
```

**Подсказка:** создайте Subject, запустите процесс через `process.start`, в процессе вызовите `f()` и отправьте результат через `process.send`. Получите результат через `process.receive`.

### 4. key_value_store — хранилище ключ-значение (Среднее)

Создайте актор, реализующий in-memory хранилище ключ-значение на основе `Dict`.

```gleam
pub type KvMsg {
  Put(key: String, value: String)
  Get(key: String, reply_to: process.Subject(Result(String, Nil)))
  Delete(key: String)
  AllKeys(reply_to: process.Subject(List(String)))
}

pub fn start_kv() -> Result(process.Subject(KvMsg), actor.StartError)
pub fn kv_put(store: process.Subject(KvMsg), key: String, value: String) -> Nil
pub fn kv_get(store: process.Subject(KvMsg), key: String) -> Result(String, Nil)
pub fn kv_delete(store: process.Subject(KvMsg), key: String) -> Nil
pub fn kv_all_keys(store: process.Subject(KvMsg)) -> List(String)
```

**Примеры:**

```
kv_put(store, "name", "Alice")
kv_get(store, "name") == Ok("Alice")
kv_get(store, "age") == Error(Nil)
kv_delete(store, "name")
kv_get(store, "name") == Error(Nil)
kv_all_keys(store) == []
```

**Подсказка:** начальное состояние — `dict.new()`. Используйте `dict.insert`, `dict.get`, `dict.delete`, `dict.keys`.

### 5. stack_actor — актор-стек (Среднее)

Создайте актор, реализующий стек (LIFO). Поддержите операции: push, pop, peek (посмотреть верхний без удаления), size.

```gleam
pub type StackMsg(a) {
  StackPush(value: a)
  StackPop(reply_to: process.Subject(Result(a, Nil)))
  StackPeek(reply_to: process.Subject(Result(a, Nil)))
  StackSize(reply_to: process.Subject(Int))
}

pub fn start_stack() -> Result(process.Subject(StackMsg(a)), actor.StartError)
pub fn stack_push(stack: process.Subject(StackMsg(a)), value: a) -> Nil
pub fn stack_pop(stack: process.Subject(StackMsg(a))) -> Result(a, Nil)
pub fn stack_peek(stack: process.Subject(StackMsg(a))) -> Result(a, Nil)
pub fn stack_size(stack: process.Subject(StackMsg(a))) -> Int
```

**Примеры:**

```
stack_push(s, 1)
stack_push(s, 2)
stack_push(s, 3)
stack_peek(s) == Ok(3)    // верхний элемент, не удаляя
stack_pop(s) == Ok(3)     // извлечь верхний
stack_pop(s) == Ok(2)
stack_size(s) == 1        // остался только 1
stack_pop(s) == Ok(1)
stack_pop(s) == Error(Nil) // пустой стек
```

**Подсказка:** состояние — `List(a)`. Push — `[value, ..stack]`. Pop — pattern matching на `[top, ..rest]`.

### 6. parallel_map — параллельный map (Сложное)

Реализуйте функцию, которая применяет функцию к каждому элементу списка **параллельно**, запуская отдельный процесс для каждого элемента.

```gleam
pub fn parallel_map(items: List(a), f: fn(a) -> b) -> List(b)
```

Результаты должны быть в **том же порядке**, что и входной список.

**Примеры:**

```
parallel_map([1, 2, 3], fn(x) { x * 2 }) == [2, 4, 6]
parallel_map(["a", "b"], string.uppercase) == ["A", "B"]
parallel_map([], fn(x) { x }) == []
```

**Подсказка:** для сохранения порядка создайте отдельный Subject для каждого элемента. Запустите процесс для каждого элемента, который отправит результат в свой Subject. Затем соберите результаты в правильном порядке через `list.map(subjects, fn(s) { receive(s, ...) })`.

## Заключение

В этой главе мы изучили:

- **Модель акторов** — изоляция, mailbox, последовательная обработка
- **Процессы BEAM** — легковесные, с вытесняющей многозадачностью
- **Subject** — типизированный канал для обмена сообщениями
- **Selector** — мультиплексирование нескольких источников
- **Акторы** (`gleam/otp/actor`) — процессы с состоянием и обработчиком
- **actor.send** и **actor.call** — асинхронные и синхронные сообщения
- **Мониторинг и связывание** — обнаружение сбоев
- **Супервизоры** — автоматический перезапуск упавших процессов
- **«Let it crash»** — философия отказоустойчивости

В следующей главе мы изучим тестирование в Gleam — от unit-тестов с gleeunit до property-based testing с qcheck и snapshot-тестов с birdie.
