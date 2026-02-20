//// Здесь вы можете писать свои решения упражнений.
////
//// В этой главе мы создаем HTML builder (билдер-паттерн):
//// - Element — тип для HTML элементов
//// - Attribute — тип для атрибутов
//// - Конструкторы: div, p, a, ul, ol, li, table, etc.
//// - Атрибуты: class, id, href, alt, etc.
//// - to_string — рендеринг в HTML строку

// ============================================================
// Типы для HTML билдера
// ============================================================

/// HTML элемент
pub opaque type Element {
  Element(tag: String, attrs: List(Attribute), children: List(Element))
  Text(content: String)
}

/// HTML атрибут
pub type Attribute {
  Attribute(name: String, value: String)
}

// ============================================================
// Упражнение 1: Конструкторы элементов
// ============================================================

/// Создаёт произвольный HTML элемент
pub fn element(
  tag: String,
  attrs: List(Attribute),
  children: List(Element),
) -> Element {
  todo
}

/// Создаёт текстовый узел
pub fn text(content: String) -> Element {
  todo
}

// Реализуйте конструкторы для распространённых элементов:

pub fn div(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn p(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn a(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn ul(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn ol(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn li(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn table(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn thead(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn tbody(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn tr(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn th(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn td(attrs: List(Attribute), children: List(Element)) -> Element {
  todo
}

pub fn img(attrs: List(Attribute)) -> Element {
  todo
}

// ============================================================
// Упражнение 2: Конструкторы атрибутов
// ============================================================

pub fn attr(name: String, value: String) -> Attribute {
  todo
}

pub fn class(value: String) -> Attribute {
  todo
}

pub fn id(value: String) -> Attribute {
  todo
}

pub fn href(value: String) -> Attribute {
  todo
}

pub fn alt(value: String) -> Attribute {
  todo
}

// ============================================================
// Упражнение 3: Рендеринг
// ============================================================

/// Конвертирует Element в HTML строку
/// Подсказка: используйте рекурсию для обработки children
pub fn to_string(element: Element) -> String {
  todo
}

/// Экранирует HTML-спецсимволы: &, <, >, ", '
/// Порядок важен! Начните с &
pub fn escape_html(content: String) -> String {
  todo
}

// ============================================================
// Упражнение 4: Удобные функции-обёртки
// ============================================================

/// Упрощённая функция для создания HTML-тега.
/// Принимает простые типы, а под капотом использует HTML builder API
pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String {
  todo
}

/// Строит HTML-список (<ul> или <ol>) из элементов.
/// Реализуйте через HTML builder API
pub fn build_list(items: List(String), ordered: Bool) -> String {
  todo
}

/// Находит URL в тексте и оборачивает их в <a> теги.
/// Подсказка: используйте gleam/regexp
pub fn linkify(text: String) -> String {
  todo
}

/// Строит HTML-таблицу из заголовков и строк данных.
/// Реализуйте через HTML builder API
pub fn build_table(headers: List(String), rows: List(List(String))) -> String {
  todo
}

// ============================================================
// Примеры использования (для вдохновения)
// ============================================================

// Простой пример:
// let page =
//   div([class("container")], [
//     p([], [text("Hello, world!")]),
//     a([href("https://gleam.run")], [text("Visit Gleam")])
//   ])
//   |> to_string
//
// Результат:
// "<div class=\"container\"><p>Hello, world!</p><a href=\"https://gleam.run\">Visit Gleam</a></div>"

// Список через HTML builder:
// let items_list =
//   ul([], [
//     li([], [text("First")]),
//     li([], [text("Second")]),
//     li([], [text("Third")])
//   ])
//   |> to_string
//
// Результат:
// "<ul><li>First</li><li>Second</li><li>Third</li></ul>"
