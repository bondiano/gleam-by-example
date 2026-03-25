import gleam/int
import gleam/option.{type Option, None}

import telega/bot
import telega/reply
import telega/update

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

// Пример SessionSettings для подключения сессий к боту:
//
//   telega.new_for_polling(api_client: client)
//   |> telega.with_router(bot_router)
//   |> telega.with_session_settings(bot.SessionSettings(
//     persist_session: fn(_key, session) { Ok(session) },
//     get_session: fn(_key) { Ok(None) },
//     default_session: default_session,
//   ))
//   |> telega.init_for_polling()

fn handle_start(ctx: bot.Context(MusicBotSession, Nil), _command) {
  let assert Ok(_) =
    reply.with_text(ctx:, text: "🎵 Добро пожаловать в музыкальный бот!")
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

  let assert Ok(_) = reply.with_text(ctx:, text: message)
  Ok(ctx)
}

fn handle_play_track(ctx: bot.Context(MusicBotSession, Nil), _command) {
  // Увеличиваем счётчик прослушиваний
  let updated_session =
    MusicBotSession(..ctx.session, plays_count: ctx.session.plays_count + 1)

  let assert Ok(_) = reply.with_text(ctx:, text: "🎶 Трек начал играть!")

  // Сохраняем обновлённую сессию
  bot.next_session(ctx:, session: updated_session)
}

fn handle_change_language(
  ctx: bot.Context(MusicBotSession, Nil),
  command: update.Command,
) {
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

      let assert Ok(_) = reply.with_text(ctx:, text: message)
      bot.next_session(ctx:, session: updated)
    }
    invalid -> {
      let assert Ok(_) =
        reply.with_text(ctx:, text: "❌ Неизвестный язык: " <> invalid)
      Ok(ctx)
    }
  }
}

// Подавляем предупреждения о неиспользуемых функциях
pub fn ignore() {
  #(handle_start, handle_stats, handle_play_track, handle_change_language)
}
