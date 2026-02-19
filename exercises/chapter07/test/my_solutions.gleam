//// Здесь вы можете писать свои решения упражнений.
//// Тема: PokeDex CLI — все упражнения складываются в мини-приложение.

import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}

// ============================================================
// Упражнение 1: PokemonId — opaque type + smart constructor
// ============================================================

/// Непрозрачный тип для ID покемона (1–1025).
pub opaque type PokemonId {
  PokemonId(Int)
}

/// Создаёт PokemonId из Int. Ошибка, если id вне диапазона 1–1025.
pub fn pokemon_id_new(id: Int) -> Result(PokemonId, String) {
  todo
}

/// Извлекает числовое значение из PokemonId.
pub fn pokemon_id_value(id: PokemonId) -> Int {
  todo
}

/// Формирует путь API: "/api/v2/pokemon/<id>".
pub fn pokemon_id_to_path(id: PokemonId) -> String {
  todo
}

// ============================================================
// Упражнение 2: Erlang FFI — время и окружение
// ============================================================

/// Возвращает текущее время в секундах через FFI к Erlang.
pub fn system_time_seconds() -> Int {
  todo
}

/// Получает POKEAPI_BASE_URL из окружения или возвращает
/// "https://pokeapi.co" по умолчанию.
pub fn get_api_base_url() -> String {
  todo
}

// ============================================================
// Упражнение 3: pokemon_decoder — расширенный декодер
// ============================================================

/// Стата покемона.
pub type PokemonStat {
  PokemonStat(name: String, base_value: Int)
}

/// Покемон из PokeAPI (расширенная версия).
pub type Pokemon {
  Pokemon(
    id: Int,
    name: String,
    height: Int,
    weight: Int,
    types: List(String),
    abilities: List(String),
    stats: List(PokemonStat),
  )
}

/// Декодер для Pokemon.
pub fn pokemon_decoder() -> decode.Decoder(Pokemon) {
  todo
}

/// Парсит JSON-строку PokeAPI ответа в Pokemon.
pub fn parse_pokemon(json_str: String) -> Result(Pokemon, Nil) {
  todo
}

// ============================================================
// Упражнение 4: pokemon_to_json — кодирование в JSON
// ============================================================

/// Кодирует PokemonStat в JSON.
pub fn stat_to_json(stat: PokemonStat) -> json.Json {
  todo
}

/// Кодирует Pokemon в компактный JSON (для кеширования).
pub fn pokemon_to_json(pokemon: Pokemon) -> json.Json {
  todo
}

// ============================================================
// Упражнение 5: search_results_decoder — пагинированный список
// ============================================================

/// Именованный ресурс из PokeAPI.
pub type NamedResource {
  NamedResource(name: String, url: String)
}

/// Результаты поиска с пагинацией.
pub type SearchResults {
  SearchResults(
    count: Int,
    next: Option(String),
    previous: Option(String),
    results: List(NamedResource),
  )
}

/// Декодирует JSON результатов поиска PokeAPI.
pub fn decode_search_results(
  json_str: String,
) -> Result(SearchResults, Nil) {
  todo
}

// ============================================================
// Упражнение 6: DamageMultiplier — фантомные типы
// ============================================================

/// Фантомный маркер для физических атак.
pub type Physical

/// Фантомный маркер для специальных атак.
pub type Special

/// Множитель урона с категорией (Physical / Special).
pub opaque type DamageMultiplier(category) {
  DamageMultiplier(Float)
}

/// Создаёт физический множитель. Значение >= 0.0.
pub fn physical(value: Float) -> Result(DamageMultiplier(Physical), String) {
  todo
}

/// Создаёт специальный множитель. Значение >= 0.0.
pub fn special(value: Float) -> Result(DamageMultiplier(Special), String) {
  todo
}

/// Извлекает числовое значение множителя.
pub fn multiplier_value(m: DamageMultiplier(a)) -> Float {
  todo
}

/// Комбинирует два множителя одной категории (умножением).
pub fn combine(
  a: DamageMultiplier(category),
  b: DamageMultiplier(category),
) -> DamageMultiplier(category) {
  todo
}

/// Применяет множитель к базовому урону.
pub fn apply_damage(base: Int, m: DamageMultiplier(a)) -> Int {
  todo
}

// ============================================================
// Упражнение 7: format_pokemon_card — CLI-вывод
// ============================================================

/// Форматирует карточку покемона для CLI.
/// Формат:
///   #025 Pikachu
///   Тип: electric
///   Способности: static, lightning-rod
pub fn format_pokemon_card(pokemon: Pokemon) -> String {
  todo
}

/// Форматирует стат-бар для CLI.
/// Формат: "hp              [##.............] 35"
/// Имя — 16 символов (дополнено пробелами), бар — 15 символов, значение в конце.
pub fn format_stat_bar(stat: PokemonStat) -> String {
  todo
}

// ============================================================
// Упражнение 8: build_pokedex_entry — ROP-цепочка
// ============================================================

/// Ошибки при построении записи PokeDex.
pub type PokedexError {
  InvalidJson
  InvalidPokemonId
  MissingTypes
  MissingAbilities
}

/// Строит запись PokeDex из JSON-строки.
/// Цепочка: parse JSON → validate ID (1–1025) → validate types → validate abilities → format card.
pub fn build_pokedex_entry(
  json_str: String,
) -> Result(String, PokedexError) {
  todo
}
