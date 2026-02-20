import gleam/erlang/os
import gleam/option.{None}
import gleam/result
import pog
import telega
import telega/reply
import telega/router
import todo_bot/handlers/todos

pub fn build(db_conn: pog.Connection) -> Result(telega.Telega(Nil, Nil), String) {
  let token = os.get_env("TELEGRAM_TOKEN") |> result.unwrap("")
  let url = os.get_env("BOT_URL") |> result.unwrap("https://example.com")

  let bot_router =
    router.new("todo_bot")
    // /start
    |> router.on_command("start", fn(ctx, _command) {
      let assert Ok(_) =
        reply.with_text(
          ctx,
          "Привет! Я TODO-бот.\n\n/list — список задач\n/add — добавить задачу\n/help — помощь",
        )
      Ok(ctx)
    })
    // /help
    |> router.on_command("help", fn(ctx, _command) {
      let assert Ok(_) =
        reply.with_text(
          ctx,
          "Команды:\n/list — все задачи\n/add — добавить\n/done <номер> — отметить выполненной\n/clear — очистить выполненные",
        )
      Ok(ctx)
    })
    // /list
    |> router.on_command("list", fn(ctx, _command) {
      todos.handle_list(ctx, db_conn)
    })
    // /add — многошаговый диалог через Conversation API
    |> router.on_command("add", fn(ctx, _command) {
      todos.handle_add_conversation(ctx, db_conn)
    })
    // /done
    |> router.on_command("done", fn(ctx, command) {
      todos.handle_done(ctx, db_conn, command)
    })
    // /clear
    |> router.on_command("clear", fn(ctx, _command) {
      todos.handle_clear(ctx, db_conn)
    })

  use bot <- result.try(
    telega.new(token: token, url: url, webhook_path: "/bot", secret_token: None)
    |> telega.with_router(bot_router)
    |> telega.with_nil_session()
    |> telega.init(),
  )

  Ok(bot)
}
