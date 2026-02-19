import gleam/dict
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================
// Упражнение 1: echo_actor
// ============================================================

pub fn echo_actor_test() {
  let assert Ok(actor) = my_solutions.start_echo()
  my_solutions.send_echo(actor, "hello")
  |> should.equal("hello")
}

pub fn echo_actor_multiple_test() {
  let assert Ok(actor) = my_solutions.start_echo()
  my_solutions.send_echo(actor, "first")
  |> should.equal("first")
  my_solutions.send_echo(actor, "second")
  |> should.equal("second")
}

pub fn echo_actor_unicode_test() {
  let assert Ok(actor) = my_solutions.start_echo()
  my_solutions.send_echo(actor, "привет мир")
  |> should.equal("привет мир")
}

pub fn echo_actor_empty_test() {
  let assert Ok(actor) = my_solutions.start_echo()
  my_solutions.send_echo(actor, "")
  |> should.equal("")
}

// ============================================================
// Упражнение 2: accumulator
// ============================================================

pub fn accumulator_zero_test() {
  let assert Ok(actor) = my_solutions.start_accumulator()
  my_solutions.get_total(actor)
  |> should.equal(0)
}

pub fn accumulator_single_test() {
  let assert Ok(actor) = my_solutions.start_accumulator()
  my_solutions.accumulate(actor, 42)
  my_solutions.get_total(actor)
  |> should.equal(42)
}

pub fn accumulator_multiple_test() {
  let assert Ok(actor) = my_solutions.start_accumulator()
  my_solutions.accumulate(actor, 10)
  my_solutions.accumulate(actor, 20)
  my_solutions.accumulate(actor, 30)
  my_solutions.get_total(actor)
  |> should.equal(60)
}

pub fn accumulator_negative_test() {
  let assert Ok(actor) = my_solutions.start_accumulator()
  my_solutions.accumulate(actor, 100)
  my_solutions.accumulate(actor, -30)
  my_solutions.get_total(actor)
  |> should.equal(70)
}

// ============================================================
// Упражнение 3: spawn_compute
// ============================================================

pub fn spawn_compute_int_test() {
  my_solutions.spawn_compute(fn() { 42 })
  |> should.equal(42)
}

pub fn spawn_compute_string_test() {
  my_solutions.spawn_compute(fn() { "hello" })
  |> should.equal("hello")
}

pub fn spawn_compute_complex_test() {
  my_solutions.spawn_compute(fn() { list.range(1, 100) |> list.fold(0, fn(acc, x) { acc + x }) })
  |> should.equal(5050)
}

// ============================================================
// Упражнение 4: key_value_store
// ============================================================

pub fn kv_put_get_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_put(store, "name", "Alice")
  my_solutions.kv_get(store, "name")
  |> should.equal(Ok("Alice"))
}

pub fn kv_get_missing_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_get(store, "nonexistent")
  |> should.equal(Error(Nil))
}

pub fn kv_overwrite_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_put(store, "key", "value1")
  my_solutions.kv_put(store, "key", "value2")
  my_solutions.kv_get(store, "key")
  |> should.equal(Ok("value2"))
}

pub fn kv_delete_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_put(store, "key", "value")
  my_solutions.kv_delete(store, "key")
  my_solutions.kv_get(store, "key")
  |> should.equal(Error(Nil))
}

pub fn kv_delete_nonexistent_test() {
  let assert Ok(store) = my_solutions.start_kv()
  // Удаление несуществующего ключа не должно падать
  my_solutions.kv_delete(store, "ghost")
  my_solutions.kv_get(store, "ghost")
  |> should.equal(Error(Nil))
}

pub fn kv_all_keys_empty_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_all_keys(store)
  |> should.equal([])
}

pub fn kv_all_keys_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_put(store, "b", "2")
  my_solutions.kv_put(store, "a", "1")
  my_solutions.kv_put(store, "c", "3")
  let keys = my_solutions.kv_all_keys(store)
  // Порядок ключей в Dict не гарантирован,
  // проверяем содержимое через сортировку
  keys
  |> list.sort(string.compare)
  |> should.equal(["a", "b", "c"])
}

