//// Здесь вы можете писать свои решения упражнений.

import gleam/json

/// Тип Todo.
pub type Todo {
  Todo(title: String, completed: Bool)
}

/// Возвращает тело JSON-ответа для health check.
pub fn health_check_body() -> String {
  todo
}

/// Парсит JSON-строку в Todo.
pub fn parse_todo(s: String) -> Result(Todo, Nil) {
  todo
}

/// Сериализует Todo в JSON-строку.
pub fn todo_to_json_string(t: Todo) -> String {
  todo
}
