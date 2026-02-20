import gleam/erlang/atom
import gleam/erlang/process
import gleam/string
import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================
// Упражнение 1: system_time_seconds — FFI к erlang:system_time
// ============================================================

pub fn system_time_seconds_is_positive_test() {
  let time = my_solutions.system_time_seconds()
  { time > 0 }
  |> should.be_true
}

pub fn system_time_seconds_is_recent_test() {
  let time = my_solutions.system_time_seconds()
  // Время должно быть больше 2024-01-01 в секундах
  { time > 1_704_067_200 }
  |> should.be_true
}

pub fn system_time_seconds_increases_test() {
  let time1 = my_solutions.system_time_seconds()
  let time2 = my_solutions.system_time_seconds()
  // Время должно увеличиваться (или остаться тем же, если вызовы быстрые)
  { time2 >= time1 }
  |> should.be_true
}

// ============================================================
// Упражнение 2: get_api_base_url — переменные окружения
// ============================================================

pub fn get_api_base_url_default_test() {
  // Если POKEAPI_BASE_URL не установлена, возвращает дефолт
  let url = my_solutions.get_api_base_url()
  { string.contains(url, "pokeapi") || string.contains(url, "pokemon") }
  |> should.be_true
}

pub fn get_api_base_url_returns_string_test() {
  let url = my_solutions.get_api_base_url()
  { string.length(url) > 0 }
  |> should.be_true
}

// ============================================================
// Упражнение 3: file_exists — проверка существования файла
// ============================================================

pub fn file_exists_gleam_toml_test() {
  my_solutions.file_exists("gleam.toml")
  |> should.be_true
}

pub fn file_exists_manifest_test() {
  my_solutions.file_exists("manifest.toml")
  |> should.be_true
}

pub fn file_exists_nonexistent_test() {
  my_solutions.file_exists("nonexistent_file_12345.txt")
  |> should.be_false
}

pub fn file_exists_directory_test() {
  my_solutions.file_exists("src")
  |> should.be_true
}

// ============================================================
// Упражнение 4: read_lines — чтение файла построчно
// ============================================================

pub fn read_lines_gleam_toml_test() {
  let assert Ok(lines) = my_solutions.read_lines("gleam.toml")
  { lines != [] }
  |> should.be_true
  // Первая строка должна содержать "name"
  let assert [first, ..] = lines
  { string.contains(first, "name") || string.contains(first, "chapter08") }
  |> should.be_true
}

pub fn read_lines_nonexistent_test() {
  my_solutions.read_lines("nonexistent_file_12345.txt")
  |> should.be_error
}

pub fn read_lines_preserves_content_test() {
  let assert Ok(lines) = my_solutions.read_lines("gleam.toml")
  // Должно быть несколько строк
  { lines != [] }
  |> should.be_true
}

// ============================================================
// Упражнение 5: LogLevel — безопасная работа с атомами
// ============================================================

pub fn log_level_to_atom_debug_test() {
  my_solutions.log_level_to_atom(my_solutions.Debug)
  |> atom.to_string
  |> should.equal("debug")
}

pub fn log_level_to_atom_info_test() {
  my_solutions.log_level_to_atom(my_solutions.Info)
  |> atom.to_string
  |> should.equal("info")
}

pub fn log_level_to_atom_warning_test() {
  my_solutions.log_level_to_atom(my_solutions.Warning)
  |> atom.to_string
  |> should.equal("warning")
}

pub fn log_level_to_atom_error_test() {
  my_solutions.log_level_to_atom(my_solutions.LogError)
  |> atom.to_string
  |> should.equal("error")
}

pub fn log_level_from_atom_debug_test() {
  let a = atom.create("debug")
  my_solutions.log_level_from_atom(a)
  |> should.equal(Ok(my_solutions.Debug))
}

pub fn log_level_from_atom_info_test() {
  let a = atom.create("info")
  my_solutions.log_level_from_atom(a)
  |> should.equal(Ok(my_solutions.Info))
}

pub fn log_level_from_atom_warning_test() {
  let a = atom.create("warning")
  my_solutions.log_level_from_atom(a)
  |> should.equal(Ok(my_solutions.Warning))
}

