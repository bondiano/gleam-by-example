import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result

// ============================================================
// Пример: актор-счётчик
// ============================================================

/// Тип сообщений для счётчика
pub type CounterMsg {
  Increment
  Decrement
  GetCount(reply_to: Subject(Int))
  Reset
}

/// Обработчик сообщений счётчика
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

/// Запускает актор-счётчик
pub fn start_counter() -> Result(Subject(CounterMsg), actor.StartError) {
  actor.new(0)
  |> actor.on_message(handle_counter)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

/// Получить текущее значение счётчика
pub fn get_count(counter: Subject(CounterMsg)) -> Int {
  actor.call(counter, waiting: 1000, sending: GetCount)
}

// ============================================================
// Пример: актор-стек (из текста главы)
// ============================================================

/// Тип сообщений для стека
pub type StackMsg(a) {
  Push(value: a)
  Pop(reply_to: Subject(Result(a, Nil)))
  StackSize(reply_to: Subject(Int))
}

/// Обработчик сообщений стека
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

    StackSize(reply_to) -> {
      process.send(reply_to, list.length(stack))
      actor.continue(stack)
    }
  }
}

/// Запускает актор-стек
pub fn start_stack() -> Result(Subject(StackMsg(a)), actor.StartError) {
  actor.new([])
  |> actor.on_message(handle_stack)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

// ============================================================
// Пример: параллельные вычисления
// ============================================================

/// Запускает функцию в отдельном процессе и возвращает результат
pub fn run_in_process(f: fn() -> a) -> a {
  let subject = process.new_subject()
  process.start(fn() { process.send(subject, f()) }, True)
  let assert Ok(result) = process.receive(subject, 5000)
  result
}

// ============================================================
// Пример: Key-Value Store
// ============================================================

/// Тип сообщений для KV-хранилища
pub type KvStoreMsg {
  KvPut(key: String, value: String)
  KvGet(key: String, reply_to: Subject(Result(String, Nil)))
  KvDelete(key: String)
  KvKeys(reply_to: Subject(List(String)))
}

/// Обработчик сообщений KV-хранилища
fn handle_kv(
  state: Dict(String, String),
  message: KvStoreMsg,
) -> actor.Next(Dict(String, String), KvStoreMsg) {
  case message {
    KvPut(key:, value:) -> actor.continue(dict.insert(state, key, value))
    KvGet(key:, reply_to:) -> {
      process.send(reply_to, dict.get(state, key))
      actor.continue(state)
    }
    KvDelete(key:) -> actor.continue(dict.delete(state, key))
    KvKeys(reply_to:) -> {
      process.send(reply_to, dict.keys(state))
      actor.continue(state)
    }
  }
}

/// Запускает KV-хранилище
pub fn start_kv_store() -> Result(Subject(KvStoreMsg), actor.StartError) {
  actor.new(dict.new())
  |> actor.on_message(handle_kv)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

// ============================================================
// Пример: использование Selector
// ============================================================

/// Демонстрация Selector — получение из нескольких источников
pub fn selector_demo() -> String {
  let string_subject = process.new_subject()
  let int_subject = process.new_subject()

  process.send(int_subject, 42)
  process.send(string_subject, "hello")

  let selector =
    process.new_selector()
    |> process.select(string_subject)
    |> process.select_map(int_subject, int.to_string)

  case process.selector_receive(selector, 100) {
    Ok(value) -> value
    Error(Nil) -> "таймаут"
  }
}

pub fn main() {
  let assert Ok(counter) = start_counter()

  actor.send(counter, Increment)
  actor.send(counter, Increment)
  actor.send(counter, Increment)
  actor.send(counter, Decrement)

  let count = get_count(counter)
  io.println("Счётчик: " <> int.to_string(count))
}
