import gleam/erlang/process
import mist
import telega/adapters/wisp as telega_wisp
import todo_bot/bot
import todo_bot/db
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // Подключаемся к PostgreSQL
  let db_conn = db.connect()

  // Создаём таблицы если их нет
  let assert Ok(_) = db.create_schema(db_conn)

  // Собираем бота
  let assert Ok(telegram_bot) = bot.build(db_conn)

  // Запускаем веб-сервер
  let assert Ok(_) =
    wisp_mist.handler(handle_request(telegram_bot, _), "secret_key_base")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(telegram_bot, req) {
  use <- telega_wisp.handle_bot(telegram_bot, req)

  // Все остальные запросы (не webhook) возвращают 404
  wisp.not_found()
}
