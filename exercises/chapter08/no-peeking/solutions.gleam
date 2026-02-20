//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/bit_array
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/string

// ============================================================
// Упражнение 1: system_time_seconds — FFI к erlang:system_time
// ============================================================

type ErlAtom

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(s: String) -> ErlAtom

@external(erlang, "erlang", "system_time")
fn erl_system_time(unit: ErlAtom) -> Int

pub fn system_time_seconds() -> Int {
  erl_system_time(binary_to_atom("second"))
}

// ============================================================
// Упражнение 2: get_api_base_url — переменные окружения
// ============================================================

@external(erlang, "chapter08_ffi", "get_env")
fn ffi_get_env(name: String) -> Result(String, Nil)

pub fn get_api_base_url() -> String {
  case ffi_get_env("POKEAPI_BASE_URL") {
    Ok(value) -> value
    Error(_) -> "https://pokeapi.co"
  }
}

// ============================================================
// Упражнение 3: file_exists — проверка существования файла
// ============================================================

@external(erlang, "filelib", "is_file")
fn erl_is_file(path: charlist.Charlist) -> Bool

pub fn file_exists(path: String) -> Bool {
  charlist.from_string(path)
  |> erl_is_file
}

// ============================================================
// Упражнение 4: read_lines — чтение файла построчно
// ============================================================

@external(erlang, "file", "read_file")
fn erl_read_file(path: charlist.Charlist) -> Result(BitArray, atom.Atom)

pub fn read_lines(path: String) -> Result(List(String), String) {
  let charlist_path = charlist.from_string(path)

  case erl_read_file(charlist_path) {
    Ok(contents) -> {
      case bit_array.to_string(contents) {
        Ok(str) -> Ok(string.split(str, "\n"))
        Error(_) -> Error("failed to decode file as UTF-8")
      }
    }
    Error(reason) -> Error("failed to read: " <> atom.to_string(reason))
  }
}

// ============================================================
// Упражнение 5: LogLevel — безопасная работа с атомами
// ============================================================

pub type LogLevel {
  Debug
  Info
  Warning
  LogError
}

pub fn log_level_to_atom(level: LogLevel) -> atom.Atom {
  case level {
    Debug -> atom.create("debug")
    Info -> atom.create("info")
    Warning -> atom.create("warning")
    LogError -> atom.create("error")
  }
}

pub fn log_level_from_atom(a: atom.Atom) -> Result(LogLevel, Nil) {
  case atom.to_string(a) {
    "debug" -> Ok(Debug)
    "info" -> Ok(Info)
    "warning" -> Ok(Warning)
    "error" -> Ok(LogError)
    _ -> Error(Nil)
  }
}

// ============================================================
// Упражнение 6: pid_to_string — работа с процессами
// ============================================================

@external(erlang, "erlang", "pid_to_list")
fn pid_to_charlist(pid: process.Pid) -> charlist.Charlist

pub fn pid_to_string(pid: process.Pid) -> String {
  pid_to_charlist(pid)
  |> charlist.to_string
}

// ============================================================
// Упражнение 7: measure_time — измерение времени выполнения
// ============================================================

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: ErlAtom) -> Int

pub fn measure_time(f: fn() -> a) -> #(a, Int) {
  let start = monotonic_time(binary_to_atom("microsecond"))
  let result = f()
  let end = monotonic_time(binary_to_atom("microsecond"))
  #(result, end - start)
}

// ============================================================
// Упражнение 8: ensure_dir — создание директории
// ============================================================

@external(erlang, "chapter08_ffi", "ensure_dir")
fn erl_ensure_dir(path: charlist.Charlist) -> Result(Nil, atom.Atom)

pub fn ensure_dir(path: String) -> Result(Nil, String) {
  // filelib:ensure_dir требует путь к файлу, поэтому добавляем "/"
  let file_path = path <> "/"
  let charlist_path = charlist.from_string(file_path)

  case erl_ensure_dir(charlist_path) {
    Ok(_) -> Ok(Nil)
    Error(reason) ->
      Error("failed to create directory: " <> atom.to_string(reason))
  }
}
