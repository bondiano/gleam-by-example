import gleam/int
import gleam/list
import gleeunit
import gleeunit/should
import my_solutions
import qcheck

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================
// Упражнение 1: is_sorted (unit-тесты)
// ============================================================

pub fn is_sorted_empty_test() {
  my_solutions.is_sorted([])
  |> should.be_true
}

pub fn is_sorted_single_test() {
  my_solutions.is_sorted([1])
  |> should.be_true
}

pub fn is_sorted_ascending_test() {
  my_solutions.is_sorted([1, 2, 3, 4, 5])
  |> should.be_true
}

pub fn is_sorted_descending_test() {
  my_solutions.is_sorted([5, 4, 3, 2, 1])
  |> should.be_false
}

pub fn is_sorted_unsorted_test() {
  my_solutions.is_sorted([1, 3, 2])
  |> should.be_false
}

pub fn is_sorted_equal_elements_test() {
  my_solutions.is_sorted([3, 3, 3])
  |> should.be_true
}

pub fn is_sorted_two_elements_sorted_test() {
  my_solutions.is_sorted([1, 2])
  |> should.be_true
}

pub fn is_sorted_two_elements_unsorted_test() {
  my_solutions.is_sorted([2, 1])
  |> should.be_false
}

pub fn is_sorted_negative_test() {
  my_solutions.is_sorted([-5, -3, -1, 0, 2])
  |> should.be_true
}

// ============================================================
// Упражнение 2: encode_ints / decode_ints (unit + roundtrip)
// ============================================================

pub fn encode_decode_roundtrip_test() {
  let original = [1, 2, 3, 4, 5]
  original
  |> my_solutions.encode_ints
  |> my_solutions.decode_ints
  |> should.equal(Ok(original))
}

pub fn encode_decode_empty_test() {
  []
  |> my_solutions.encode_ints
  |> my_solutions.decode_ints
  |> should.equal(Ok([]))
}

pub fn decode_invalid_json_test() {
  my_solutions.decode_ints("not json")
  |> should.be_error
}

pub fn decode_wrong_type_test() {
  my_solutions.decode_ints("[\"a\", \"b\"]")
  |> should.be_error
}

pub fn encode_decode_negative_test() {
  let original = [-10, -5, 0, 5, 10]
  original
  |> my_solutions.encode_ints
  |> my_solutions.decode_ints
  |> should.equal(Ok(original))
}

// PBT: roundtrip для произвольных списков
pub fn encode_decode_roundtrip_pbt_test() {
  use xs <- qcheck.given(qcheck.list_from(qcheck.uniform_int()))
  xs
  |> my_solutions.encode_ints
  |> my_solutions.decode_ints
  |> should.equal(Ok(xs))
}

// ============================================================
// Упражнение 3: my_sort (PBT)
// ============================================================

// Unit-тесты
pub fn my_sort_empty_test() {
  my_solutions.my_sort([])
  |> should.equal([])
}

pub fn my_sort_single_test() {
  my_solutions.my_sort([42])
  |> should.equal([42])
}

pub fn my_sort_already_sorted_test() {
  my_solutions.my_sort([1, 2, 3])
  |> should.equal([1, 2, 3])
}

pub fn my_sort_reverse_test() {
  my_solutions.my_sort([3, 2, 1])
  |> should.equal([1, 2, 3])
}

pub fn my_sort_duplicates_test() {
  my_solutions.my_sort([3, 1, 3, 1, 2])
  |> should.equal([1, 1, 2, 3, 3])
}

// PBT: результат отсортирован
pub fn my_sort_is_sorted_pbt_test() {
  use xs <- qcheck.given(qcheck.list_from(qcheck.uniform_int()))
  my_solutions.my_sort(xs)
  |> my_solutions.is_sorted
  |> should.be_true
}

