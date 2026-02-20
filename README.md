# Gleam by Example

Образовательная книга по языку программирования [Gleam](https://gleam.run/), написанная на русском языке. Проект является адаптацией "PureScript by Example" и предназначен для пошагового изучения Gleam через практические примеры и упражнения.

## Описание

**Gleam by Example** — это интерактивная книга, состоящая из 14 глав и приложения. Большинство глав содержат:

- Теоретический материал с примерами кода
- Практические упражнения для закрепления материала
- Тесты для проверки правильности решений
- Референсные решения для самопроверки

**Упражнения доступны для глав 2-13** (12 проектов) и приложения A. Главы 1 и 14 содержат только текст.

## Структура проекта

```text
gleam-by-example/
├── text/                   # Исходники книги (Markdown)
│   ├── chapter01.md        # Главы 1-14
│   ├── chapter02.md
│   ├── ...
│   └── appendix_a.md       # Приложения
├── exercises/              # Упражнения (по одному Gleam-проекту на главу)
│   ├── chapter02/
│   │   ├── gleam.toml
│   │   ├── src/chapter02.gleam         # Примеры кода из текста
│   │   ├── test/
│   │   │   ├── chapter02_test.gleam    # Тесты (готовые)
│   │   │   └── my_solutions.gleam      # Шаблон для студента
│   │   └── no-peeking/
│   │       └── solutions.gleam         # Референсные решения
│   ├── ...
│   └── appendix_a/         # Упражнения для приложений
├── scripts/                # Скрипты автоматизации
│   ├── test-all.sh         # Тестирование всех глав
│   ├── build-all.sh        # Сборка всех глав + HTML книги
│   └── prepare-exercises.sh # Сброс шаблонов упражнений
├── output/                 # HTML-версия книги (генерируется mdBook)
└── book.toml              # Конфигурация mdBook
```

## Статус глав

- **Глава 1** (Введение): ✅ Текст готов (упражнений нет)
- **Главы 2-13** (Фазы 0-4): ✅ Текст и упражнения готовы
- **Глава 14** (Заключение): ✅ Текст готов (упражнений нет)
- **Приложение A** (Telegram-бот): ✅ Текст и упражнения готовы

### Особенности глав

- **Глава 8**: Erlang FFI и системное программирование
- **Глава 9**: JavaScript FFI и фронтенд интеграция (компиляция в JavaScript)
- **Глава 10**: Процессы и OTP (gleam_otp, gleam_erlang)
- **Глава 11**: Тестирование (qcheck, birdie)
- **Глава 12**: Веб-разработка с Wisp и Mist
- **Глава 13**: Фронтенд на Lustre (компиляция в JavaScript)
- **Глава 14**: Заключение и следующие шаги (только текст)
- **Приложение A**: Telegram-бот с Telega, Wisp и Mist

## Требования

- [Gleam](https://gleam.run/) >= 1.0.0
- [Erlang/OTP](https://www.erlang.org/) >= 26.0
- [mdBook](https://rust-lang.github.io/mdBook/) (для сборки HTML-версии)
- [Node.js](https://nodejs.org/) >= 18.0 (для глав 9 и 13 — компиляция в JavaScript)

### Установка Gleam

```bash
# macOS
brew install gleam

# Linux/WSL
# Следуйте инструкциям на https://gleam.run/getting-started/installing/

# Проверка установки
gleam --version
```

### Установка mdBook

```bash
# macOS
brew install mdbook

# Linux/WSL
cargo install mdbook
```

## Быстрый старт

### Просмотр книги

```bash
# Сборка HTML-версии
mdbook build

# Или запуск с автоперезагрузкой
mdbook serve
# Откройте http://localhost:3000 в браузере
```

### Работа с упражнениями

```bash
# Перейти в директорию главы
cd exercises/chapter02

# Запустить тесты (проверит ваши решения в test/my_solutions.gleam)
gleam test

# Собрать проект
gleam build

# Запустить примеры из src/chapter02.gleam
gleam run
```

### Проверка всех глав

```bash
# Тестирование всех упражнений
./scripts/test-all.sh

# Полная сборка (все главы + HTML книги)
./scripts/build-all.sh
```

## Работа с упражнениями

### Решение задач

1. Откройте `exercises/chapterXX/test/my_solutions.gleam`
2. Замените `todo` на свою реализацию функций
3. Запустите `gleam test` для проверки
4. Тесты находятся в `test/chapterXX_test.gleam` (только для чтения)

### Проверка референсных решений

```bash
cd exercises/chapterXX

# Сохранить текущие решения
cp test/my_solutions.gleam /tmp/backup.gleam

# Подставить референсные решения
cp no-peeking/solutions.gleam test/my_solutions.gleam

# Запустить тесты
gleam test

# Восстановить свои решения
cp /tmp/backup.gleam test/my_solutions.gleam
```

### Сброс упражнений

```bash
# Сбросить все шаблоны к исходному состоянию
./scripts/prepare-exercises.sh
```

## Особенности отдельных глав

### Главы 9 и 13 (JavaScript Runtime)

Эти главы компилируются в JavaScript:

```bash
# Глава 9: JavaScript FFI
cd exercises/chapter09
gleam test  # target указан в gleam.toml

# Глава 13: Lustre frontend
cd exercises/chapter13
gleam test  # target указан в gleam.toml

# Или явно указать target
gleam test --target javascript
```

### Главы 12 и Приложение A (Веб-разработка)

Эти главы используют веб-фреймворк Wisp и HTTP-сервер Mist. Приложение A дополнительно использует Telega для работы с Telegram Bot API:

```bash
# Глава 12: Web API с Wisp
cd exercises/chapter12
gleam test
gleam run  # если есть main

# Приложение A: Telegram бот
cd exercises/appendix_a
gleam test
gleam run  # запуск бота
```

## Советы и известные проблемы

### Ошибки "module not found" после перемещения проекта

Если вы скопировали или переместили папку проекта, удалите кеш сборки:

```bash
cd exercises/chapterXX
rm -rf build/dev/
gleam test
```

**Причина**: скомпилированные `.beam` файлы содержат абсолютные пути.

### Импорты в no-peeking/solutions.gleam

Файл `no-peeking/solutions.gleam` должен явно импортировать все используемые модули:

```gleam
import gleam/list
import gleam/int
import gleam/result
```

Даже если основной `src/chapterXX.gleam` их не импортирует.

## Разработка

### Добавление нового упражнения

1. Добавьте заглушку функции в `test/my_solutions.gleam`:

   ```gleam
   pub fn new_exercise(input: Int) -> Int {
     todo as "Реализуйте new_exercise"
   }
   ```

2. Добавьте тест в `test/chapterXX_test.gleam`:

   ```gleam
   pub fn new_exercise_test() {
     my_solutions.new_exercise(5)
     |> should.equal(25)
   }
   ```

3. Добавьте решение в `no-peeking/solutions.gleam`:

   ```gleam
   pub fn new_exercise(input: Int) -> Int {
     input * input
   }
   ```

4. (Опционально) Добавьте пример использования в `src/chapterXX.gleam`

### Структура тестов

- `test/chapterXX_test.gleam` — тесты импортируют `test/my_solutions.gleam`
- Студенты редактируют только `test/my_solutions.gleam`
- Референсные решения в `no-peeking/solutions.gleam` имеют идентичные сигнатуры

## Лицензия

MIT

## Благодарности

Этот проект основан на ["PureScript by Example"](https://book.purescript.org/) Phil Freeman.

Переработан для языка Gleam с адаптацией примеров и упражнений под особенности Gleam и его экосистемы.

## Полезные ссылки

- [Официальный сайт Gleam](https://gleam.run/)
- [Документация Gleam](https://gleam.run/documentation/)
- [Gleam Language Tour](https://tour.gleam.run/)
- [Пакеты Gleam](https://packages.gleam.run/)
- [Discord сообщество Gleam](https://discord.gg/Fm8Pwmy)
