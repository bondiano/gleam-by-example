import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// escape_html

pub fn escape_html_tags_test() {
  my_solutions.escape_html("<script>alert('xss')</script>")
  |> should.equal(
    "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;",
  )
}

pub fn escape_html_ampersand_test() {
  my_solutions.escape_html("Tom & Jerry")
  |> should.equal("Tom &amp; Jerry")
}

pub fn escape_html_quotes_test() {
  my_solutions.escape_html("value=\"hello\"")
  |> should.equal("value=&quot;hello&quot;")
}

pub fn escape_html_plain_test() {
  my_solutions.escape_html("hello world")
  |> should.equal("hello world")
}

// tag

pub fn tag_simple_test() {
  my_solutions.tag("p", [], "Hello")
  |> should.equal("<p>Hello</p>")
}

pub fn tag_with_attrs_test() {
  my_solutions.tag("a", [#("href", "https://gleam.run")], "Gleam")
  |> should.equal("<a href=\"https://gleam.run\">Gleam</a>")
}

pub fn tag_multiple_attrs_test() {
  my_solutions.tag("div", [#("class", "box"), #("id", "main")], "content")
  |> should.equal("<div class=\"box\" id=\"main\">content</div>")
}

pub fn tag_escapes_attr_value_test() {
  my_solutions.tag("img", [#("alt", "a < b & c")], "")
  |> should.equal("<img alt=\"a &lt; b &amp; c\"></img>")
}

// build_list

pub fn build_list_unordered_test() {
  my_solutions.build_list(["one", "two", "three"], False)
  |> should.equal("<ul><li>one</li><li>two</li><li>three</li></ul>")
}

pub fn build_list_ordered_test() {
  my_solutions.build_list(["first", "second"], True)
  |> should.equal("<ol><li>first</li><li>second</li></ol>")
}

pub fn build_list_empty_test() {
  my_solutions.build_list([], False)
  |> should.equal("<ul></ul>")
}

// linkify

pub fn linkify_single_url_test() {
  my_solutions.linkify("Visit https://gleam.run for more")
  |> should.equal(
    "Visit <a href=\"https://gleam.run\">https://gleam.run</a> for more",
  )
}

pub fn linkify_no_urls_test() {
  my_solutions.linkify("no urls here")
  |> should.equal("no urls here")
}

pub fn linkify_multiple_urls_test() {
  my_solutions.linkify("see http://a.com and https://b.org end")
  |> should.equal(
    "see <a href=\"http://a.com\">http://a.com</a> and <a href=\"https://b.org\">https://b.org</a> end",
  )
}

// build_table

pub fn build_table_test() {
  my_solutions.build_table(
    ["Name", "Age"],
    [["Alice", "30"], ["Bob", "25"]],
  )
  |> should.equal(
    "<table><thead><tr><th>Name</th><th>Age</th></tr></thead><tbody><tr><td>Alice</td><td>30</td></tr><tr><td>Bob</td><td>25</td></tr></tbody></table>",
  )
}

pub fn build_table_single_row_test() {
  my_solutions.build_table(["X"], [["1"]])
  |> should.equal(
    "<table><thead><tr><th>X</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>",
  )
}

pub fn build_table_empty_rows_test() {
  my_solutions.build_table(["A", "B"], [])
  |> should.equal(
    "<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody></tbody></table>",
  )
}
