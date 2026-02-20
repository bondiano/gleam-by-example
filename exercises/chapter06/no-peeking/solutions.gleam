//// Референсные решения — не подсматривайте, пока не попробуете сами!
//// HTML builder

import gleam/list
import gleam/regexp
import gleam/string

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

// Конструкторы элементов

pub fn element(
  tag: String,
  attrs: List(Attribute),
  children: List(Element),
) -> Element {
  Element(tag, attrs, children)
}

pub fn text(content: String) -> Element {
  Text(content)
}

// Распространённые HTML элементы

pub fn div(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("div", attrs, children)
}

pub fn p(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("p", attrs, children)
}

pub fn a(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("a", attrs, children)
}

pub fn ul(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("ul", attrs, children)
}

pub fn ol(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("ol", attrs, children)
}

pub fn li(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("li", attrs, children)
}

pub fn table(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("table", attrs, children)
}

pub fn thead(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("thead", attrs, children)
}

pub fn tbody(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("tbody", attrs, children)
}

pub fn tr(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("tr", attrs, children)
}

pub fn th(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("th", attrs, children)
}

pub fn td(attrs: List(Attribute), children: List(Element)) -> Element {
  Element("td", attrs, children)
}

pub fn img(attrs: List(Attribute)) -> Element {
  Element("img", attrs, [])
}

// Конструкторы атрибутов

pub fn attr(name: String, value: String) -> Attribute {
  Attribute(name, value)
}

pub fn class(value: String) -> Attribute {
  Attribute("class", value)
}

pub fn id(value: String) -> Attribute {
  Attribute("id", value)
}

pub fn href(value: String) -> Attribute {
  Attribute("href", value)
}

pub fn alt(value: String) -> Attribute {
  Attribute("alt", value)
}

// Рендеринг

pub fn to_string(element: Element) -> String {
  case element {
    Element(tag_name, attrs, children) -> {
      let attrs_str =
        attrs
        |> list.map(fn(attr) {
          " " <> attr.name <> "=\"" <> escape_html(attr.value) <> "\""
        })
        |> string.concat

      let children_str =
        children
        |> list.map(to_string)
        |> string.concat

      "<"
      <> tag_name
      <> attrs_str
      <> ">"
      <> children_str
      <> "</"
      <> tag_name
      <> ">"
    }
    Text(content) -> escape_html(content)
  }
}

// ============================================================
// Утилиты
// ============================================================

pub fn escape_html(content: String) -> String {
  content
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

// ============================================================
// Удобные функции-обёртки
// ============================================================

pub fn tag(
  name: String,
  attrs: List(#(String, String)),
  children: String,
) -> String {
  let attrs_list =
    attrs
    |> list.map(fn(pair) { Attribute(pair.0, pair.1) })

  element(name, attrs_list, [Text(children)])
  |> to_string
}

pub fn build_list(items: List(String), ordered: Bool) -> String {
  let constructor = case ordered {
    True -> ol
    False -> ul
  }

  let children =
    items
    |> list.map(fn(item) { li([], [text(item)]) })

  constructor([], children)
  |> to_string
}

pub fn linkify(input: String) -> String {
  let assert Ok(re) = regexp.from_string("https?://\\S+")
  let matches =
    regexp.scan(re, input)
    |> list.map(fn(m) { m.content })

  list.fold(matches, input, fn(acc, url) {
    let link = a([href(url)], [text(url)]) |> to_string
    string.replace(acc, url, link)
  })
}

pub fn build_table(headers: List(String), rows: List(List(String))) -> String {
  let head_row =
    headers
    |> list.map(fn(h) { th([], [text(h)]) })
    |> tr([], _)

  let body_rows =
    rows
    |> list.map(fn(row) {
      row
      |> list.map(fn(cell) { td([], [text(cell)]) })
      |> tr([], _)
    })

  table([], [thead([], [head_row]), tbody([], body_rows)])
  |> to_string
}
