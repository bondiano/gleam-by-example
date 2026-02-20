# Gleam by Example

Образовательная книга по языку программирования [Gleam](https://gleam.run/), написанная на русском языке. Проект является адаптацией "PureScript by Example" и предназначен для пошагового изучения Gleam через практические примеры и упражнения.

## Описание

**Gleam by Example** — это интерактивная книга, состоящая из 14 глав и приложений, каждая из которых содержит:

- Теоретический материал с примерами кода
- Практические упражнения для закрепления материала
- Тесты для проверки правильности решений
- Референсные решения для самопроверки

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

- **Главы 1-7** (Фазы 0-2): ✅ Текст и упражнения готовы
- **Главы 8-9** (Фаза 3): ⚠️ Упражнения готовы, текст — заглушки
- **Главы 10-14** (Фаза 4): ✅ Текст и упражнения готовы
- **Приложение A**: ✅ Telegram-бот — текст и упражнения готовы

### Особенности глав

- **Глава 10**: Процессы и OTP (gleam_otp, gleam_erlang)
- **Глава 11**: Тестирование
- **Глава 12**: Веб-разработка с Wisp и Mist
- **Глава 13**: Фронтенд на Lustre (компиляция в JavaScript)
- **Глава 14**: Заключение и следующие шаги
- **Приложение A**: Telegram-бот с Telega и Wisp

## Требования

- [Gleam](https://gleam.run/) >= 1.0.0
- [Erlang/OTP](https://www.erlang.org/) >= 26.0
- [mdBook](https://rust-lang.github.io/mdBook/) (для сборки HTML-версии)
- [Node.js](https://nodejs.org/) >= 18.0 (для главы 11, компиляция в JavaScript)

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

### Глава 13 (Lustre/JavaScript)

Эта глава компилируется в JavaScript:

```bash
cd exercises/chapter13

# Тесты запускаются на JavaScript Runtime
gleam test --target javascript

# Или просто (target указан в gleam.toml)
gleam test
```

### Глава 12 и Приложение A (Веб-разработка)

Эти главы используют веб-фреймворк Wisp и HTTP-сервер Mist:

```bash
cd exercises/chapter12
# или
cd exercises/appendix_a

# Запуск тестов
gleam test

# Запуск веб-сервера (если есть main)
gleam run
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