pub fn kv_multiple_operations_test() {
  let assert Ok(store) = my_solutions.start_kv()
  my_solutions.kv_put(store, "x", "1")
  my_solutions.kv_put(store, "y", "2")
  my_solutions.kv_put(store, "z", "3")
  my_solutions.kv_delete(store, "y")
  my_solutions.kv_get(store, "x") |> should.equal(Ok("1"))
  my_solutions.kv_get(store, "y") |> should.equal(Error(Nil))
  my_solutions.kv_get(store, "z") |> should.equal(Ok("3"))
  let keys = my_solutions.kv_all_keys(store)
  keys |> list.sort(string.compare) |> should.equal(["x", "z"])
}

// ============================================================
// Упражнение 5: stack_actor
// ============================================================

pub fn stack_empty_pop_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_pop(s)
  |> should.equal(Error(Nil))
}

pub fn stack_empty_peek_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_peek(s)
  |> should.equal(Error(Nil))
}

pub fn stack_empty_size_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_size(s)
  |> should.equal(0)
}

pub fn stack_push_pop_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_push(s, 1)
  my_solutions.stack_push(s, 2)
  my_solutions.stack_push(s, 3)
  my_solutions.stack_pop(s) |> should.equal(Ok(3))
  my_solutions.stack_pop(s) |> should.equal(Ok(2))
  my_solutions.stack_pop(s) |> should.equal(Ok(1))
  my_solutions.stack_pop(s) |> should.equal(Error(Nil))
}

pub fn stack_peek_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_push(s, 42)
  // Peek не удаляет элемент
  my_solutions.stack_peek(s) |> should.equal(Ok(42))
  my_solutions.stack_peek(s) |> should.equal(Ok(42))
  my_solutions.stack_size(s) |> should.equal(1)
}

pub fn stack_size_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_size(s) |> should.equal(0)
  my_solutions.stack_push(s, "a")
  my_solutions.stack_size(s) |> should.equal(1)
  my_solutions.stack_push(s, "b")
  my_solutions.stack_push(s, "c")
  my_solutions.stack_size(s) |> should.equal(3)
  let assert Ok(_) = my_solutions.stack_pop(s)
  my_solutions.stack_size(s) |> should.equal(2)
}

pub fn stack_lifo_order_test() {
  let assert Ok(s) = my_solutions.start_stack()
  my_solutions.stack_push(s, "first")
  my_solutions.stack_push(s, "second")
  my_solutions.stack_push(s, "third")
  // LIFO: last in, first out
  my_solutions.stack_pop(s) |> should.equal(Ok("third"))
  my_solutions.stack_pop(s) |> should.equal(Ok("second"))
  my_solutions.stack_pop(s) |> should.equal(Ok("first"))
}

// ============================================================
// Упражнение 6: parallel_map
// ============================================================

pub fn parallel_map_empty_test() {
  my_solutions.parallel_map([], fn(x) { x })
  |> should.equal([])
}

pub fn parallel_map_double_test() {
  my_solutions.parallel_map([1, 2, 3, 4, 5], fn(x) { x * 2 })
  |> should.equal([2, 4, 6, 8, 10])
}

pub fn parallel_map_strings_test() {
  my_solutions.parallel_map(["hello", "world"], string.uppercase)
  |> should.equal(["HELLO", "WORLD"])
}

pub fn parallel_map_single_test() {
  my_solutions.parallel_map([42], fn(x) { x + 1 })
  |> should.equal([43])
}

pub fn parallel_map_preserves_order_test() {
  // Убеждаемся, что порядок сохраняется даже при разном времени выполнения
  my_solutions.parallel_map([5, 3, 1, 4, 2], fn(x) { x * x })
  |> should.equal([25, 9, 1, 16, 4])
}

pub fn parallel_map_large_test() {
  let items = list.range(1, 50)
  let result = my_solutions.parallel_map(items, fn(x) { x * 2 })
  let expected = list.map(items, fn(x) { x * 2 })
  result |> should.equal(expected)
}
