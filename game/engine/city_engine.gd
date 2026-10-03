## The one interface the game uses to talk to a city simulation.
##
## MicropolisCityEngine implements it over MicropolisCore's C++ engine; a
## GDScript engine will implement it in Phase 2. The game holds a CityEngine and
## never touches an implementation's own class.
##
## Signals are emitted synchronously, from inside the call that caused them
## (tick, do_tool, load_scenario, ...). Handlers shouldn't call back into the
## engine while one is running.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
@abstract
class_name CityEngine
extends RefCounted

## Map size in tiles.
const MAP_WIDTH := 120
const MAP_HEIGHT := 100
## Tile indices run from 0 to TILE_COUNT - 1.
const TILE_COUNT := 1024
## Low 10 bits of a tile value: the tile index. The rest are flags.
const TILE_INDEX_MASK := 0x03ff
const TILE_ZONE_BIT := 0x0400
const TILE_ANIM_BIT := 0x0800
const TILE_BULLDOZABLE_BIT := 0x1000
const TILE_BURNABLE_BIT := 0x2000
const TILE_CONDUCTIVE_BIT := 0x4000
const TILE_POWERED_BIT := 0x8000
## The engine's number of history entries per graph and scale.
const HISTORY_LENGTH := 120

enum Tool {
	RESIDENTIAL, COMMERCIAL, INDUSTRIAL, FIRE_STATION, POLICE_STATION, QUERY,
	WIRE, BULLDOZER, RAILROAD, ROAD, STADIUM, PARK, SEAPORT, COAL_POWER,
	NUCLEAR_POWER, AIRPORT, NETWORK, WATER, LAND, FOREST,
}
enum ToolResult { NO_MONEY = -2, NEED_BULLDOZE = -1, FAILED = 0, OK = 1 }
enum Scenario {
	NONE, DULLSVILLE, SAN_FRANCISCO, HAMBURG, BERN, TOKYO, DETROIT, BOSTON, RIO,
}
enum HistoryType { RESIDENTIAL, COMMERCIAL, INDUSTRIAL, MONEY, CRIME, POLLUTION }
## SHORT is the last 10 years, LONG the last 120.
enum HistoryScale { SHORT, LONG }
enum Overlay {
	POPULATION_DENSITY, TRAFFIC_DENSITY, POLLUTION, LAND_VALUE, CRIME,
	TERRAIN_DENSITY, POWER_GRID, RATE_OF_GROWTH, FIRE_COVERAGE, POLICE_COVERAGE,
	COMMERCIAL_RATE,
}
enum Problem { CRIME, POLLUTION, HOUSING, TAXES, TRAFFIC, UNEMPLOYMENT, FIRE }
## The engine's moving things. Images: content images/sprite_<type>_<frame - 1>.png.
enum SpriteType { NONE, TRAIN, HELICOPTER, AIRPLANE, SHIP, MONSTER, TORNADO, EXPLOSION, BUS }

# The front end's signals, one per engine callback.
signal funds_changed(funds: int)
signal date_changed(year: int, month: int)
signal demand_changed(residential: float, commercial: float, industrial: float)
## index is a message number (the engine's text.h; strings in content/data).
## A picture message that repeats the last one isn't sent, as 1989's SendMes
## did, unless an important message came in between (local edit 7).
signal message_sent(index: int, x: int, y: int, picture: bool, important: bool)
## The yearly budget wants the player (auto-budget off), or request_budget().
signal budget_requested
## The Query tool's report on the zone at (x, y).
signal zone_status_shown(category: int, population_density: int, land_value: int, crime: int, pollution: int, growth: int, x: int, y: int)
## x and y are -1 for a sound everywhere.
signal sound_requested(channel: String, sound: String, x: int, y: int)
## Pan the map to (x, y): a message with a place, with auto-goto on.
signal auto_goto_requested(x: int, y: int, message: String)
signal city_loaded(path: String)
signal scenario_loaded(name: String, path: String)
signal city_load_failed(path: String)
signal city_saved(path: String)
signal city_save_failed(path: String)
signal save_city_as_requested(path: String)
signal map_generated(seed: int)
signal new_game_requested
signal game_started
signal scenario_started(scenario: int)
signal game_won
signal game_lost
signal tool_applied(name: String, x: int, y: int)
signal earthquake_started(strength: int)
signal budget_changed
signal tax_rate_changed(rate: int)
signal evaluation_changed
signal history_changed
signal map_changed
signal options_changed
signal city_name_changed(name: String)
signal game_level_changed(level: int)
signal speed_changed(speed: int)
signal paused_changed(paused: bool)
signal passes_changed(passes: int)


