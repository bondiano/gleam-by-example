import gleam/erlang/process

import telega
import telega/reply
import telega/router
import telega_httpc

pub fn main() {
  // Роутер с одним обработчиком — любой текст отзывается эхом
  let bot_router =
    router.new("echo_bot")
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx:, text:)
      Ok(ctx)
    })

  // Создаём HTTP-клиент и бота в режиме polling
  let client = telega_httpc.new(token: "YOUR_BOT_TOKEN")

  let assert Ok(_bot) =
    telega.new_for_polling(api_client: client)
    |> telega.with_router(bot_router)
    |> telega.init_for_polling_nil_session()

  // Бот запущен — дерево супервизоров управляет polling
  process.sleep_forever()
}
