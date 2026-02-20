//// Референсные решения — не подсматривайте, пока не попробуете сами!

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

// ============================================================
// Упражнение 1: PokemonId
// ============================================================

pub opaque type PokemonId {
  PokemonId(Int)
}

pub fn pokemon_id_new(id: Int) -> Result(PokemonId, String) {
  case id >= 1 && id <= 1025 {
    True -> Ok(PokemonId(id))
    False -> Error("ID должен быть от 1 до 1025")
  }
}

pub fn pokemon_id_value(id: PokemonId) -> Int {
  let PokemonId(n) = id
  n
}

pub fn pokemon_id_to_path(id: PokemonId) -> String {
  "/api/v2/pokemon/" <> int.to_string(pokemon_id_value(id))
}

// ============================================================
// Упражнение 2: Erlang FFI
// ============================================================

@external(erlang, "os", "system_time")
fn os_system_time(unit: ErlAtom) -> Int

type ErlAtom

@external(erlang, "erlang", "binary_to_atom")
fn binary_to_atom(s: String) -> ErlAtom

pub fn system_time_seconds() -> Int {
  os_system_time(binary_to_atom("second"))
}

@external(erlang, "chapter07_ffi", "get_env")
fn ffi_get_env(name: String) -> Result(String, Nil)

pub fn get_api_base_url() -> String {
  case ffi_get_env("POKEAPI_BASE_URL") {
    Ok(value) -> value
    Error(_) -> "https://pokeapi.co"
  }
}

// ============================================================
// Упражнение 3: pokemon_decoder (расширенный)
// ============================================================

pub type PokemonStat {
  PokemonStat(name: String, base_value: Int)
}

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

fn type_name_decoder() -> decode.Decoder(String) {
  use name <- decode.subfield(["type", "name"], decode.string)
  decode.success(name)
}

fn ability_name_decoder() -> decode.Decoder(String) {
  use name <- decode.subfield(["ability", "name"], decode.string)
  decode.success(name)
}

fn stat_decoder() -> decode.Decoder(PokemonStat) {
  use base_value <- decode.field("base_stat", decode.int)
  use name <- decode.subfield(["stat", "name"], decode.string)
  decode.success(PokemonStat(name:, base_value:))
}

pub fn pokemon_decoder() -> decode.Decoder(Pokemon) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use height <- decode.field("height", decode.int)
  use weight <- decode.field("weight", decode.int)
  use types <- decode.field("types", decode.list(type_name_decoder()))
  use abilities <- decode.field(
    "abilities",
    decode.list(ability_name_decoder()),
  )
  use stats <- decode.field("stats", decode.list(stat_decoder()))
  decode.success(Pokemon(
    id:,
    name:,
    height:,
    weight:,
    types:,
    abilities:,
    stats:,
  ))
}

pub fn parse_pokemon(json_str: String) -> Result(Pokemon, Nil) {
  json.parse(json_str, pokemon_decoder())
  |> result.map_error(fn(_) { Nil })
}

// ============================================================
// Упражнение 4: pokemon_to_json
// ============================================================

pub fn stat_to_json(stat: PokemonStat) -> json.Json {
  json.object([
    #("name", json.string(stat.name)),
    #("base_value", json.int(stat.base_value)),
  ])
}

pub fn pokemon_to_json(pokemon: Pokemon) -> json.Json {
  json.object([
    #("id", json.int(pokemon.id)),
    #("name", json.string(pokemon.name)),
    #("height", json.int(pokemon.height)),
    #("weight", json.int(pokemon.weight)),
    #("types", json.array(pokemon.types, json.string)),
    #("abilities", json.array(pokemon.abilities, json.string)),
    #("stats", json.array(pokemon.stats, stat_to_json)),
  ])
}

// ============================================================
// Упражнение 5: search_results_decoder
// ============================================================

pub type NamedResource {
  NamedResource(name: String, url: String)
}

pub type SearchResults {
  SearchResults(
    count: Int,
    next: Option(String),
    previous: Option(String),
    results: List(NamedResource),
  )
}

fn named_resource_decoder() -> decode.Decoder(NamedResource) {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)
  decode.success(NamedResource(name:, url:))
}

