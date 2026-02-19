import lustre/element.{type Element}
import lustre/element/html

/// Пример: статический HTML
pub fn greeting(name: String) -> Element(msg) {
  html.div([], [
    html.h1([], [element.text("Привет, " <> name <> "!")]),
  ])
}