# Cities -------------------------------------------------------------------

## Loads one of the 8 scenarios. False if it's out of range or the content is
## missing.
@abstract func load_scenario(scenario: Scenario) -> bool
## Loads a .cty file: absolute, res:// or user://, or relative to the content
## folder (e.g. "cities/haight.cty").
@abstract func load_city(path: String) -> bool
@abstract func save_city(path: String) -> bool
## A new city on terrain generated from the seed.
@abstract func generate_map(seed: int) -> void
@abstract func generate_random_map() -> void
## Seeds the random numbers now. Every load reseeds them, so call it after one.
@abstract func seed_random(seed: int) -> void
## Makes every later load and generated map start its random numbers from seed
## instead of the clock, so two runs of a city are identical. Tests and the
## reference snapshots use it; play uses the clock.
@abstract func set_fixed_seed(seed: int) -> void
## Goes back to seeding from the clock on every load.
@abstract func clear_fixed_seed() -> void

# Simulation ---------------------------------------------------------------

## One step of the simulation at the current speed; does nothing at speed 0.
@abstract func tick() -> void
## 0 (stopped) to 3 (fast).
@abstract func set_speed(speed: int) -> void
## The chosen speed, which pausing keeps.
@abstract func get_speed() -> int
@abstract func pause() -> void
@abstract func resume() -> void
@abstract func is_paused() -> bool
## Simulation passes per tick.
@abstract func set_passes(passes: int) -> void
@abstract func get_passes() -> int

# Numbers ------------------------------------------------------------------

@abstract func get_funds() -> int
@abstract func set_funds(funds: int) -> void
## Weeks since 1900: 48 a year.
@abstract func get_city_time() -> int
@abstract func get_year() -> int
## 0 (January) to 11.
@abstract func get_month() -> int
@abstract func get_population() -> int
@abstract func get_residential_population() -> int
@abstract func get_commercial_population() -> int
@abstract func get_industrial_population() -> int
## The R, C and I demand valves, about -2000 to 2000.
@abstract func get_demand() -> Vector3i
@abstract func get_city_name() -> String
@abstract func set_city_name(name: String) -> void
## 0 (easy) to 2 (hard).
@abstract func get_game_level() -> int
@abstract func set_game_level(level: int) -> void
@abstract func get_scenario() -> int

# Options ------------------------------------------------------------------

@abstract func set_disasters_enabled(enabled: bool) -> void
@abstract func get_disasters_enabled() -> bool
@abstract func set_auto_budget(enabled: bool) -> void
@abstract func get_auto_budget() -> bool
@abstract func set_auto_bulldoze(enabled: bool) -> void
@abstract func get_auto_bulldoze() -> bool
@abstract func set_auto_goto(enabled: bool) -> void
@abstract func get_auto_goto() -> bool
## The OLPC's Options: Animation (off, the engine leaves static rubble and the
## tiles don't animate), Messages (off, no message line or log) and Notices
## (off, no notices). The engine keeps all three; it uses only Animation.
@abstract func set_animation(enabled: bool) -> void
@abstract func get_animation() -> bool
@abstract func set_messages(enabled: bool) -> void
@abstract func get_messages() -> bool
@abstract func set_notices(enabled: bool) -> void
@abstract func get_notices() -> bool
## The OLPC editor's cheat words (w_keys.c): "fund" ($10,000, and an
## earthquake every fifth time), "fart" (every disaster), "nuke" (everything
## built explodes), "will" (500 tiles swapped), "olpc" ($1,000,000), and the
## heat automaton's "bobo", "boss", "mack", "donh", "patb", "lucb" and
## "stop". Returns whether the word was one.
@abstract func cheat(word: String) -> bool