fn search_results_decoder() -> decode.Decoder(SearchResults) {
  use count <- decode.field("count", decode.int)
  use next <- decode.field("next", decode.optional(decode.string))
  use previous <- decode.field("previous", decode.optional(decode.string))
  use results <- decode.field("results", decode.list(named_resource_decoder()))
  decode.success(SearchResults(count:, next:, previous:, results:))
}

pub fn decode_search_results(json_str: String) -> Result(SearchResults, Nil) {
  json.parse(json_str, search_results_decoder())
  |> result.map_error(fn(_) { Nil })
}

// ============================================================
// Упражнение 6: DamageMultiplier — фантомные типы
// ============================================================

pub type Physical

pub type Special

pub opaque type DamageMultiplier(category) {
  DamageMultiplier(Float)
}

pub fn physical(value: Float) -> Result(DamageMultiplier(Physical), String) {
  case value >=. 0.0 {
    True -> Ok(DamageMultiplier(value))
    False -> Error("множитель не может быть отрицательным")
  }
}

pub fn special(value: Float) -> Result(DamageMultiplier(Special), String) {
  case value >=. 0.0 {
    True -> Ok(DamageMultiplier(value))
    False -> Error("множитель не может быть отрицательным")
  }
}

pub fn multiplier_value(m: DamageMultiplier(a)) -> Float {
  let DamageMultiplier(v) = m
  v
}

pub fn combine(
  a: DamageMultiplier(category),
  b: DamageMultiplier(category),
) -> DamageMultiplier(category) {
  DamageMultiplier(multiplier_value(a) *. multiplier_value(b))
}

pub fn apply_damage(base: Int, m: DamageMultiplier(a)) -> Int {
  float.truncate(int.to_float(base) *. multiplier_value(m))
}

// ============================================================
// Упражнение 7: format_pokemon_card
// ============================================================

fn pad_right(s: String, length: Int) -> String {
  let pad = length - string.length(s)
  case pad > 0 {
    True -> s <> string.repeat(" ", pad)
    False -> s
  }
}

fn pad_left_zeros(n: Int, length: Int) -> String {
  let s = int.to_string(n)
  let pad = length - string.length(s)
  case pad > 0 {
    True -> string.repeat("0", pad) <> s
    False -> s
  }
}

fn capitalize(s: String) -> String {
  case string.pop_grapheme(s) {
    Ok(#(first, rest)) -> string.uppercase(first) <> rest
    Error(_) -> s
  }
}

pub fn format_pokemon_card(pokemon: Pokemon) -> String {
  let id_str = "#" <> pad_left_zeros(pokemon.id, 3)
  let name = capitalize(pokemon.name)
  let types = string.join(pokemon.types, ", ")
  let abilities = string.join(pokemon.abilities, ", ")
  id_str
  <> " "
  <> name
  <> "\n"
  <> "Тип: "
  <> types
  <> "\n"
  <> "Способности: "
  <> abilities
}

pub fn format_stat_bar(stat: PokemonStat) -> String {
  let name = pad_right(stat.name, 16)
  let filled = float.round(int.to_float(stat.base_value) *. 15.0 /. 255.0)
  let filled = int.min(filled, 15) |> int.max(0)
  let empty = 15 - filled
  let bar =
    "[" <> string.repeat("#", filled) <> string.repeat(".", empty) <> "]"
  name <> bar <> " " <> int.to_string(stat.base_value)
}

// ============================================================
// Упражнение 8: build_pokedex_entry — ROP-цепочка
// ============================================================

pub type PokedexError {
  InvalidJson
  InvalidPokemonId
  MissingTypes
  MissingAbilities
}

pub fn build_pokedex_entry(json_str: String) -> Result(String, PokedexError) {
  use pokemon <- result.try(
    parse_pokemon(json_str)
    |> result.map_error(fn(_) { InvalidJson }),
  )
  use _ <- result.try(case pokemon.id >= 1 && pokemon.id <= 1025 {
    True -> Ok(Nil)
    False -> Error(InvalidPokemonId)
  })
  use _ <- result.try(case list.is_empty(pokemon.types) {
    True -> Error(MissingTypes)
    False -> Ok(Nil)
  })
  use _ <- result.try(case list.is_empty(pokemon.abilities) {
    True -> Error(MissingAbilities)
    False -> Ok(Nil)
  })
  Ok(format_pokemon_card(pokemon))
}
