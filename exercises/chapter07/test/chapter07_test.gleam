import gleam/json
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import my_solutions

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================
// Упражнение 1: PokemonId
// ============================================================

pub fn pokemon_id_new_ok_test() {
  my_solutions.pokemon_id_new(25)
  |> should.be_ok
}

pub fn pokemon_id_new_min_test() {
  my_solutions.pokemon_id_new(1)
  |> should.be_ok
}

pub fn pokemon_id_new_max_test() {
  my_solutions.pokemon_id_new(1025)
  |> should.be_ok
}

pub fn pokemon_id_new_zero_error_test() {
  my_solutions.pokemon_id_new(0)
  |> should.be_error
}

pub fn pokemon_id_new_negative_error_test() {
  my_solutions.pokemon_id_new(-1)
  |> should.be_error
}

pub fn pokemon_id_new_too_large_error_test() {
  my_solutions.pokemon_id_new(1026)
  |> should.be_error
}

pub fn pokemon_id_value_test() {
  let assert Ok(id) = my_solutions.pokemon_id_new(25)
  my_solutions.pokemon_id_value(id)
  |> should.equal(25)
}

pub fn pokemon_id_to_path_test() {
  let assert Ok(id) = my_solutions.pokemon_id_new(25)
  my_solutions.pokemon_id_to_path(id)
  |> should.equal("/api/v2/pokemon/25")
}

pub fn pokemon_id_to_path_first_test() {
  let assert Ok(id) = my_solutions.pokemon_id_new(1)
  my_solutions.pokemon_id_to_path(id)
  |> should.equal("/api/v2/pokemon/1")
}

// ============================================================
// Упражнение 2: Erlang FFI
// ============================================================

pub fn system_time_test() {
  let time = my_solutions.system_time_seconds()
  // Время должно быть больше 2024-01-01 в секундах
  { time > 1_704_067_200 }
  |> should.be_true
}

pub fn get_api_base_url_default_test() {
  // Если POKEAPI_BASE_URL не установлена, возвращает дефолт
  let url = my_solutions.get_api_base_url()
  { string.contains(url, "pokeapi") }
  |> should.be_true
}

// ============================================================
// Упражнение 3: pokemon_decoder (расширенный)
// ============================================================

