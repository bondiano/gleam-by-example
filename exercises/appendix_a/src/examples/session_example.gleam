import gleam/int
import gleam/option.{None, Some}
import gleam/result
import telega
import telega/bot
import telega/reply
import telega/router
import telega/session

// Пример сессии для музыкального бота
pub type MusicBotSession {
  MusicBotSession(
    language: String,
    favorite_genre: Option(String),
    plays_count: Int,
  )
}

// Значения по умолчанию для новых пользователей
pub fn default_session() -> MusicBotSession {
  MusicBotSession(language: "ru", favorite_genre: None, plays_count: 0)
}

pub fn build_bot(token: String, url: String) {
  let bot_router =
    router.new("music_bot")
    |> router.on_command("start", handle_start)
    |> router.on_command("stats", handle_stats)
    |> router.on_command("play", handle_play_track)
    |> router.on_command("lang", handle_change_language)

  let assert Ok(bot) =
    telega.new(token: token, url: url, webhook_path: "/bot", secret_token: None)
    |> telega.with_router(bot_router)
    |> session.attach(default_session)
    |> telega.init()

  bot
}

fn handle_start(ctx: bot.Context(MusicBotSession, Nil), _command) {
  let assert Ok(_) =
    reply.with_text(ctx, "🎵 Добро пожаловать в музыкальный бот!")
  Ok(ctx)
}

fn handle_stats(ctx: bot.Context(MusicBotSession, Nil), _command) {
  let plays = ctx.session.plays_count
  let genre = ctx.session.favorite_genre |> option.unwrap("не выбран")

  let message =
    "📊 Ваша статистика:\n"
    <> "🎵 Прослушано треков: "
    <> int.to_string(plays)
    <> "\n"
    <> "❤️ Любимый жанр: "
    <> genre

  let assert Ok(_) = reply.with_text(ctx, message)
  Ok(ctx)
}

fn handle_play_track(ctx: bot.Context(MusicBotSession, Nil), _command) {
  // Увеличиваем счётчик прослушиваний
  let updated_session =
    MusicBotSession(..ctx.session, plays_count: ctx.session.plays_count + 1)

  let assert Ok(_) = reply.with_text(ctx, "🎶 Трек начал играть!")

  // Сохраняем обновлённую сессию
  bot.next_session(ctx, updated_session)
}

fn handle_change_language(ctx: bot.Context(MusicBotSession, Nil), command) {
  let new_lang = command.payload |> option.unwrap("ru")

  // Проверяем валидность
  case new_lang {
    "ru" | "en" | "de" -> {
      // Создаём обновлённую сессию
      let updated = MusicBotSession(..ctx.session, language: new_lang)

      let message = case new_lang {
        "ru" -> "🇷🇺 Язык изменён на русский"
        "en" -> "🇬🇧 Language changed to English"
        "de" -> "🇩🇪 Sprache geändert auf Deutsch"
        _ -> ""
      }

      let assert Ok(_) = reply.with_text(ctx, message)
      bot.next_session(ctx, updated)
    }
    invalid -> {
      let assert Ok(_) = reply.with_text(ctx, "❌ Неизвестный язык: " <> invalid)
      Ok(ctx)
    }
  }
}
