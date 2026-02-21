//// Здесь вы можете писать свои решения упражнений.
//// Тема: JavaScript FFI — интеграция с браузерными API и JavaScript-функциями.

import gleam/dynamic.{type Dynamic}
import gleam/javascript/promise.{type Promise}

// ============================================================
// Упражнение 1: current_timestamp — Date.now()
// ============================================================

/// Возвращает текущее время в миллисекундах через FFI к Date.now().
///
/// Подсказка: создайте функцию в my_ffi.mjs, которая вызывает Date.now(),
/// и подключите её через @external(javascript, "./my_ffi.mjs", "functionName")
pub fn current_timestamp() -> Int {
  todo
}

// ============================================================
// Упражнение 2: local_storage — get/set/remove
// ============================================================

/// Получает значение из localStorage по ключу.
/// Возвращает Error(Nil) если ключ не найден.
///
/// Подсказка: localStorage.getItem(key) возвращает null если ключа нет.
/// Преобразуйте null в {type: "Error", 0: undefined}, а значение в {type: "Ok", 0: value}
pub fn storage_get(key: String) -> Result(String, Nil) {
  todo
}

/// Сохраняет значение в localStorage.
/// Возвращает Error с сообщением об ошибке в случае неудачи.
///
/// Подсказка: оберните localStorage.setItem в try/catch
pub fn storage_set(key: String, value: String) -> Result(Nil, String) {
  todo
}

/// Удаляет значение из localStorage.
///
/// Подсказка: используйте localStorage.removeItem(key)
pub fn storage_remove(key: String) -> Nil {
  todo
}

// ============================================================
// Упражнение 3: console_log_levels — разные уровни логов
// ============================================================

/// Выводит сообщение в консоль (уровень log).
pub fn console_log(message: String) -> Nil {
  todo
}

/// Выводит предупреждение в консоль (уровень warn).
pub fn console_warn(message: String) -> Nil {
  todo
}

/// Выводит ошибку в консоль (уровень error).
pub fn console_error(message: String) -> Nil {
  todo
}

// ============================================================
// Упражнение 4: timeout — setTimeout wrapper
// ============================================================

/// Непрозрачный тип для ID таймера.
pub type TimeoutId

/// Создаёт таймер, который вызовет callback через delay миллисекунд.
/// Возвращает TimeoutId, который можно передать в clear_timeout.
///
/// Подсказка: setTimeout возвращает число (ID), используйте его как TimeoutId
pub fn set_timeout(callback: fn() -> Nil, delay: Int) -> TimeoutId {
  todo
}

/// Отменяет таймер по ID.
pub fn clear_timeout(id: TimeoutId) -> Nil {
  todo
}

// ============================================================
// Упражнение 5: fetch_json — HTTP запрос с парсингом
// ============================================================

/// Выполняет HTTP GET-запрос и возвращает промис с результатом.
///
/// Подсказка:
/// - Используйте fetch(url).then(r => r.text())
/// - Оберните результат в {type: "Ok", 0: text}
/// - Ошибки оборачивайте в {type: "Error", 0: error.message}
pub fn fetch_json(url: String) -> Promise(Result(String, String)) {
  todo
}

// ============================================================
// Упражнение 6: query_selector — типобезопасный поиск элементов
// ============================================================

/// Непрозрачный тип для DOM-элемента.
pub type Element

/// Ищет первый элемент по CSS-селектору.
/// Возвращает Error(Nil) если элемент не найден.
///
/// Подсказка: document.querySelector возвращает null если не найдено
pub fn query_selector(selector: String) -> Result(Element, Nil) {
  todo
}

/// Ищет все элементы по CSS-селектору.
/// Возвращает список элементов (может быть пустым).
///
/// Подсказка:
/// - document.querySelectorAll возвращает NodeList
/// - Преобразуйте его в массив: Array.from(nodeList)
pub fn query_selector_all(selector: String) -> List(Element) {
  todo
}

// ============================================================
// Упражнение 7: json_parse_safe — безопасный JSON.parse
// ============================================================

