//// Референсные решения — не подсматривайте, пока не попробуете сами!
//// Тема: JavaScript FFI — интеграция с браузерными API и JavaScript-функциями.

import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise.{type Promise}

// ============================================================
// Упражнение 1: current_timestamp — Date.now()
// ============================================================

@external(javascript, "./solutions_ffi.mjs", "getCurrentTimestamp")
pub fn current_timestamp() -> Int

// ============================================================
// Упражнение 2: local_storage — get/set/remove
// ============================================================

@external(javascript, "./solutions_ffi.mjs", "storageGet")
pub fn storage_get(key: String) -> Result(String, Nil)

@external(javascript, "./solutions_ffi.mjs", "storageSet")
pub fn storage_set(key: String, value: String) -> Result(Nil, String)

@external(javascript, "./solutions_ffi.mjs", "storageRemove")
pub fn storage_remove(key: String) -> Nil

// ============================================================
// Упражнение 3: console_log_levels — разные уровни логов
// ============================================================

@external(javascript, "./solutions_ffi.mjs", "consoleLog")
pub fn console_log(message: String) -> Nil

@external(javascript, "./solutions_ffi.mjs", "consoleWarn")
pub fn console_warn(message: String) -> Nil

@external(javascript, "./solutions_ffi.mjs", "consoleError")
pub fn console_error(message: String) -> Nil

// ============================================================
// Упражнение 4: timeout — setTimeout wrapper
// ============================================================

pub type TimeoutId

@external(javascript, "./solutions_ffi.mjs", "setTimeoutWrapper")
pub fn set_timeout(callback: fn() -> Nil, delay: Int) -> TimeoutId

@external(javascript, "./solutions_ffi.mjs", "clearTimeoutWrapper")
pub fn clear_timeout(id: TimeoutId) -> Nil

// ============================================================
// Упражнение 5: fetch_json — HTTP запрос с парсингом
// ============================================================

@external(javascript, "./solutions_ffi.mjs", "fetchJson")
pub fn fetch_json(url: String) -> Promise(Result(String, String))

// ============================================================
// Упражнение 6: query_selector — типобезопасный поиск элементов
// ============================================================

pub type Element

@external(javascript, "./solutions_ffi.mjs", "querySelectorWrapper")
pub fn query_selector(selector: String) -> Result(Element, Nil)

@external(javascript, "./solutions_ffi.mjs", "querySelectorAllWrapper")
pub fn query_selector_all(selector: String) -> List(Element)

// ============================================================
// Упражнение 7: json_parse_safe — безопасный JSON.parse
// ============================================================

@external(javascript, "./solutions_ffi.mjs", "jsonParseSafe")
pub fn json_parse_safe(json_str: String) -> Result(Dynamic, String)

// ============================================================
// Упражнение 8: event_target_value — получение значения из event.target
// ============================================================

pub type Event

@external(javascript, "./solutions_ffi.mjs", "eventTargetValue")
pub fn event_target_value(event: Event) -> Result(String, Nil)