// PBT: длина сохраняется
pub fn my_sort_preserves_length_pbt_test() {
  use xs <- qcheck.given(qcheck.list_from(qcheck.uniform_int()))
  list.length(my_solutions.my_sort(xs))
  |> should.equal(list.length(xs))
}

// PBT: идемпотентность
pub fn my_sort_idempotent_pbt_test() {
  use xs <- qcheck.given(qcheck.list_from(qcheck.uniform_int()))
  let sorted = my_solutions.my_sort(xs)
  my_solutions.my_sort(sorted)
  |> should.equal(sorted)
}

// PBT: сохранение элементов (те же элементы, что на входе)
pub fn my_sort_preserves_elements_pbt_test() {
  use xs <- qcheck.given(qcheck.list_from(qcheck.uniform_int()))
  let sorted = my_solutions.my_sort(xs)
  list.sort(sorted, int.compare)
  |> should.equal(list.sort(xs, int.compare))
}

// ============================================================
// Упражнение 4: int_in_range (PBT генератор)
// ============================================================

pub fn int_in_range_lower_bound_pbt_test() {
  let lo = 10
  let hi = 100
  use n <- qcheck.given(my_solutions.int_in_range(lo, hi))
  { n >= lo }
  |> should.be_true
}

pub fn int_in_range_upper_bound_pbt_test() {
  let lo = -50
  let hi = 50
  use n <- qcheck.given(my_solutions.int_in_range(lo, hi))
  { n <= hi }
  |> should.be_true
}

pub fn int_in_range_single_value_pbt_test() {
  use n <- qcheck.given(my_solutions.int_in_range(42, 42))
  n
  |> should.equal(42)
}

pub fn int_in_range_negative_pbt_test() {
  let lo = -100
  let hi = -10
  use n <- qcheck.given(my_solutions.int_in_range(lo, hi))
  { n >= lo && n <= hi }
  |> should.be_true
}

// ============================================================
// Упражнение 5: clamp (unit + PBT)
// ============================================================

// Unit-тесты
pub fn clamp_in_range_test() {
  my_solutions.clamp(5, 1, 10)
  |> should.equal(5)
}

pub fn clamp_below_test() {
  my_solutions.clamp(-3, 0, 100)
  |> should.equal(0)
}

pub fn clamp_above_test() {
  my_solutions.clamp(999, 0, 100)
  |> should.equal(100)
}

pub fn clamp_at_lower_boundary_test() {
  my_solutions.clamp(0, 0, 100)
  |> should.equal(0)
}

pub fn clamp_at_upper_boundary_test() {
  my_solutions.clamp(100, 0, 100)
  |> should.equal(100)
}

pub fn clamp_negative_range_test() {
  my_solutions.clamp(-50, -100, -10)
  |> should.equal(-50)
}

// PBT: результат всегда >= lo
pub fn clamp_lower_bound_pbt_test() {
  use n <- qcheck.given(qcheck.uniform_int())
  let lo = 0
  let hi = 100
  { my_solutions.clamp(n, lo, hi) >= lo }
  |> should.be_true
}

// PBT: результат всегда <= hi
pub fn clamp_upper_bound_pbt_test() {
  use n <- qcheck.given(qcheck.uniform_int())
  let lo = 0
  let hi = 100
  { my_solutions.clamp(n, lo, hi) <= hi }
  |> should.be_true
}

// PBT: идемпотентность
pub fn clamp_idempotent_pbt_test() {
  use n <- qcheck.given(qcheck.uniform_int())
  let lo = -50
  let hi = 50
  let once = my_solutions.clamp(n, lo, hi)
  let twice = my_solutions.clamp(once, lo, hi)
  once
  |> should.equal(twice)
}

// PBT: если значение в диапазоне — не меняется
pub fn clamp_identity_in_range_pbt_test() {
  use n <- qcheck.given(
    qcheck.map(qcheck.uniform_int(), fn(n) { int.absolute_value(n) % 101 }),
  )
  my_solutions.clamp(n, 0, 100)
  |> should.equal(n)
}