pub fn log_level_from_atom_error_test() {
  let a = atom.create("error")
  my_solutions.log_level_from_atom(a)
  |> should.equal(Ok(my_solutions.LogError))
}

pub fn log_level_from_atom_invalid_test() {
  let a = atom.create("invalid")
  my_solutions.log_level_from_atom(a)
  |> should.be_error
}

pub fn log_level_roundtrip_test() {
  let a = atom.create("info")
  let assert Ok(level) = my_solutions.log_level_from_atom(a)
  my_solutions.log_level_to_atom(level)
  |> should.equal(a)
}

// ============================================================
// Упражнение 6: pid_to_string — работа с процессами
// ============================================================

pub fn pid_to_string_self_test() {
  let pid = process.self()
  let result = my_solutions.pid_to_string(pid)
  { string.starts_with(result, "<") }
  |> should.be_true
  { string.ends_with(result, ">") }
  |> should.be_true
}

pub fn pid_to_string_format_test() {
  let pid = process.self()
  let result = my_solutions.pid_to_string(pid)
  // PID должен содержать точки (например, <0.123.0>)
  { string.contains(result, ".") }
  |> should.be_true
}

pub fn pid_to_string_not_empty_test() {
  let pid = process.self()
  let result = my_solutions.pid_to_string(pid)
  { string.length(result) > 0 }
  |> should.be_true
}

// ============================================================
// Упражнение 7: measure_time — измерение времени выполнения
// ============================================================

pub fn measure_time_fast_function_test() {
  let #(result, time) = my_solutions.measure_time(fn() { 42 })
  result |> should.equal(42)
  // Время должно быть неотрицательным
  { time >= 0 }
  |> should.be_true
}

pub fn measure_time_returns_result_test() {
  let #(result, _time) = my_solutions.measure_time(fn() { "hello" })
  result |> should.equal("hello")
}

pub fn measure_time_measures_time_test() {
  let #(_result, time) =
    my_solutions.measure_time(fn() {
      // Имитируем работу (список очень длинный)
      let _ =
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        |> list.map(fn(x) { x * x })
        |> list.fold(0, fn(acc, x) { acc + x })
      Nil
    })
  // Время должно быть больше 0 (хотя может быть очень маленьким)
  { time >= 0 }
  |> should.be_true
}

pub fn measure_time_different_calls_test() {
  let #(_result1, time1) = my_solutions.measure_time(fn() { Nil })
  let #(_result2, time2) = my_solutions.measure_time(fn() { Nil })
  // Оба вызова должны вернуть неотрицательное время
  { time1 >= 0 }
  |> should.be_true
  { time2 >= 0 }
  |> should.be_true
}

// ============================================================
// Упражнение 8: ensure_dir — создание директории
// ============================================================

pub fn ensure_dir_creates_directory_test() {
  let test_dir = "test_output/chapter08/new_dir"
  let result = my_solutions.ensure_dir(test_dir)
  result |> should.be_ok

  // Проверяем, что директория создана
  my_solutions.file_exists(test_dir)
  |> should.be_true
}

pub fn ensure_dir_nested_directory_test() {
  let test_dir = "test_output/chapter08/nested/deep/dir"
  let result = my_solutions.ensure_dir(test_dir)
  result |> should.be_ok

  // Проверяем, что директория создана
  my_solutions.file_exists(test_dir)
  |> should.be_true
}

pub fn ensure_dir_already_exists_test() {
  let test_dir = "test_output/chapter08/existing"
  // Создаём первый раз
  let assert Ok(_) = my_solutions.ensure_dir(test_dir)
  // Создаём второй раз (должно быть OK)
  let result = my_solutions.ensure_dir(test_dir)
  result |> should.be_ok
}

pub fn ensure_dir_single_level_test() {
  let test_dir = "test_output/chapter08_single"
  let result = my_solutions.ensure_dir(test_dir)
  result |> should.be_ok

  my_solutions.file_exists(test_dir)
  |> should.be_true
}

// Импортируем list для теста measure_time
import gleam/list