# Tools --------------------------------------------------------------------

## Applies a tool at a tile; returns a ToolResult.
@abstract func do_tool(tool: Tool, x: int, y: int) -> ToolResult
## Applies a tool as a click on the map does: do_tool, and if it fails for want
## of money or bulldozing, the engine sends that message and its sound.
@abstract func tool_down(tool: Tool, x: int, y: int) -> void
## Paints a line tool (road, rail, wire, bulldozer, ...) from one tile to another.
@abstract func tool_drag(tool: Tool, from_x: int, from_y: int, to_x: int, to_y: int) -> void
@abstract func get_tool_cost(tool: Tool) -> int
## Footprint in tiles (square).
@abstract func get_tool_size(tool: Tool) -> int

# Budget -------------------------------------------------------------------

## Tax rate in percent, 0 to 20.
@abstract func get_tax_rate() -> int
@abstract func set_tax_rate(rate: int) -> void
## Funding levels, 0.0 to 1.0. As the 1989 budget sliders did, a level
## applies at once: this year's spending becomes the request times the level,
## and the road, fire and police effects follow it (the engine's
## setRoadPercent and its siblings, local edit 8). The next yearly budget
## requests again at these levels.
@abstract func set_road_percent(percent: float) -> void
@abstract func set_fire_percent(percent: float) -> void
@abstract func set_police_percent(percent: float) -> void
## tax_rate, tax_income, cash_flow, {road,fire,police}_{percent,requested,spent},
## auto_budget.
@abstract func get_budget() -> Dictionary
## Opens the budget from the menu: emits budget_requested.
@abstract func request_budget() -> void

# Evaluation ---------------------------------------------------------------

## Runs the evaluation now (the engine also runs it yearly).
@abstract func evaluate() -> void
## score, score_delta, approval (percent), population, population_delta,
## assessed_value, city_class, game_level, and problems: up to 4
## {problem: Problem, votes}, worst first.
@abstract func get_evaluation() -> Dictionary

# Disasters ----------------------------------------------------------------

@abstract func make_earthquake() -> void
@abstract func make_fire() -> void
@abstract func make_flood() -> void
@abstract func make_meltdown() -> void
@abstract func make_monster() -> void
@abstract func make_tornado() -> void
## Crashes the plane in the air, or a new one, where it is: an explosion, then
## fire (1989's MakeAirCrash, local edit 9). Only the Disasters menu does it.
@abstract func make_air_crash() -> void
@abstract func make_fire_bombs() -> void
@abstract func make_explosion(x: int, y: int) -> void

# Sprites ------------------------------------------------------------------

## The live sprites, in the order to draw them: {type: SpriteType, frame
## (from 1), x, y, x_offset, y_offset, width, height}, in map pixels (16 to a
## tile). The image for frame f goes at (x + x_offset, y + y_offset), as 1989's
## DrawSprite put it.
@abstract func get_sprites() -> Array

# Graph history ------------------------------------------------------------

## HISTORY_LENGTH values, newest first.
@abstract func get_history(type: HistoryType, scale: HistoryScale) -> PackedInt32Array

# Map data -----------------------------------------------------------------

## A raw tile value: index and flags (TILE_*).
@abstract func get_tile(x: int, y: int) -> int
## Every tile, row-major: index = y * MAP_WIDTH + x.
@abstract func get_map() -> PackedInt32Array
## TILE_COUNT entries: the tile each tile shows next when it's animated
## (TILE_ANIM_BIT). A tile that doesn't animate maps to itself. The engine
## doesn't apply it; the front end steps its animated tiles through it.
@abstract func get_animation_table() -> PackedInt32Array
## An overlay at its own resolution (get_overlay_size), row-major.
@abstract func get_overlay(overlay: Overlay) -> PackedInt32Array
@abstract func get_overlay_size(overlay: Overlay) -> Vector2i
