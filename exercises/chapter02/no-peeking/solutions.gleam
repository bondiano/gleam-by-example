//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/float
import gleam/int
import gleam/list

pub fn diagonal(a: Float, b: Float) -> Float {
  let assert Ok(result) = float.square_root(a *. a +. b *. b)
  result
}

pub fn celsius_to_fahrenheit(c: Float) -> Float {
  c *. 9.0 /. 5.0 +. 32.0
}

pub fn fahrenheit_to_celsius(f: Float) -> Float {
  { f -. 32.0 } *. 5.0 /. 9.0
}

pub fn euler1(n: Int) -> Int {
  list.range(1, n)
  |> list.filter(fn(x) { x % 3 == 0 || x % 5 == 0 })
  |> int.sum
}
