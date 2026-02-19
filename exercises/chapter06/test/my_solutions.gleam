//// Здесь вы можете писать свои решения упражнений.

/// Экранирует HTML-спецсимволы: &, <, >, ", '
pub fn escape_html(text: String) -> String {
  todo
}

/// Создаёт HTML-тег с именем, атрибутами и содержимым.
/// Значения атрибутов должны быть экранированы.
pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String {
  todo
}

/// Строит HTML-список (<ul> или <ol>) из элементов.
pub fn build_list(items: List(String), ordered: Bool) -> String {
  todo
}

/// Находит URL в тексте и оборачивает их в <a> теги.
pub fn linkify(text: String) -> String {
  todo
}

/// Строит HTML-таблицу из заголовков и строк данных.
pub fn build_table(
  headers: List(String),
  rows: List(List(String)),
) -> String {
  todo
}
