import gleam/int
import gleam/float
import gleam/io

/// Пример: вывод в консоль
pub fn greet(name: String) -> Nil {
  io.println("Привет, " <> name <> "!")
}

/// Пример: базовая арифметика
pub fn circle_area(radius: Float) -> Float {
  let pi = 3.14159265358979
  pi *. radius *. radius
}

/// Пример: конвертация типов
pub fn int_to_float_example(n: Int) -> Float {
  int.to_float(n)
}
