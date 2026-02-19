//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/result

// ============================================================
// Упражнение 1: echo_actor
// ============================================================

pub type EchoMsg {
  Echo(value: String, reply_to: Subject(String))
}

pub fn start_echo() -> Result(Subject(EchoMsg), actor.StartError) {
  actor.new(Nil)
  |> actor.on_message(fn(_state, message) {
    case message {
      Echo(value:, reply_to:) -> {
        process.send(reply_to, value)
        actor.continue(Nil)
      }
    }
  })
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn send_echo(subj: Subject(EchoMsg), message: String) -> String {
  actor.call(subj, waiting: 1000, sending: fn(reply_to) {
    Echo(value: message, reply_to:)
  })
}

// ============================================================
// Упражнение 2: accumulator
// ============================================================

pub type AccMsg {
  Add(value: Int)
  GetTotal(reply_to: Subject(Int))
}

pub fn start_accumulator() -> Result(Subject(AccMsg), actor.StartError) {
  actor.new(0)
  |> actor.on_message(fn(state, message) {
    case message {
      Add(value:) -> actor.continue(state + value)
      GetTotal(reply_to:) -> {
        process.send(reply_to, state)
        actor.continue(state)
      }
    }
  })
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn accumulate(subj: Subject(AccMsg), value: Int) -> Nil {
  process.send(subj, Add(value:))
}

pub fn get_total(subj: Subject(AccMsg)) -> Int {
  actor.call(subj, waiting: 1000, sending: GetTotal)
}

// ============================================================
// Упражнение 3: spawn_compute
// ============================================================

pub fn spawn_compute(f: fn() -> a) -> a {
  let subject = process.new_subject()
  process.start(fn() { process.send(subject, f()) }, True)
  let assert Ok(result) = process.receive(subject, 5000)
  result
}

// ============================================================
// Упражнение 4: key_value_store
// ============================================================

pub type KvMsg {
  Put(key: String, value: String)
  Get(key: String, reply_to: Subject(Result(String, Nil)))
  Delete(key: String)
  AllKeys(reply_to: Subject(List(String)))
}

pub fn start_kv() -> Result(Subject(KvMsg), actor.StartError) {
  actor.new(dict.new())
  |> actor.on_message(fn(state: Dict(String, String), message: KvMsg) {
    case message {
      Put(key:, value:) -> actor.continue(dict.insert(state, key, value))
      Get(key:, reply_to:) -> {
        process.send(reply_to, dict.get(state, key))
        actor.continue(state)
      }
      Delete(key:) -> actor.continue(dict.delete(state, key))
      AllKeys(reply_to:) -> {
        process.send(reply_to, dict.keys(state))
        actor.continue(state)
      }
    }
  })
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn kv_put(store: Subject(KvMsg), key: String, value: String) -> Nil {
  process.send(store, Put(key:, value:))
}

pub fn kv_get(store: Subject(KvMsg), key: String) -> Result(String, Nil) {
  actor.call(store, waiting: 1000, sending: fn(reply_to) {
    Get(key:, reply_to:)
  })
}

pub fn kv_delete(store: Subject(KvMsg), key: String) -> Nil {
  process.send(store, Delete(key:))
}

pub fn kv_all_keys(store: Subject(KvMsg)) -> List(String) {
  actor.call(store, waiting: 1000, sending: AllKeys)
}

// ============================================================
// Упражнение 5: stack_actor
// ============================================================

pub type StackMsg(a) {
  StackPush(value: a)
  StackPop(reply_to: Subject(Result(a, Nil)))
  StackPeek(reply_to: Subject(Result(a, Nil)))
  StackSize(reply_to: Subject(Int))
}

pub fn start_stack() -> Result(Subject(StackMsg(a)), actor.StartError) {
  actor.new([])
  |> actor.on_message(fn(stack: List(a), message: StackMsg(a)) {
    case message {
      StackPush(value:) -> actor.continue([value, ..stack])

      StackPop(reply_to:) ->
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

      StackPeek(reply_to:) ->
        case stack {
          [] -> {
            process.send(reply_to, Error(Nil))
            actor.continue(stack)
          }
          [top, ..] -> {
            process.send(reply_to, Ok(top))
            actor.continue(stack)
          }
        }

      StackSize(reply_to:) -> {
        process.send(reply_to, list.length(stack))
        actor.continue(stack)
      }
    }
  })
  |> actor.start
  |> result.map(fn(started) { started.data })
}

pub fn stack_push(stack: Subject(StackMsg(a)), value: a) -> Nil {
  process.send(stack, StackPush(value:))
}

pub fn stack_pop(stack: Subject(StackMsg(a))) -> Result(a, Nil) {
  actor.call(stack, waiting: 1000, sending: StackPop)
}

pub fn stack_peek(stack: Subject(StackMsg(a))) -> Result(a, Nil) {
  actor.call(stack, waiting: 1000, sending: StackPeek)
}

pub fn stack_size(stack: Subject(StackMsg(a))) -> Int {
  actor.call(stack, waiting: 1000, sending: StackSize)
}

// ============================================================
// Упражнение 6: parallel_map
// ============================================================

pub fn parallel_map(items: List(a), f: fn(a) -> b) -> List(b) {
  // Создаём Subject для каждого элемента
  let subjects =
    list.map(items, fn(item) {
      let subject = process.new_subject()
      process.start(fn() { process.send(subject, f(item)) }, True)
      subject
    })

  // Собираем результаты в правильном порядке
  list.map(subjects, fn(subject) {
    let assert Ok(result) = process.receive(subject, 5000)
    result
  })
}
