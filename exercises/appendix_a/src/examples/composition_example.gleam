// Примеры композиции роутеров в Telega

import telega/reply
import telega/router

// ── 1. merge — объединение двух роутеров ────────────────────────────────────
//
// merge складывает команды, callbacks и routes двух роутеров в один.
// Если есть конфликт (одинаковая команда) — побеждает первый роутер.

pub fn merge_example() {
  let admin_router =
    router.new("admin")
    |> router.on_command("ban", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Пользователь заблокирован")
      Ok(ctx)
    })
    |> router.on_command("stats", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Статистика бота")
      Ok(ctx)
    })

  let user_router =
    router.new("user")
    |> router.on_command("start", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
      Ok(ctx)
    })
    |> router.on_command("help", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Помощь")
      Ok(ctx)
    })

  // Один роутер обрабатывает /start, /help, /ban, /stats
  router.merge(user_router, admin_router)
}

// ── 2. compose — последовательная цепочка ───────────────────────────────────
//
// compose создаёт цепочку: обновление пробуется на первом роутере,
// если не совпало — на втором. Каждый роутер сохраняет свои middleware.

pub fn compose_example() {
  let commands_router =
    router.new("commands")
    |> router.on_command("start", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
      Ok(ctx)
    })

  let fallback_router =
    router.new("fallback")
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) =
        reply.with_text(ctx:, text: "Не понимаю: " <> text)
      Ok(ctx)
    })

  // Сначала пробуем commands_router, потом fallback_router
  router.compose(commands_router, fallback_router)
}