/// Парсит JSON-строку в Dynamic, возвращая ошибку вместо исключения.
///
/// Подсказка:
/// - Оберните JSON.parse(jsonStr) в try/catch
/// - В случае успеха верните {type: "Ok", 0: parsed}
/// - В случае ошибки верните {type: "Error", 0: error.message}
pub fn json_parse_safe(json_str: String) -> Result(Dynamic, String) {
  todo
}

// ============================================================
// Упражнение 8: event_target_value — получение значения из event.target
// ============================================================

/// Непрозрачный тип для события.
pub type Event

/// Извлекает значение из event.target.value (для input-элементов).
/// Возвращает Error(Nil) если значение недоступно.
///
/// Подсказка:
/// - Проверьте event?.target?.value (optional chaining)
/// - Если undefined или null, верните {type: "Error", 0: undefined}
/// - Иначе верните {type: "Ok", 0: String(value)}
pub fn event_target_value(event: Event) -> Result(String, Nil) {
  todo
}

// ============================================================
// Упражнение 9: varargs_logger — console.log с разными типами
// ============================================================

/// Логирует множество значений разных типов в консоль.
///
/// Подсказка:
/// - Создайте JavaScript функцию, принимающую массив
/// - Используйте spread operator: console.log(...values)
pub fn log_values(values: List(Dynamic)) -> Nil {
  todo
}

// ============================================================
// Упражнение 10: math_operations — varargs для математики
// ============================================================

/// Суммирует все числа в списке.
///
/// Подсказка:
/// export function sumAll(numbers) {
///   return numbers.reduce((a, b) => a + b, 0);
/// }
pub fn sum_all(numbers: List(Float)) -> Float {
  todo
}

/// Перемножает все числа в списке.
///
/// Подсказка: аналогично sum_all, но с умножением
pub fn multiply_all(numbers: List(Float)) -> Float {
  todo
}

// ============================================================
// Упражнение 11: js_date_wrapper — работа с Date классом
// ============================================================

/// Непрозрачный тип для JavaScript Date.
pub type JSDate

/// Создаёт новую дату (текущее время).
///
/// Подсказка: export function newDate() { return new Date(); }
pub fn new_date() -> JSDate {
  todo
}

/// Создаёт дату из ISO-строки.
/// Возвращает Error(Nil) если строка невалидна.
///
/// Подсказка:
/// - const d = new Date(isoString);
/// - Проверьте isNaN(d.getTime()) для валидности
pub fn date_from_string(iso: String) -> Result(JSDate, Nil) {
  todo
}

/// Добавляет дни к дате.
///
/// Подсказка:
/// const newDate = new Date(date);
/// newDate.setDate(newDate.getDate() + days);
/// return newDate;
pub fn add_days(date: JSDate, days: Int) -> JSDate {
  todo
}

/// Форматирует дату в строку.
///
/// Подсказка: используйте date.toLocaleDateString() или toISOString()
pub fn format_date(date: JSDate, format: String) -> String {
  todo
}

// ============================================================
// Упражнение 12: canvas_wrapper — обёртка для Canvas API
// ============================================================

/// Непрозрачный тип для Canvas контекста.
pub type Canvas

/// Получает Canvas контекст по ID элемента.
/// Возвращает Error(Nil) если элемент не найден.
///
/// Подсказка:
/// const elem = document.getElementById(elementId);
/// if (!elem) return {type: "Error", 0: undefined};
/// const ctx = elem.getContext('2d');
/// if (!ctx) return {type: "Error", 0: undefined};
/// return {type: "Ok", 0: ctx};
pub fn get_canvas(element_id: String) -> Result(Canvas, Nil) {
  todo
}

/// Рисует закрашенный прямоугольник.
///
/// Подсказка:
/// canvas.fillStyle = color;
/// canvas.fillRect(x, y, w, h);
/// return canvas;
pub fn fill_rect(
  canvas: Canvas,
  x: Float,
  y: Float,
  w: Float,
  h: Float,
  color: String,
) -> Canvas {
  todo
}

/// Очищает весь canvas.
///
/// Подсказка:
/// canvas.clearRect(0, 0, canvas.canvas.width, canvas.canvas.height);
/// return canvas;
pub fn clear_canvas(canvas: Canvas) -> Canvas {
  todo
}
