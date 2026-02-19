//// Референсные решения — не подсматривайте, пока не попробуете сами!

import lustre/element.{type Element}
import lustre/element/html

pub fn render_list(items: List(String)) -> Element(msg) {
  html.ul(
    [],
    items
      |> list.map(fn(item) { html.li([], [element.text(item)]) }),
  )
}

pub type CounterMsg {
  CounterIncrement
  CounterDecrement
  CounterReset
}

pub fn counter_init() -> Int {
  0
}

pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  case msg {
    CounterIncrement -> model + 1
    CounterDecrement -> model - 1
    CounterReset -> 0
  }
}
