import gleam/option.{None, Some}
import gleam/result
import telega
import telega/reply
import telega/router

pub fn build_bot(token: String, url: String) {
  // Строим роутер через цепочку пайпов
  let bot_router =
    router.new("my_bot")
    |> router.on_command("start", fn(ctx, _command) {
      let assert Ok(_) =
        reply.with_text(ctx, "Привет! Я готов к работе. /help для помощи.")
      Ok(ctx)
    })
    |> router.on_command("help", fn(ctx, _command) {
      let assert Ok(_) =
        reply.with_text(
          ctx,
          "Доступные команды:\n/start — начало\n/help — помощь\n/echo — повторить текст",
        )
      Ok(ctx)
    })
    // Любой текст — text передаётся как аргумент обработчика
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx, "Вы написали: " <> text)
      Ok(ctx)
    })
    // Только если текст точно совпадает с "ping"
    |> router.on_text(router.Exact("ping"), fn(ctx, _text) {
      let assert Ok(_) = reply.with_text(ctx, "pong!")
      Ok(ctx)
    })

  let assert Ok(bot) =
    telega.new(token: token, url: url, webhook_path: "/bot", secret_token: None)
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init()

  bot
}
