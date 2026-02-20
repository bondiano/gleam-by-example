//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import qcheck

// ============================================================
// Упражнение 1: is_sorted
// ============================================================

pub fn is_sorted(xs: List(Int)) -> Bool {
  case xs {
    [] | [_] -> True
    [a, b, ..rest] ->
      case a <= b {
        True -> is_sorted([b, ..rest])
        False -> False
      }
  }
}

// ============================================================
// Упражнение 2: encode_ints / decode_ints
// ============================================================

pub fn encode_ints(xs: List(Int)) -> String {
  xs
  |> json.array(json.int)
  |> json.to_string
}

pub fn decode_ints(s: String) -> Result(List(Int), Nil) {
  json.parse(s, decode.list(decode.int))
  |> result.map_error(fn(_) { Nil })
}

// ============================================================
// Упражнение 3: my_sort
// ============================================================

pub fn my_sort(xs: List(Int)) -> List(Int) {
  list.sort(xs, int.compare)
}

// ============================================================
// Упражнение 4: int_in_range
// ============================================================

pub fn int_in_range(lo: Int, hi: Int) -> qcheck.Generator(Int) {
  qcheck.int_uniform_inclusive(lo, hi)
}

// ============================================================
// Упражнение 5: clamp
// ============================================================

pub fn clamp(value: Int, lo: Int, hi: Int) -> Int {
  int.min(hi, int.max(lo, value))
}
