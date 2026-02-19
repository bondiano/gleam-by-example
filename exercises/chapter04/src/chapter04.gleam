import gleam/int
import gleam/list

/// Узел файловой системы — основной тип для упражнений главы.
pub type FSNode {
  File(name: String, size: Int)
  Directory(name: String, children: List(FSNode))
}

/// Пример: pattern matching на пользовательских типах
pub fn describe(node: FSNode) -> String {
  case node {
    File(name:, size:) ->
      name <> " (" <> int.to_string(size) <> " bytes)"
    Directory(name:, children:) ->
      name <> "/ (" <> int.to_string(list.length(children)) <> " items)"
  }
}
