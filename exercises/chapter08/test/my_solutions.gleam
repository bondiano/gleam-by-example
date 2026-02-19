//// Здесь вы можете писать свои решения упражнений.
//// Тема: Процессы и OTP — акторы, сообщения, параллельные вычисления.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

// ============================================================
// Упражнение 1: echo_actor
// ============================================================

/// Тип сообщений для эхо-актора.
pub type EchoMsg {
  Echo(value: String, reply_to: Subject(String))
}

/// Запускает эхо-актор, который отвечает тем же сообщением.
pub fn start_echo() -> Result(Subject(EchoMsg), actor.StartError) {
  todo
}

/// Отправляет сообщение эхо-актору и получает ответ.
pub fn send_echo(subj: Subject(EchoMsg), message: String) -> String {
  todo
}

// ============================================================
// Упражнение 2: accumulator
// ============================================================

/// Тип сообщений для актора-аккумулятора.
pub type AccMsg {
  Add(value: Int)
  GetTotal(reply_to: Subject(Int))
}

/// Запускает актор-аккумулятор.
pub fn start_accumulator() -> Result(Subject(AccMsg), actor.StartError) {
  todo
}

/// Добавляет значение к аккумулятору.
pub fn accumulate(subj: Subject(AccMsg), value: Int) -> Nil {
  todo
}

/// Получает текущую сумму.
pub fn get_total(subj: Subject(AccMsg)) -> Int {
  todo
}

// ============================================================
// Упражнение 3: spawn_compute
// ============================================================

/// Запускает вычисление в отдельном процессе и возвращает результат.
pub fn spawn_compute(f: fn() -> a) -> a {
  todo
}

// ============================================================
// Упражнение 4: key_value_store
// ============================================================

/// Тип сообщений для KV-хранилища.
pub type KvMsg {
  Put(key: String, value: String)
  Get(key: String, reply_to: Subject(Result(String, Nil)))
  Delete(key: String)
  AllKeys(reply_to: Subject(List(String)))
}

/// Запускает актор KV-хранилища.
pub fn start_kv() -> Result(Subject(KvMsg), actor.StartError) {
  todo
}

/// Сохраняет значение по ключу.
pub fn kv_put(store: Subject(KvMsg), key: String, value: String) -> Nil {
  todo
}

/// Получает значение по ключу.
pub fn kv_get(store: Subject(KvMsg), key: String) -> Result(String, Nil) {
  todo
}

/// Удаляет значение по ключу.
pub fn kv_delete(store: Subject(KvMsg), key: String) -> Nil {
  todo
}

/// Возвращает все ключи.
pub fn kv_all_keys(store: Subject(KvMsg)) -> List(String) {
  todo
}

// ============================================================
// Упражнение 5: stack_actor
// ============================================================

/// Тип сообщений для стека.
pub type StackMsg(a) {
  StackPush(value: a)
  StackPop(reply_to: Subject(Result(a, Nil)))
  StackPeek(reply_to: Subject(Result(a, Nil)))
  StackSize(reply_to: Subject(Int))
}

/// Запускает актор-стек.
pub fn start_stack() -> Result(Subject(StackMsg(a)), actor.StartError) {
  todo
}

/// Кладёт элемент на вершину стека.
pub fn stack_push(stack: Subject(StackMsg(a)), value: a) -> Nil {
  todo
}

/// Извлекает верхний элемент.
pub fn stack_pop(stack: Subject(StackMsg(a))) -> Result(a, Nil) {
  todo
}

/// Смотрит на верхний элемент, не удаляя.
pub fn stack_peek(stack: Subject(StackMsg(a))) -> Result(a, Nil) {
  todo
}

/// Возвращает количество элементов.
pub fn stack_size(stack: Subject(StackMsg(a))) -> Int {
  todo
}

// ============================================================
// Упражнение 6: parallel_map
// ============================================================

/// Применяет функцию к каждому элементу списка параллельно.
/// Результаты в том же порядке, что и входной список.
pub fn parallel_map(items: List(a), f: fn(a) -> b) -> List(b) {
  todo
}
