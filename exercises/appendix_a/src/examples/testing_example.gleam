// Примеры тестирования бота с telega/testing
//
// Эти функции демонстрируют паттерны тестирования.
// Реальные тесты находятся в test/appendix_a_test.gleam.

import telega/reply
import telega/router
import telega/testing/conversation

// ── 1. Conversation DSL ─────────────────────────────────────────────────────
//
// conversation.conversation_test() создаёт тест-цепочку:
//   send("text")                    — отправляем текст боту
//   expect_reply("text")            — ожидаем точный ответ
//   expect_reply_containing("part") — ответ содержит подстроку
//   expect_keyboard(buttons: [...]) — ответ содержит inline-клавиатуру
//   run(router, fn() { session })   — запускаем тест

pub fn example_conversation_test() {
  let test_router =
    router.new("test")
    |> router.on_command("start", fn(ctx, _cmd) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Привет!")
      Ok(ctx)
    })
    |> router.on_any_text(fn(ctx, text) {
      let assert Ok(_) = reply.with_text(ctx:, text: "Эхо: " <> text)
      Ok(ctx)
    })

  conversation.conversation_test()
  |> conversation.send("/start")
  |> conversation.expect_reply_containing("Привет")
  |> conversation.send("hello")
  |> conversation.expect_reply("Эхо: hello")
  |> conversation.run(test_router, fn() { Nil })
}
