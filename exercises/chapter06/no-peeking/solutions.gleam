//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/list
import gleam/regexp
import gleam/string
import gleam/string_tree

pub fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String {
  let attrs_str =
    attrs
    |> list.map(fn(attr) {
      " " <> attr.0 <> "=\"" <> escape_html(attr.1) <> "\""
    })
    |> string.concat
  "<" <> name <> attrs_str <> ">" <> children <> "</" <> name <> ">"
}

pub fn build_list(items: List(String), ordered: Bool) -> String {
  let wrapper = case ordered {
    True -> "ol"
    False -> "ul"
  }
  let inner =
    items
    |> list.map(fn(item) { "<li>" <> item <> "</li>" })
    |> string.concat
  "<" <> wrapper <> ">" <> inner <> "</" <> wrapper <> ">"
}

pub fn linkify(text: String) -> String {
  let assert Ok(re) = regexp.from_string("https?://\\S+")
  let matches =
    regexp.scan(re, text)
    |> list.map(fn(m) { m.content })
  list.fold(matches, text, fn(acc, url) {
    string.replace(acc, url, "<a href=\"" <> url <> "\">" <> url <> "</a>")
  })
}

pub fn build_table(
  headers: List(String),
  rows: List(List(String)),
) -> String {
  let head_cells =
    headers
    |> list.map(fn(h) { "<th>" <> h <> "</th>" })
    |> string.concat
  let thead = "<thead><tr>" <> head_cells <> "</tr></thead>"

  let tbody =
    rows
    |> list.fold(string_tree.new(), fn(tree, row) {
      let cells =
        row
        |> list.map(fn(cell) { "<td>" <> cell <> "</td>" })
        |> string.concat
      tree |> string_tree.append("<tr>" <> cells <> "</tr>")
    })
  let tbody_str = "<tbody>" <> string_tree.to_string(tbody) <> "</tbody>"

  "<table>" <> thead <> tbody_str <> "</table>"
}
