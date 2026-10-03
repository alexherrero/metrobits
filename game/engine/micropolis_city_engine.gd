## CityEngine over MicropolisCore's C++ engine, through the GDExtension class
## MicropolisEngine. It only delegates, and re-emits the engine's signals as
## CityEngine's.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name MicropolisCityEngine
extends CityEngine

var _engine: MicropolisEngine


## content_dir defaults to micropolis-core/content, wherever Content finds it:
## in the repo, or inside an exported app.
func _init(content_dir := "") -> void:
	_engine = MicropolisEngine.new()
	_engine.set_content_dir(content_dir if content_dir != "" else Content.path(""))
	for info in get_script().get_base_script().get_script_signal_list():
		var signal_name: StringName = info.name
		_engine.connect(signal_name, Signal(self, signal_name).emit)


func get_content_dir() -> String:
	return _engine.get_content_dir()


func load_scenario(scenario: Scenario) -> bool:
	return _engine.load_scenario(scenario)


func load_city(path: String) -> bool:
	return _engine.load_city(path)


func save_city(path: String) -> bool:
	return _engine.save_city(path)


func generate_map(seed: int) -> void:
	_engine.generate_map(seed)


func generate_random_map() -> void:
	_engine.generate_random_map()


func seed_random(seed: int) -> void:
	_engine.seed_random(seed)


func set_fixed_seed(seed: int) -> void:
	_engine.set_fixed_seed(seed)


func clear_fixed_seed() -> void:
	_engine.clear_fixed_seed()


func tick() -> void:
	_engine.tick()


func set_speed(speed: int) -> void:
	_engine.set_speed(speed)


func get_speed() -> int:
	return _engine.get_speed()


func pause() -> void:
	_engine.pause()


func resume() -> void:
	_engine.resume()


func is_paused() -> bool:
	return _engine.is_paused()


func set_passes(passes: int) -> void:
	_engine.set_passes(passes)


func get_passes() -> int:
	return _engine.get_passes()


func get_funds() -> int:
	return _engine.get_funds()


func set_funds(funds: int) -> void:
	_engine.set_funds(funds)


func get_city_time() -> int:
	return _engine.get_city_time()


func get_year() -> int:
	return _engine.get_year()


func get_month() -> int:
	return _engine.get_month()


func get_population() -> int:
	return _engine.get_population()


func get_residential_population() -> int:
	return _engine.get_residential_population()


func get_commercial_population() -> int:
	return _engine.get_commercial_population()


func get_industrial_population() -> int:
	return _engine.get_industrial_population()


func get_demand() -> Vector3i:
	return _engine.get_demand()


func get_city_name() -> String:
	return _engine.get_city_name()


func set_city_name(name: String) -> void:
	_engine.set_city_name(name)


func get_game_level() -> int:
	return _engine.get_game_level()


func set_game_level(level: int) -> void:
	_engine.set_game_level(level)


func get_scenario() -> int:
	return _engine.get_scenario()


func set_disasters_enabled(enabled: bool) -> void:
	_engine.set_disasters_enabled(enabled)


func get_disasters_enabled() -> bool:
	return _engine.get_disasters_enabled()


func set_auto_budget(enabled: bool) -> void:
	_engine.set_auto_budget(enabled)


func get_auto_budget() -> bool:
	return _engine.get_auto_budget()


func set_auto_bulldoze(enabled: bool) -> void:
	_engine.set_auto_bulldoze(enabled)


func get_auto_bulldoze() -> bool:
	return _engine.get_auto_bulldoze()


func set_auto_goto(enabled: bool) -> void:
	_engine.set_auto_goto(enabled)


func get_auto_goto() -> bool:
	return _engine.get_auto_goto()


func set_animation(enabled: bool) -> void:
	_engine.set_animation(enabled)


func get_animation() -> bool:
	return _engine.get_animation()


func set_messages(enabled: bool) -> void:
	_engine.set_messages(enabled)


func get_messages() -> bool:
	return _engine.get_messages()


func set_notices(enabled: bool) -> void:
	_engine.set_notices(enabled)


func get_notices() -> bool:
	return _engine.get_notices()


func cheat(word: String) -> bool:
	return _engine.cheat(word)


func do_tool(tool: Tool, x: int, y: int) -> ToolResult:
	return _engine.do_tool(tool, x, y) as ToolResult


func tool_down(tool: Tool, x: int, y: int) -> void:
	_engine.tool_down(tool, x, y)


func tool_drag(tool: Tool, from_x: int, from_y: int, to_x: int, to_y: int) -> void:
	_engine.tool_drag(tool, from_x, from_y, to_x, to_y)


func get_tool_cost(tool: Tool) -> int:
	return MicropolisEngine.get_tool_cost(tool)


func get_tool_size(tool: Tool) -> int:
	return MicropolisEngine.get_tool_size(tool)


func get_tax_rate() -> int:
	return _engine.get_tax_rate()


func set_tax_rate(rate: int) -> void:
	_engine.set_tax_rate(rate)


func set_road_percent(percent: float) -> void:
	_engine.set_road_percent(percent)


func set_fire_percent(percent: float) -> void:
	_engine.set_fire_percent(percent)


func set_police_percent(percent: float) -> void:
	_engine.set_police_percent(percent)


func get_budget() -> Dictionary:
	return _engine.get_budget()


func request_budget() -> void:
	_engine.request_budget()


func evaluate() -> void:
	_engine.evaluate()


func get_evaluation() -> Dictionary:
	return _engine.get_evaluation()


func make_earthquake() -> void:
	_engine.make_earthquake()


func make_fire() -> void:
	_engine.make_fire()


func make_flood() -> void:
	_engine.make_flood()


func make_meltdown() -> void:
	_engine.make_meltdown()


func make_monster() -> void:
	_engine.make_monster()


func make_tornado() -> void:
	_engine.make_tornado()


func make_air_crash() -> void:
	_engine.make_air_crash()


func get_sprites() -> Array:
	return _engine.get_sprites()


func make_fire_bombs() -> void:
	_engine.make_fire_bombs()


func make_explosion(x: int, y: int) -> void:
	_engine.make_explosion(x, y)


func get_history(type: HistoryType, scale: HistoryScale) -> PackedInt32Array:
	return _engine.get_history(type, scale)


func get_tile(x: int, y: int) -> int:
	return _engine.get_tile(x, y)


func get_map() -> PackedInt32Array:
	return _engine.get_map()


func get_animation_table() -> PackedInt32Array:
	return MicropolisEngine.get_animation_table()


func get_overlay(overlay: Overlay) -> PackedInt32Array:
	return _engine.get_overlay(overlay)


func get_overlay_size(overlay: Overlay) -> Vector2i:
	return _engine.get_overlay_size(overlay)
