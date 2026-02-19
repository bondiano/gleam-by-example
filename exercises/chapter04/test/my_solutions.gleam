//// Здесь вы можете писать свои решения упражнений.
//// Все упражнения работают с типом FSNode из chapter04.

import chapter04.{type FsQuery, type FSNode}

/// Вычисляет общий размер узла файловой системы (рекурсивно).
/// Для файла — его размер, для директории — сумма размеров всех вложенных узлов.
pub fn total_size(node: FSNode) -> Int {
  todo
}

/// Собирает имена всех файлов в дереве в плоский список (в порядке обхода).
pub fn all_files(node: FSNode) -> List(String) {
  todo
}

/// Находит все файлы с заданным расширением.
/// Возвращает список имён файлов, оканчивающихся на ext.
pub fn find_by_extension(node: FSNode, ext: String) -> List(String) {
  todo
}

/// Находит самый большой файл в дереве.
/// Возвращает пару #(имя, размер) или Error(Nil), если файлов нет.
pub fn largest_file(node: FSNode) -> Result(#(String, Int), Nil) {
  todo
}

/// Подсчитывает количество файлов по расширениям.
/// Результат — список пар #(расширение, количество), отсортированный по расширению.
/// Считайте, что все файлы имеют расширение формата ".xxx".
pub fn count_by_extension(node: FSNode) -> List(#(String, Int)) {
  todo
}

/// Группирует файлы по директории, в которой они находятся.
/// Возвращает список пар #(имя_директории, список_файлов),
/// отсортированный по имени директории. Директории без файлов не включаются.
pub fn group_by_directory(node: FSNode) -> List(#(String, List(String))) {
  todo
}

// ── Упражнение 7: Builder-паттерн ────────────────────────────────────────────
//
// FsQuery — «конфигурирующий» builder: аккумулирует фильтры и применяет их
// к дереву файловой системы одним вызовом run_query.
//
// Тип FsQuery уже определён в chapter04.gleam — вам не нужно его объявлять.
// Поле extension: Option(String), min_size: Option(Int), max_size: Option(Int).
//
// Реализуйте:
//   new_query()            — пустой запрос: без фильтров → вернёт все файлы
//   with_extension(q, ext) — добавить фильтр по расширению (напр. ".gleam")
//   with_min_size(q, size) — добавить фильтр: размер ≥ size
//   with_max_size(q, size) — добавить фильтр: размер ≤ size
//   run_query(q, node)     — применить запрос, вернуть имена подходящих файлов
//
// Пример:
//   new_query()
//   |> with_extension(".gleam")
//   |> with_min_size(1000)
//   |> run_query(sample_fs)
//   // → ["main.gleam", "main_test.gleam"]

pub fn new_query() -> FsQuery {
  todo
}

pub fn with_extension(q: FsQuery, ext: String) -> FsQuery {
  todo
}

pub fn with_min_size(q: FsQuery, size: Int) -> FsQuery {
  todo
}

pub fn with_max_size(q: FsQuery, size: Int) -> FsQuery {
  todo
}

pub fn run_query(q: FsQuery, node: FSNode) -> List(String) {
  todo
}
