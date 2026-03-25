// Примеры клавиатур в Telega

import telega/keyboard
import telega/reply
import telega/router

// Пример inline-клавиатуры
pub fn send_settings_menu(ctx) {
  let lang_cb = keyboard.string_callback_data("lang")
  let notification_cb = keyboard.string_callback_data("notification")
  let close_cb = keyboard.string_callback_data("close")

  let assert Ok(kb) =
    keyboard.inline_builder()
    |> keyboard.inline_text(
      "🌍 Изменить язык",
      keyboard.pack_callback(callback_data: lang_cb, data: "open"),
    )
  let assert Ok(kb) =
    kb
    |> keyboard.inline_text(
      "🔔 Уведомления",
      keyboard.pack_callback(callback_data: notification_cb, data: "open"),
    )
  let kb = kb |> keyboard.inline_next_row()
  let assert Ok(kb) =
    kb
    |> keyboard.inline_text(
      "❌ Закрыть",
      keyboard.pack_callback(callback_data: close_cb, data: "close"),
    )
  let kb = keyboard.inline_build(kb)

  let assert Ok(_) =
    reply.with_markup(
      ctx:,
      text: "⚙️ Настройки:",
      markup: keyboard.inline_to_markup(kb),
    )
  Ok(ctx)
}

// Пример custom-клавиатуры (reply keyboard)
pub fn ask_confirmation(ctx) {
  let kb =
    keyboard.builder()
    |> keyboard.text("✅ Да")
    |> keyboard.text("❌ Нет")
    |> keyboard.next_row()
    |> keyboard.text("❓ Не уверен")
    |> keyboard.build()

  let assert Ok(_) =
    reply.with_markup(
      ctx:,
      text: "Подтвердите действие:",
      markup: keyboard.to_markup(kb),
    )
  Ok(ctx)
}

// Обработка inline-клавиатур через роутер
pub fn build_settings_router() {
  router.new("settings_bot")
  |> router.on_callback(router.Exact("lang"), fn(ctx, _data, _query_id) {
    show_language_menu(ctx)
  })
  |> router.on_callback(router.Exact("close"), fn(ctx, _data, _query_id) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Меню закрыто")
    Ok(ctx)
  })
}

fn show_language_menu(ctx) {
  let assert Ok(_) = reply.with_text(ctx:, text: "Выберите язык...")
  Ok(ctx)
}

// Обработка custom-клавиатур
pub fn build_quiz_router() {
  router.new("quiz_bot")
  |> router.on_text(router.Exact("✅ Да"), fn(ctx, _) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Отлично! Продолжаем.")
    Ok(ctx)
  })
  |> router.on_text(router.Exact("❌ Нет"), fn(ctx, _) {
    let assert Ok(_) = reply.with_text(ctx:, text: "Операция отменена.")
    Ok(ctx)
  })
}
