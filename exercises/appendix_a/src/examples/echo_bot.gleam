import gleam/erlang/process
import gleam/option.{None}
import mist
import telega
import telega/adapters/wisp as telega_wisp
import telega/reply
import telega/router
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // Роутер с одним обработчиком — любой текст отзывается эхом
  let bot_router =
    router.new("echo_bot")
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx, text)
      Ok(ctx)
    })

  // Создаём бота с токеном и роутером
  let assert Ok(bot) =
    telega.new(
      token: "YOUR_BOT_TOKEN",
      url: "https://your-server.com",
      webhook_path: "/bot",
      secret_token: None,
    )
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init()

  let assert Ok(_) =
    wisp_mist.handler(handle_request(bot, _), "secret_key_base")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(
  bot: telega.Telega(Nil, Nil),
  req: wisp.Request,
) -> wisp.Response {
  // Телега перехватывает запросы на webhook-путь
  use <- telega_wisp.handle_bot(bot, req)
  // Всё остальное — обычный Wisp
  wisp.not_found()
}
