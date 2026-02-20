import gleam/int
import gleam/option.{None, Some}
import telega/bot.{type Context, wait_choice, wait_email, wait_number, wait_text}
import telega/reply

pub type Plan {
  Free
  Premium
}

// Простой диалог
pub fn handle_name_conversation(ctx: Context(Nil, Nil), _command) {
  use ctx <- reply.with_text(ctx, "Как вас зовут?")
  use ctx, name <- wait_text(ctx, or: None, timeout: None)

  use ctx <- reply.with_text(ctx, "Сколько вам лет?")
  use ctx, age_str <- wait_text(ctx, or: None, timeout: None)

  reply.with_text(ctx, "Привет, " <> name <> "! Вам " <> age_str <> " лет.")
}

// Форма регистрации с валидацией
pub fn handle_register(ctx: Context(Nil, Nil), _command) {
  use ctx <- reply.with_text(ctx, "Давайте зарегистрируемся! Как вас зовут?")
  use ctx, name <- wait_text(ctx, or: None, timeout: Some(120_000))

  use ctx <- reply.with_text(ctx, "Сколько вам лет?")
  use ctx, age <- wait_number(
    ctx,
    min: Some(13),
    max: Some(120),
    or: Some(
      bot.HandleText(fn(ctx, _) {
        reply.with_text(ctx, "Введите возраст (число от 13 до 120)")
      }),
    ),
    timeout: Some(60_000),
  )

  use ctx <- reply.with_text(ctx, "Ваш email?")
  use ctx, email <- wait_email(
    ctx,
    or: Some(
      bot.HandleText(fn(ctx, _) {
        reply.with_text(ctx, "Некорректный email. Попробуйте ещё раз.")
      }),
    ),
    timeout: Some(60_000),
  )

  use ctx <- reply.with_text(ctx, "Выберите тарифный план:")
  use ctx, plan <- wait_choice(
    ctx,
    [#("🆓 Бесплатный", Free), #("💎 Премиум", Premium)],
    or: None,
    timeout: Some(60_000),
  )

  // Сохраняем в БД
  let plan_name = case plan {
    Free -> "Бесплатный"
    Premium -> "Премиум"
  }

  reply.with_text(
    ctx,
    "✅ Регистрация завершена!\n\nИмя: "
      <> name
      <> "\nВозраст: "
      <> int.to_string(age)
      <> "\nПлан: "
      <> plan_name,
  )
}
