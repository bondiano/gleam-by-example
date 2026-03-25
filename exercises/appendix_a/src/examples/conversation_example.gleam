import gleam/int
import gleam/option.{None, Some}

import telega
import telega/bot.{type Context}
import telega/reply

pub type Plan {
  Free
  Premium
}

// Простой диалог
pub fn handle_name_conversation(ctx: Context(Nil, Nil), _command) {
  let assert Ok(_) = reply.with_text(ctx:, text: "Как вас зовут?")
  use ctx, name <- telega.wait_text(ctx:, or: None, timeout: None)

  let assert Ok(_) = reply.with_text(ctx:, text: "Сколько вам лет?")
  use ctx, age_str <- telega.wait_text(ctx:, or: None, timeout: None)

  let assert Ok(_) =
    reply.with_text(
      ctx:,
      text: "Привет, " <> name <> "! Вам " <> age_str <> " лет.",
    )
  Ok(ctx)
}

// Форма регистрации с валидацией
pub fn handle_register(ctx: Context(Nil, Nil), _command) {
  let assert Ok(_) =
    reply.with_text(ctx:, text: "Давайте зарегистрируемся! Как вас зовут?")
  use ctx, name <- telega.wait_text(ctx:, or: None, timeout: Some(120_000))

  let assert Ok(_) = reply.with_text(ctx:, text: "Сколько вам лет?")
  use ctx, age <- telega.wait_number(
    ctx:,
    min: Some(13),
    max: Some(120),
    or: Some(
      bot.HandleText(fn(ctx, _) {
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Введите возраст (число от 13 до 120)")
        Ok(ctx)
      }),
    ),
    timeout: Some(60_000),
  )

  let assert Ok(_) = reply.with_text(ctx:, text: "Ваш email?")
  use ctx, email <- telega.wait_email(
    ctx:,
    or: Some(
      bot.HandleText(fn(ctx, _) {
        let assert Ok(_) =
          reply.with_text(ctx:, text: "Некорректный email. Попробуйте ещё раз.")
        Ok(ctx)
      }),
    ),
    timeout: Some(60_000),
  )

  let assert Ok(_) = reply.with_text(ctx:, text: "Выберите тарифный план:")
  use ctx, plan <- telega.wait_choice(
    ctx:,
    options: [#("🆓 Бесплатный", Free), #("💎 Премиум", Premium)],
    or: None,
    timeout: Some(60_000),
  )

  // Сохраняем в БД
  let plan_name = case plan {
    Free -> "Бесплатный"
    Premium -> "Премиум"
  }

  let _ = email
  let assert Ok(_) =
    reply.with_text(
      ctx:,
      text: "✅ Регистрация завершена!\n\nИмя: "
        <> name
        <> "\nВозраст: "
        <> int.to_string(age)
        <> "\nПлан: "
        <> plan_name,
    )
  Ok(ctx)
}
