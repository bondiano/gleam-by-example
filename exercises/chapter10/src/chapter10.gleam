import wisp

/// Пример: простой обработчик
pub fn hello_handler(_req: wisp.Request) -> wisp.Response {
  wisp.ok()
  |> wisp.string_body("Hello, Gleam!")
}
