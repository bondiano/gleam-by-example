import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string

/// Пример: opaque type с валидацией
pub opaque type Email {
  Email(String)
}

pub fn parse_email(s: String) -> Result(Email, String) {
  case string.contains(s, "@") {
    True -> Ok(Email(s))
    False -> Error("некорректный email")
  }
}

pub fn email_to_string(email: Email) -> String {
  let Email(s) = email
  s
}

/// Пример: тип User для JSON
pub type User {
  User(name: String, age: Int)
}

/// Пример: JSON encoder
pub fn user_to_json(user: User) -> json.Json {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
  ])
}

/// Пример: JSON decoder
pub fn user_decoder() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(User(name:, age:))
}

/// Пример: фантомный тип DamageMultiplier
pub opaque type DamageMultiplier(category) {
  DamageMultiplier(Float)
}

pub type Physical

pub type Special

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

pub fn apply_damage(base: Int, m: DamageMultiplier(a)) -> Int {
  float.truncate(int.to_float(base) *. multiplier_value(m))
}

/// Пример: opaque type PokemonId (smart constructor)
pub opaque type PokemonId {
  PokemonId(Int)
}

pub fn pokemon_id(n: Int) -> Result(PokemonId, String) {
  case n >= 1 && n <= 1025 {
    True -> Ok(PokemonId(n))
    False -> Error("ID должен быть от 1 до 1025")
  }
}

pub fn pokemon_id_value(p: PokemonId) -> Int {
  let PokemonId(n) = p
  n
}

/// Пример: расширенный Pokemon decoder
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

/// Пример: ROP-цепочка для PokeDex
pub type PokedexError {
  InvalidJson
  InvalidPokemonId
  MissingTypes
}

pub fn build_pokedex_entry(json_str: String) -> Result(Pokemon, PokedexError) {
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
  Ok(pokemon)
}
