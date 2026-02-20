import gleam/option.{None, Some}
import telega/bot.{type Context}
import telega/keyboard
import telega/reply
import telega/router

// Пример inline-клавиатуры
pub fn send_settings_menu(ctx) {
  let kb =
    keyboard.inline_builder()
    |> keyboard.inline_button(
      "🌍 Изменить язык",
      keyboard.string_callback_data("lang"),
    )
    |> keyboard.inline_button(
      "🔔 Уведомления",
      keyboard.string_callback_data("notif"),
    )
    |> keyboard.inline_row()
    |> keyboard.inline_button(
      "❌ Закрыть",
      keyboard.string_callback_data("close"),
    )
    |> keyboard.inline_build()

  let assert Ok(_) =
    reply.with_markup(ctx, "⚙️ Настройки:", keyboard.inline_to_markup(kb))
  Ok(ctx)
}

// Пример custom-клавиатуры
pub fn ask_confirmation(ctx) {
  let kb =
    keyboard.custom_builder()
    |> keyboard.custom_button("✅ Да")
    |> keyboard.custom_button("❌ Нет")
    |> keyboard.custom_row()
    |> keyboard.custom_button("❓ Не уверен")
    |> keyboard.custom_build(one_time: True, resize: True)

  let assert Ok(_) =
    reply.with_markup(
      ctx,
      "Подтвердите действие:",
      keyboard.custom_to_markup(kb),
    )
  Ok(ctx)
}

// Обработка inline-клавиатур через роутер
pub fn build_settings_router() {
  router.new("settings_bot")
  |> router.on_callback_query("lang", fn(ctx, query) {
    // Обязательно отвечаем на callback query
    let assert Ok(_) =
      reply.answer_callback_query(
        ctx,
        query.id,
        Some("Открываю настройки языка..."),
      )
    // Обрабатываем действие
    show_language_menu(ctx)
  })
  |> router.on_callback_query("close", fn(ctx, query) {
    let assert Ok(_) = reply.answer_callback_query(ctx, query.id, None)
    let assert Ok(_) = reply.delete_message(ctx, query.message.message_id)
    Ok(ctx)
  })
}

fn show_language_menu(ctx) {
  let assert Ok(_) = reply.with_text(ctx, "Выберите язык...")
  Ok(ctx)
}

// Обработка custom-клавиатур
pub fn build_quiz_router() {
  router.new("quiz_bot")
  |> router.on_text(router.Exact("✅ Да"), fn(ctx, _) {
    let assert Ok(_) = reply.with_text(ctx, "Отлично! Продолжаем.")
    Ok(ctx)
  })
  |> router.on_text(router.Exact("❌ Нет"), fn(ctx, _) {
    let assert Ok(_) = reply.with_text(ctx, "Операция отменена.")
    Ok(ctx)
  })
}
