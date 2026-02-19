import gleam/int
import gleam/list
import gleam/option.{type Option}

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

// ── Builder-паттерн ──────────────────────────────────────────────────────────
//
// Builder — один из самых распространённых паттернов в Gleam-экосистеме.
// Причина его популярности: в Gleam нет default-аргументов и перегрузки
// функций, поэтому builder — стандартный способ создавать сложные объекты
// с опциональными параметрами.
//
// Примеры из реальных библиотек:
//   pog.default_config() |> pog.host("db") |> pog.port(5432) |> pog.connect
//   telega.new_for_polling(token) |> telega.with_router(r) |> telega.init...
//   mist.new(handler) |> mist.port(8080) |> mist.start
//
// Ключевые свойства:
//   1. Начинается с `new_*()` или `default_*()` — создаёт builder с дефолтами
//   2. Каждый `with_*` / `add_*` возвращает НОВЫЙ builder (иммутабельно)
//   3. Заканчивается `build` / `start` / `connect` — создаёт финальный объект
//   4. Дружит с pipe operator `|>` — код читается как список инструкций

/// Builder для пошагового конструирования директории.
///
/// ```gleam
/// new_dir("src")
/// |> add_file("main.gleam", 2048)
/// |> add_file("utils.gleam", 512)
/// |> build
/// // → Directory("src", [File("main.gleam", 2048), File("utils.gleam", 512)])
/// ```
pub type DirBuilder {
  DirBuilder(name: String, children: List(FSNode))
}

/// Создаёт пустой builder с именем директории.
pub fn new_dir(name: String) -> DirBuilder {
  DirBuilder(name: name, children: [])
}

/// Добавляет файл в конструируемую директорию.
/// Каждый вызов возвращает новый builder с добавленным файлом.
pub fn add_file(b: DirBuilder, name: String, size: Int) -> DirBuilder {
  DirBuilder(..b, children: list.append(b.children, [File(name, size)]))
}

/// Вставляет готовую поддиректорию (FSNode).
/// Параметр `sub` — результат `build` другого DirBuilder.
pub fn add_subdir(b: DirBuilder, sub: FSNode) -> DirBuilder {
  DirBuilder(..b, children: list.append(b.children, [sub]))
}

/// «Собирает» builder в финальный FSNode.Directory.
pub fn build(b: DirBuilder) -> FSNode {
  Directory(b.name, b.children)
}

/// Пример использования: построить дерево с вложенными директориями.
///
/// Сравните с прямым конструированием:
///   Directory("project", [File("README.md", 1024), Directory("src", [...])])
/// — при большом числе файлов это нечитаемо; builder решает эту проблему.
pub fn example_tree() -> FSNode {
  let src =
    new_dir("src")
    |> add_file("main.gleam", 2048)
    |> add_file("utils.gleam", 512)
    |> build

  let tests =
    new_dir("test")
    |> add_file("main_test.gleam", 1536)
    |> build

  new_dir("project")
  |> add_file("README.md", 1024)
  |> add_subdir(src)
  |> add_subdir(tests)
  |> build
}

// ── FsQuery builder — для упражнения 7 ──────────────────────────────────────
//
// FsQuery — builder другого рода: он конфигурирует запрос к файловой системе.
// Это «конфигурирующий» builder (в отличие от «конструирующего» DirBuilder):
// вместо построения структуры данных он собирает набор фильтров.
//
// Студенты реализуют его в my_solutions.gleam.

/// Запрос для поиска файлов по критериям.
pub type FsQuery {
  FsQuery(
    extension: Option(String),
    min_size: Option(Int),
    max_size: Option(Int),
  )
}
