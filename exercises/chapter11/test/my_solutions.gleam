//// Здесь вы можете писать свои решения упражнений.

import lustre/element.{type Element}

/// Рендерит список строк как HTML `<ul>` с `<li>` элементами.
pub fn render_list(items: List(String)) -> Element(msg) {
  todo
}

/// Тип сообщений для счётчика.
pub type CounterMsg {
  CounterIncrement
  CounterDecrement
  CounterReset
}

/// Начальное состояние счётчика.
pub fn counter_init() -> Int {
  todo
}

/// Обновление состояния счётчика.
pub fn counter_update(model: Int, msg: CounterMsg) -> Int {
  todo
}
