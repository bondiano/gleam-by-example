//// Примеры кода из Главы 8: Erlang FFI и системное программирование

import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/erlang/process

// ============================================================
// Вспомогательные типы для примеров
// ============================================================

pub type Pid =
  process.Pid

// ============================================================
// Пример 1: External functions для Erlang
// ============================================================

/// Публичная обёртка для получения системного времени
@external(erlang, "os", "system_time")
pub fn os_system_time(unit: atom.Atom) -> Int

// ============================================================
// Пример 2: External types
// ============================================================

/// Reference — уникальный идентификатор в Erlang
pub type Reference

@external(erlang, "erlang", "make_ref")
pub fn make_reference() -> Reference

@external(erlang, "erlang", "ref_to_list")
fn reference_to_charlist(ref: Reference) -> charlist.Charlist

pub fn reference_to_string(ref: Reference) -> String {
  reference_to_charlist(ref)
  |> charlist.to_string
}

// ============================================================
// Пример 3: Работа с атомами
// ============================================================

/// Безопасный LogLevel тип
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
// Пример 4: Чтение файла через Erlang file API
// ============================================================

@external(erlang, "file", "read_file")
fn erl_read_file(path: charlist.Charlist) -> Result(BitArray, atom.Atom)

pub fn read_file(path: String) -> Result(BitArray, String) {
  let charlist_path = charlist.from_string(path)

  case erl_read_file(charlist_path) {
    Ok(contents) -> Ok(contents)
    Error(reason) -> Error("failed to read: " <> atom.to_string(reason))
  }
}

// ============================================================
// Пример 5: Работа с процессами
// ============================================================

@external(erlang, "erlang", "self")
pub fn self() -> process.Pid

@external(erlang, "erlang", "pid_to_list")
fn pid_to_charlist(pid: process.Pid) -> charlist.Charlist

pub fn pid_to_string_example(pid: process.Pid) -> String {
  pid_to_charlist(pid)
  |> charlist.to_string
}
