import telega/reply
import telega/router

pub fn build_bot_router() {
  // Строим роутер через цепочку пайпов
  router.new("my_bot")
  |> router.on_command("start", fn(ctx, _command) {
    let assert Ok(_) =
      reply.with_text(ctx:, text: "Привет! Я готов к работе. /help для помощи.")
    Ok(ctx)
  })
  |> router.on_command("help", fn(ctx, _command) {
    let assert Ok(_) =
      reply.with_text(
        ctx:,
        text: "Доступные команды:\n/start — начало\n/help — помощь\n/echo — повторить текст",
      )
    Ok(ctx)
  })
  // Любой текст — text передаётся как аргумент обработчика
  |> router.on_any_text(fn(ctx, text) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Вы написали: " <> text)
    Ok(ctx)
  })
  // Только если текст точно совпадает с "ping"
  |> router.on_text(router.Exact("ping"), fn(ctx, _text) {
    let assert Ok(_) = reply.with_text(ctx:, text: "pong!")
    Ok(ctx)
  })
}

// Пример композиции роутеров — merge объединяет два роутера
pub fn build_composed_router() {
  let admin_router =
    router.new("admin")
    |> router.on_command("ban", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Пользователь заблокирован")
      Ok(ctx)
    })

  let user_router =
    router.new("user")
    |> router.on_command("start", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
      Ok(ctx)
    })

  // merge объединяет команды обоих роутеров в один
  router.merge(user_router, admin_router)
}