fn pikachu_json() -> String {
  "{
    \"id\": 25,
    \"name\": \"pikachu\",
    \"height\": 4,
    \"weight\": 60,
    \"types\": [
      {\"slot\": 1, \"type\": {\"name\": \"electric\", \"url\": \"https://pokeapi.co/api/v2/type/13/\"}}
    ],
    \"abilities\": [
      {\"ability\": {\"name\": \"static\", \"url\": \"\"}, \"is_hidden\": false, \"slot\": 1},
      {\"ability\": {\"name\": \"lightning-rod\", \"url\": \"\"}, \"is_hidden\": true, \"slot\": 3}
    ],
    \"stats\": [
      {\"base_stat\": 35, \"effort\": 0, \"stat\": {\"name\": \"hp\", \"url\": \"\"}},
      {\"base_stat\": 55, \"effort\": 0, \"stat\": {\"name\": \"attack\", \"url\": \"\"}},
      {\"base_stat\": 40, \"effort\": 0, \"stat\": {\"name\": \"defense\", \"url\": \"\"}},
      {\"base_stat\": 50, \"effort\": 0, \"stat\": {\"name\": \"special-attack\", \"url\": \"\"}},
      {\"base_stat\": 50, \"effort\": 0, \"stat\": {\"name\": \"special-defense\", \"url\": \"\"}},
      {\"base_stat\": 90, \"effort\": 2, \"stat\": {\"name\": \"speed\", \"url\": \"\"}}
    ]
  }"
}

fn charizard_json() -> String {
  "{
    \"id\": 6,
    \"name\": \"charizard\",
    \"height\": 17,
    \"weight\": 905,
    \"types\": [
      {\"slot\": 1, \"type\": {\"name\": \"fire\", \"url\": \"\"}},
      {\"slot\": 2, \"type\": {\"name\": \"flying\", \"url\": \"\"}}
    ],
    \"abilities\": [
      {\"ability\": {\"name\": \"blaze\", \"url\": \"\"}, \"is_hidden\": false, \"slot\": 1},
      {\"ability\": {\"name\": \"solar-power\", \"url\": \"\"}, \"is_hidden\": true, \"slot\": 3}
    ],
    \"stats\": [
      {\"base_stat\": 78, \"effort\": 0, \"stat\": {\"name\": \"hp\", \"url\": \"\"}},
      {\"base_stat\": 84, \"effort\": 0, \"stat\": {\"name\": \"attack\", \"url\": \"\"}},
      {\"base_stat\": 78, \"effort\": 0, \"stat\": {\"name\": \"defense\", \"url\": \"\"}},
      {\"base_stat\": 109, \"effort\": 3, \"stat\": {\"name\": \"special-attack\", \"url\": \"\"}},
      {\"base_stat\": 85, \"effort\": 0, \"stat\": {\"name\": \"special-defense\", \"url\": \"\"}},
      {\"base_stat\": 100, \"effort\": 0, \"stat\": {\"name\": \"speed\", \"url\": \"\"}}
    ]
  }"
}

pub fn pokemon_decoder_pikachu_test() {
  my_solutions.parse_pokemon(pikachu_json())
  |> should.equal(
    Ok(my_solutions.Pokemon(
      id: 25,
      name: "pikachu",
      height: 4,
      weight: 60,
      types: ["electric"],
      abilities: ["static", "lightning-rod"],
      stats: [
        my_solutions.PokemonStat("hp", 35),
        my_solutions.PokemonStat("attack", 55),
        my_solutions.PokemonStat("defense", 40),
        my_solutions.PokemonStat("special-attack", 50),
        my_solutions.PokemonStat("special-defense", 50),
        my_solutions.PokemonStat("speed", 90),
      ],
    )),
  )
}

pub fn pokemon_decoder_charizard_test() {
  my_solutions.parse_pokemon(charizard_json())
  |> should.equal(
    Ok(my_solutions.Pokemon(
      id: 6,
      name: "charizard",
      height: 17,
      weight: 905,
      types: ["fire", "flying"],
      abilities: ["blaze", "solar-power"],
      stats: [
        my_solutions.PokemonStat("hp", 78),
        my_solutions.PokemonStat("attack", 84),
        my_solutions.PokemonStat("defense", 78),
        my_solutions.PokemonStat("special-attack", 109),
        my_solutions.PokemonStat("special-defense", 85),
        my_solutions.PokemonStat("speed", 100),
      ],
    )),
  )
}

pub fn pokemon_decoder_error_test() {
  my_solutions.parse_pokemon("not json")
  |> should.be_error
}

// ============================================================
// Упражнение 4: pokemon_to_json
// ============================================================

pub fn stat_to_json_test() {
  my_solutions.stat_to_json(my_solutions.PokemonStat("hp", 35))
  |> json.to_string
  |> should.equal("{\"name\":\"hp\",\"base_value\":35}")
}

pub fn pokemon_to_json_test() {
  let pokemon =
    my_solutions.Pokemon(
      id: 25,
      name: "pikachu",
      height: 4,
      weight: 60,
      types: ["electric"],
      abilities: ["static", "lightning-rod"],
      stats: [my_solutions.PokemonStat("hp", 35)],
    )

  let result = my_solutions.pokemon_to_json(pokemon) |> json.to_string

  // Проверяем наличие всех полей
  { string.contains(result, "\"id\":25") }
  |> should.be_true
  { string.contains(result, "\"name\":\"pikachu\"") }
  |> should.be_true
  { string.contains(result, "\"height\":4") }
  |> should.be_true
  { string.contains(result, "\"weight\":60") }
  |> should.be_true
  { string.contains(result, "\"types\":[\"electric\"]") }
  |> should.be_true
  { string.contains(result, "\"abilities\":[\"static\",\"lightning-rod\"]") }
  |> should.be_true
  { string.contains(result, "\"stats\":[{\"name\":\"hp\",\"base_value\":35}]") }
  |> should.be_true
}

pub fn pokemon_to_json_multiple_types_test() {
  let pokemon =
    my_solutions.Pokemon(
      id: 6,
      name: "charizard",
      height: 17,
      weight: 905,
      types: ["fire", "flying"],
      abilities: ["blaze", "solar-power"],
      stats: [
        my_solutions.PokemonStat("hp", 78),
        my_solutions.PokemonStat("attack", 84),
      ],
    )

  let result = my_solutions.pokemon_to_json(pokemon) |> json.to_string

  { string.contains(result, "charizard") }
  |> should.be_true
  { string.contains(result, "\"types\":[\"fire\",\"flying\"]") }
  |> should.be_true
}

// ============================================================
// Упражнение 5: search_results_decoder
// ============================================================

pub fn search_results_first_page_test() {
  let json_str =
    "{
    \"count\": 1302,
    \"next\": \"https://pokeapi.co/api/v2/pokemon?offset=20&limit=20\",
    \"previous\": null,
    \"results\": [
      {\"name\": \"bulbasaur\", \"url\": \"https://pokeapi.co/api/v2/pokemon/1/\"},
      {\"name\": \"ivysaur\", \"url\": \"https://pokeapi.co/api/v2/pokemon/2/\"}
    ]
  }"

  my_solutions.decode_search_results(json_str)
  |> should.equal(
    Ok(my_solutions.SearchResults(
      count: 1302,
      next: option.Some(
        "https://pokeapi.co/api/v2/pokemon?offset=20&limit=20",
      ),
      previous: option.None,
      results: [
        my_solutions.NamedResource(
          "bulbasaur",
          "https://pokeapi.co/api/v2/pokemon/1/",
        ),
        my_solutions.NamedResource(
          "ivysaur",
          "https://pokeapi.co/api/v2/pokemon/2/",
        ),
      ],
    )),
  )
}

pub fn search_results_middle_page_test() {
  let json_str =
    "{
    \"count\": 1302,
    \"next\": \"https://pokeapi.co/api/v2/pokemon?offset=40&limit=20\",
    \"previous\": \"https://pokeapi.co/api/v2/pokemon?offset=0&limit=20\",
    \"results\": [
      {\"name\": \"spearow\", \"url\": \"https://pokeapi.co/api/v2/pokemon/21/\"}
    ]
  }"

  my_solutions.decode_search_results(json_str)
  |> should.equal(
    Ok(my_solutions.SearchResults(
      count: 1302,
      next: option.Some(
        "https://pokeapi.co/api/v2/pokemon?offset=40&limit=20",
      ),
      previous: option.Some(
        "https://pokeapi.co/api/v2/pokemon?offset=0&limit=20",
      ),
      results: [
        my_solutions.NamedResource(
          "spearow",
          "https://pokeapi.co/api/v2/pokemon/21/",
        ),
      ],
    )),
  )
}

pub fn search_results_empty_test() {
  let json_str =
    "{
    \"count\": 0,
    \"next\": null,
    \"previous\": null,
    \"results\": []
  }"

  my_solutions.decode_search_results(json_str)
  |> should.equal(
    Ok(my_solutions.SearchResults(
      count: 0,
      next: option.None,
      previous: option.None,
      results: [],
    )),
  )
}

pub fn search_results_invalid_json_test() {
  my_solutions.decode_search_results("invalid")
  |> should.be_error
}

// ============================================================
// Упражнение 6: DamageMultiplier — фантомные типы
// ============================================================

pub fn physical_ok_test() {
  my_solutions.physical(1.5)
  |> should.be_ok
}

pub fn physical_zero_ok_test() {
  my_solutions.physical(0.0)
  |> should.be_ok
}

pub fn physical_negative_error_test() {
  my_solutions.physical(-0.5)
  |> should.be_error
}

pub fn special_ok_test() {
  my_solutions.special(2.0)
  |> should.be_ok
}

pub fn special_negative_error_test() {
  my_solutions.special(-1.0)
  |> should.be_error
}

pub fn multiplier_value_test() {
  let assert Ok(m) = my_solutions.physical(1.5)
  my_solutions.multiplier_value(m)
  |> should.equal(1.5)
}

pub fn combine_physical_test() {
  let assert Ok(a) = my_solutions.physical(1.5)
  let assert Ok(b) = my_solutions.physical(2.0)
  my_solutions.combine(a, b)
  |> my_solutions.multiplier_value
  |> should.equal(3.0)
}

pub fn combine_special_test() {
  let assert Ok(a) = my_solutions.special(0.5)
  let assert Ok(b) = my_solutions.special(4.0)
  my_solutions.combine(a, b)
  |> my_solutions.multiplier_value
  |> should.equal(2.0)
}

pub fn apply_damage_test() {
  let assert Ok(m) = my_solutions.physical(1.5)
  my_solutions.apply_damage(100, m)
  |> should.equal(150)
}

pub fn apply_damage_special_test() {
  let assert Ok(m) = my_solutions.special(2.0)
  my_solutions.apply_damage(80, m)
  |> should.equal(160)
}

pub fn apply_damage_zero_multiplier_test() {
  let assert Ok(m) = my_solutions.physical(0.0)
  my_solutions.apply_damage(100, m)
  |> should.equal(0)
}

// ============================================================
// Упражнение 7: format_pokemon_card
// ============================================================

pub fn format_pokemon_card_pikachu_test() {
  let pokemon =
    my_solutions.Pokemon(
      id: 25,
      name: "pikachu",
      height: 4,
      weight: 60,
      types: ["electric"],
      abilities: ["static", "lightning-rod"],
      stats: [],
    )

  my_solutions.format_pokemon_card(pokemon)
  |> should.equal(
    "#025 Pikachu\nТип: electric\nСпособности: static, lightning-rod",
  )
}

pub fn format_pokemon_card_charizard_test() {
  let pokemon =
    my_solutions.Pokemon(
      id: 6,
      name: "charizard",
      height: 17,
      weight: 905,
      types: ["fire", "flying"],
      abilities: ["blaze", "solar-power"],
      stats: [],
    )

  my_solutions.format_pokemon_card(pokemon)
  |> should.equal(
    "#006 Charizard\nТип: fire, flying\nСпособности: blaze, solar-power",
  )
}

pub fn format_pokemon_card_high_id_test() {
  let pokemon =
    my_solutions.Pokemon(
      id: 1025,
      name: "pecharunt",
      height: 3,
      weight: 3,
      types: ["poison", "ghost"],
      abilities: ["poison-puppeteer"],
      stats: [],
    )

  my_solutions.format_pokemon_card(pokemon)
  |> should.equal(
    "#1025 Pecharunt\nТип: poison, ghost\nСпособности: poison-puppeteer",
  )
}

pub fn format_stat_bar_hp_test() {
  my_solutions.format_stat_bar(my_solutions.PokemonStat("hp", 35))
  |> should.equal("hp              [##.............] 35")
}

pub fn format_stat_bar_speed_test() {
  my_solutions.format_stat_bar(my_solutions.PokemonStat("speed", 90))
  |> should.equal("speed           [#####..........] 90")
}

pub fn format_stat_bar_max_test() {
  my_solutions.format_stat_bar(my_solutions.PokemonStat("hp", 255))
  |> should.equal("hp              [###############] 255")
}

pub fn format_stat_bar_zero_test() {
  my_solutions.format_stat_bar(my_solutions.PokemonStat("speed", 0))
  |> should.equal("speed           [...............] 0")
}

// ============================================================
// Упражнение 8: build_pokedex_entry
// ============================================================

pub fn build_pokedex_entry_ok_test() {
  let result = my_solutions.build_pokedex_entry(pikachu_json())
  result |> should.be_ok
  let assert Ok(entry) = result
  { string.contains(entry, "#025 Pikachu") }
  |> should.be_true
  { string.contains(entry, "electric") }
  |> should.be_true
}

pub fn build_pokedex_entry_invalid_json_test() {
  my_solutions.build_pokedex_entry("not json")
  |> should.equal(Error(my_solutions.InvalidJson))
}

pub fn build_pokedex_entry_invalid_id_test() {
  let json_str =
    "{
    \"id\": 99999,
    \"name\": \"fakemon\",
    \"height\": 1,
    \"weight\": 1,
    \"types\": [{\"slot\": 1, \"type\": {\"name\": \"normal\", \"url\": \"\"}}],
    \"abilities\": [{\"ability\": {\"name\": \"run-away\", \"url\": \"\"}, \"is_hidden\": false, \"slot\": 1}],
    \"stats\": [{\"base_stat\": 50, \"effort\": 0, \"stat\": {\"name\": \"hp\", \"url\": \"\"}}]
  }"

  my_solutions.build_pokedex_entry(json_str)
  |> should.equal(Error(my_solutions.InvalidPokemonId))
}

pub fn build_pokedex_entry_missing_types_test() {
  let json_str =
    "{
    \"id\": 25,
    \"name\": \"pikachu\",
    \"height\": 4,
    \"weight\": 60,
    \"types\": [],
    \"abilities\": [{\"ability\": {\"name\": \"static\", \"url\": \"\"}, \"is_hidden\": false, \"slot\": 1}],
    \"stats\": [{\"base_stat\": 35, \"effort\": 0, \"stat\": {\"name\": \"hp\", \"url\": \"\"}}]
  }"

  my_solutions.build_pokedex_entry(json_str)
  |> should.equal(Error(my_solutions.MissingTypes))
}

pub fn build_pokedex_entry_missing_abilities_test() {
  let json_str =
    "{
    \"id\": 25,
    \"name\": \"pikachu\",
    \"height\": 4,
    \"weight\": 60,
    \"types\": [{\"slot\": 1, \"type\": {\"name\": \"electric\", \"url\": \"\"}}],
    \"abilities\": [],
    \"stats\": [{\"base_stat\": 35, \"effort\": 0, \"stat\": {\"name\": \"hp\", \"url\": \"\"}}]
  }"

  my_solutions.build_pokedex_entry(json_str)
  |> should.equal(Error(my_solutions.MissingAbilities))
}
