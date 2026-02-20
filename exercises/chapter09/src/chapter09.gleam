import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise.{type Promise}

// ============================================================
// Примеры FFI для JavaScript
// ============================================================

/// Пример: получение текущего времени в миллисекундах
@external(javascript, "./chapter09_ffi.mjs", "getCurrentTime")
pub fn get_current_time() -> Int

/// Пример: логирование в консоль
@external(javascript, "./chapter09_ffi.mjs", "consoleLog")
pub fn console_log(message: String) -> Nil

/// Пример: работа с localStorage
@external(javascript, "./chapter09_ffi.mjs", "localStorageGet")
pub fn local_storage_get(key: String) -> Result(String, Nil)

@external(javascript, "./chapter09_ffi.mjs", "localStorageSet")
pub fn local_storage_set(key: String, value: String) -> Result(Nil, String)

/// Пример: setTimeout
pub type TimeoutId

@external(javascript, "./chapter09_ffi.mjs", "setTimeout")
pub fn set_timeout(callback: fn() -> Nil, delay: Int) -> TimeoutId

@external(javascript, "./chapter09_ffi.mjs", "clearTimeout")
pub fn clear_timeout(id: TimeoutId) -> Nil

/// Пример: fetch API
@external(javascript, "./chapter09_ffi.mjs", "fetchText")
pub fn fetch_text(url: String) -> Promise(Result(String, String))

/// Пример: работа с DOM
pub type Element

@external(javascript, "./chapter09_ffi.mjs", "querySelector")
pub fn query_selector(selector: String) -> Result(Element, Nil)

@external(javascript, "./chapter09_ffi.mjs", "querySelectorAll")
pub fn query_selector_all(selector: String) -> List(Element)

@external(javascript, "./chapter09_ffi.mjs", "setInnerText")
pub fn set_inner_text(element: Element, text: String) -> Nil

@external(javascript, "./chapter09_ffi.mjs", "getInnerText")
pub fn get_inner_text(element: Element) -> String

/// Пример: события
pub type Event

@external(javascript, "./chapter09_ffi.mjs", "addEventListener")
pub fn add_event_listener(
  element: Element,
  event: String,
  handler: fn(Event) -> Nil,
) -> Nil

@external(javascript, "./chapter09_ffi.mjs", "eventTargetValue")
pub fn event_target_value(event: Event) -> Result(String, Nil)

/// Пример: JSON.parse с обработкой ошибок
@external(javascript, "./chapter09_ffi.mjs", "jsonParseSafe")
pub fn json_parse_safe(json_str: String) -> Result(Dynamic, String)

/// Пример: двойной FFI (работает и на Erlang, и на JavaScript)
/// На Erlang использует os:system_time/0, на JS — Date.now()
@external(erlang, "os", "system_time")
@external(javascript, "./chapter09_ffi.mjs", "systemTimeMillis")
pub fn system_time_millis() -> Int
