//// Референсные решения — не подсматривайте, пока не попробуете сами!

import chapter04.{type FsQuery, type FSNode, Directory, File, FsQuery}
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn total_size(node: FSNode) -> Int {
  case node {
    File(size:, ..) -> size
    Directory(children:, ..) ->
      list.fold(children, 0, fn(acc, child) { acc + total_size(child) })
  }
}

pub fn all_files(node: FSNode) -> List(String) {
  case node {
    File(name:, ..) -> [name]
    Directory(children:, ..) ->
      list.flat_map(children, all_files)
  }
}

pub fn find_by_extension(node: FSNode, ext: String) -> List(String) {
  case node {
    File(name:, ..) ->
      case string.ends_with(name, ext) {
        True -> [name]
        False -> []
      }
    Directory(children:, ..) ->
      list.flat_map(children, find_by_extension(_, ext))
  }
}

pub fn largest_file(node: FSNode) -> Result(#(String, Int), Nil) {
  collect_files(node)
  |> list.reduce(fn(a, b) {
    case a.1 > b.1 {
      True -> a
      False -> b
    }
  })
}

fn collect_files(node: FSNode) -> List(#(String, Int)) {
  case node {
    File(name:, size:) -> [#(name, size)]
    Directory(children:, ..) ->
      list.flat_map(children, collect_files)
  }
}

pub fn count_by_extension(node: FSNode) -> List(#(String, Int)) {
  all_files(node)
  |> list.group(fn(name) {
    case string.split(name, ".") {
      [_, ext] -> "." <> ext
      _ -> ""
    }
  })
  |> dict.map_values(fn(_, v) { list.length(v) })
  |> dict.to_list
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

pub fn group_by_directory(node: FSNode) -> List(#(String, List(String))) {
  collect_dir_files(node)
  |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
}

fn collect_dir_files(node: FSNode) -> List(#(String, List(String))) {
  case node {
    File(..) -> []
    Directory(name:, children:) -> {
      let files =
        list.filter_map(children, fn(child) {
          case child {
            File(name:, ..) -> Ok(name)
            Directory(..) -> Error(Nil)
          }
        })
      let sub = list.flat_map(children, collect_dir_files)
      case files {
        [] -> sub
        _ -> [#(name, files), ..sub]
      }
    }
  }
}

// ── Упражнение 7: FsQuery builder ────────────────────────────────────────────

pub fn new_query() -> FsQuery {
  FsQuery(extension: None, min_size: None, max_size: None)
}

pub fn with_extension(q: FsQuery, ext: String) -> FsQuery {
  FsQuery(..q, extension: Some(ext))
}

pub fn with_min_size(q: FsQuery, size: Int) -> FsQuery {
  FsQuery(..q, min_size: Some(size))
}

pub fn with_max_size(q: FsQuery, size: Int) -> FsQuery {
  FsQuery(..q, max_size: Some(size))
}

pub fn run_query(q: FsQuery, node: FSNode) -> List(String) {
  collect_files(node)
  |> list.filter_map(fn(pair) {
    let #(name, size) = pair
    let ok_ext = case q.extension {
      None -> True
      Some(ext) -> string.ends_with(name, ext)
    }
    let ok_min = case q.min_size {
      None -> True
      Some(min) -> size >= min
    }
    let ok_max = case q.max_size {
      None -> True
      Some(max) -> size <= max
    }
    case ok_ext && ok_min && ok_max {
      True -> Ok(name)
      False -> Error(Nil)
    }
  })
}
