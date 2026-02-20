import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pog
import telega/bot.{type Context, wait_text}
import telega/reply
import telega/update.{type Command}
import todo_bot/db

fn get_user_id(ctx: Context(s, d)) -> Int {
  ctx.update.message
  |> option.map(fn(m) { m.from })
  |> option.flatten
  |> option.map(fn(u) { u.id })
  |> option.unwrap(0)
}

// Показать список задач
pub fn handle_list(ctx: Context(Nil, Nil), db_conn: pog.Connection) {
  let user_id = get_user_id(ctx)

  case db.list_user_todos(db_conn, user_id) {
    Error(_) -> {
      let assert Ok(_) = reply.with_text(ctx, "❌ Ошибка загрузки задач.")
      Ok(ctx)
    }
    Ok([]) -> {
      let assert Ok(_) =
        reply.with_text(ctx, "Список задач пуст. Добавьте задачу: /add")
      Ok(ctx)
    }
    Ok(todos) -> {
      let lines =
        todos
        |> list.index_map(fn(item, i) {
          let status = case item.completed {
            True -> "✅"
            False -> "☐"
          }
          status <> " " <> int.to_string(i + 1) <> ". " <> item.title
        })
        |> string.join("\n")

      let assert Ok(_) = reply.with_text(ctx, "Ваши задачи:\n\n" <> lines)
      Ok(ctx)
    }
  }
}

// Добавить задачу через Conversation API
pub fn handle_add_conversation(ctx: Context(Nil, Nil), db_conn: pog.Connection) {
  let user_id = get_user_id(ctx)

  // Начинаем диалог
  use ctx <- reply.with_text(ctx, "Введите название задачи:")

  // Ждём текстовое сообщение
  use ctx, title <- wait_text(ctx, or: None, timeout: Some(60_000))

  // Валидация
  case string.trim(title) {
    "" -> {
      let assert Ok(_) =
        reply.with_text(
          ctx,
          "❌ Название не может быть пустым. Попробуйте снова: /add",
        )
      Ok(ctx)
    }
    valid_title ->
      case db.create_todo(db_conn, user_id, valid_title) {
        Error(_) -> {
          let assert Ok(_) = reply.with_text(ctx, "❌ Ошибка при сохранении.")
          Ok(ctx)
        }
        Ok(_) -> {
          let assert Ok(_) =
            reply.with_text(ctx, "✅ Задача «" <> valid_title <> "» добавлена!")
          Ok(ctx)
        }
      }
  }
}

// Отметить задачу выполненной
pub fn handle_done(
  ctx: Context(Nil, Nil),
  db_conn: pog.Connection,
  command: Command,
) {
  let user_id = get_user_id(ctx)
  let index_str = command.payload |> option.unwrap("")

  case int.parse(index_str) {
    Error(_) -> {
      let assert Ok(_) = reply.with_text(ctx, "Укажите номер задачи: /done 1")
      Ok(ctx)
    }
    Ok(index) ->
      case db.mark_todo_done(db_conn, user_id, index - 1) {
        Error(_) -> {
          let assert Ok(_) =
            reply.with_text(
              ctx,
              "❌ Нет задачи с номером " <> int.to_string(index),
            )
          Ok(ctx)
        }
        Ok(_) -> {
          let assert Ok(_) = reply.with_text(ctx, "✅ Задача выполнена!")
          Ok(ctx)
        }
      }
  }
}

// Очистить выполненные задачи
pub fn handle_clear(ctx: Context(Nil, Nil), db_conn: pog.Connection) {
  let user_id = get_user_id(ctx)

  case db.delete_completed_todos(db_conn, user_id) {
    Error(_) -> {
      let assert Ok(_) = reply.with_text(ctx, "❌ Ошибка при удалении.")
      Ok(ctx)
    }
    Ok(count) -> {
      let assert Ok(_) =
        reply.with_text(ctx, "🗑 Удалено задач: " <> int.to_string(count))
      Ok(ctx)
    }
  }
}
