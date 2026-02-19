import chapter04.{Directory, File, type FSNode}
import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

/// Тестовое дерево:
/// project/
/// ├── README.md (1024)
/// ├── src/
/// │   ├── main.gleam (2048)
/// │   └── utils.gleam (512)
/// └── test/
///     └── main_test.gleam (1536)
fn sample_fs() -> FSNode {
  Directory("project", [
    File("README.md", 1024),
    Directory("src", [
      File("main.gleam", 2048),
      File("utils.gleam", 512),
    ]),
    Directory("test", [
      File("main_test.gleam", 1536),
    ]),
  ])
}

// --- total_size ---

pub fn total_size_file_test() {
  my_solutions.total_size(File("a.txt", 100))
  |> should.equal(100)
}

pub fn total_size_tree_test() {
  my_solutions.total_size(sample_fs())
  |> should.equal(5120)
}

pub fn total_size_empty_dir_test() {
  my_solutions.total_size(Directory("empty", []))
  |> should.equal(0)
}

// --- all_files ---

pub fn all_files_test() {
  my_solutions.all_files(sample_fs())
  |> should.equal(["README.md", "main.gleam", "utils.gleam", "main_test.gleam"])
}

pub fn all_files_single_test() {
  my_solutions.all_files(File("only.txt", 10))
  |> should.equal(["only.txt"])
}

// --- find_by_extension ---

pub fn find_by_extension_gleam_test() {
  my_solutions.find_by_extension(sample_fs(), ".gleam")
  |> should.equal(["main.gleam", "utils.gleam", "main_test.gleam"])
}

pub fn find_by_extension_md_test() {
  my_solutions.find_by_extension(sample_fs(), ".md")
  |> should.equal(["README.md"])
}

pub fn find_by_extension_none_test() {
  my_solutions.find_by_extension(sample_fs(), ".rs")
  |> should.equal([])
}

// --- largest_file ---

pub fn largest_file_test() {
  my_solutions.largest_file(sample_fs())
  |> should.equal(Ok(#("main.gleam", 2048)))
}

pub fn largest_file_empty_test() {
  my_solutions.largest_file(Directory("empty", []))
  |> should.equal(Error(Nil))
}

// --- count_by_extension ---

pub fn count_by_extension_test() {
  my_solutions.count_by_extension(sample_fs())
  |> should.equal([#(".gleam", 3), #(".md", 1)])
}

// --- group_by_directory ---

pub fn group_by_directory_test() {
  my_solutions.group_by_directory(sample_fs())
  |> should.equal([
    #("project", ["README.md"]),
    #("src", ["main.gleam", "utils.gleam"]),
    #("test", ["main_test.gleam"]),
  ])
}

// --- FsQuery builder (упражнение 7) ---

pub fn query_all_test() {
  my_solutions.new_query()
  |> my_solutions.run_query(sample_fs())
  |> should.equal(["README.md", "main.gleam", "utils.gleam", "main_test.gleam"])
}

pub fn query_extension_test() {
  my_solutions.new_query()
  |> my_solutions.with_extension(".gleam")
  |> my_solutions.run_query(sample_fs())
  |> should.equal(["main.gleam", "utils.gleam", "main_test.gleam"])
}

pub fn query_min_size_test() {
  my_solutions.new_query()
  |> my_solutions.with_min_size(1000)
  |> my_solutions.run_query(sample_fs())
  |> should.equal(["README.md", "main.gleam", "main_test.gleam"])
}

pub fn query_max_size_test() {
  my_solutions.new_query()
  |> my_solutions.with_max_size(1000)
  |> my_solutions.run_query(sample_fs())
  |> should.equal(["utils.gleam"])
}

pub fn query_combined_test() {
  my_solutions.new_query()
  |> my_solutions.with_min_size(1000)
  |> my_solutions.with_max_size(2000)
  |> my_solutions.run_query(sample_fs())
  |> should.equal(["README.md", "main_test.gleam"])
}
