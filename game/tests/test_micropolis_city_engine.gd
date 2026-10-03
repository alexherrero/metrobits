# MicropolisCore's engine, driven only through the CityEngine interface.
extends GutTest

var engine: CityEngine


func before_each() -> void:
	engine = MicropolisCityEngine.new()
	# Every load starts from the same random numbers, so each test repeats.
	engine.set_fixed_seed(1989)
	watch_signals(engine)


func _run(ticks: int) -> void:
	for i in ticks:
		engine.tick()


## The top-left corner of a size x size square of bare dirt, or (-1, -1).
func _find_clear_land(size: int) -> Vector2i:
	for y in range(2, CityEngine.MAP_HEIGHT - size - 2):
		for x in range(2, CityEngine.MAP_WIDTH - size - 2):
			var clear := true
			for dy in size:
				for dx in size:
					if engine.get_tile(x + dx, y + dy) & CityEngine.TILE_INDEX_MASK != 0:
						clear = false
						break
				if not clear:
					break
			if clear:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# The step's check: load a scenario, run ticks, read the numbers, apply a tool
# and receive the signals.
func test_loads_a_scenario_runs_ticks_applies_a_tool_and_signals() -> void:
	assert_true(engine.load_scenario(CityEngine.Scenario.DETROIT))
	assert_signal_emitted(engine, "scenario_loaded")
	assert_eq(engine.get_city_name(), "Detroit")
	assert_eq(engine.get_year(), 1972)
	assert_eq(engine.get_funds(), 20000)
	var start_time := engine.get_city_time()

	_run(500)
	assert_gt(engine.get_city_time(), start_time, "the date moved on")
	assert_gt(engine.get_population(), 0)
	assert_gt(engine.get_residential_population(), 0)
	assert_signal_emitted(engine, "date_changed")
	assert_signal_emitted(engine, "demand_changed")

	var site := _find_clear_land(1)
	assert_ne(site, Vector2i(-1, -1), "Detroit has bare land")
	var funds := engine.get_funds()
	assert_eq(engine.do_tool(CityEngine.Tool.ROAD, site.x, site.y), CityEngine.ToolResult.OK)
	assert_eq(engine.get_funds(), funds - engine.get_tool_cost(CityEngine.Tool.ROAD))
	assert_ne(engine.get_tile(site.x, site.y) & CityEngine.TILE_INDEX_MASK, 0, "a road is there now")
	assert_signal_emitted(engine, "tool_applied")

	_run(50)
	assert_signal_emitted(engine, "funds_changed")


func test_tools_charge_what_get_tool_cost_says() -> void:
	engine.generate_map(1234)
	engine.set_funds(100000)
	for tool: int in [CityEngine.Tool.ROAD, CityEngine.Tool.WIRE, CityEngine.Tool.RAILROAD,
			CityEngine.Tool.PARK, CityEngine.Tool.RESIDENTIAL, CityEngine.Tool.POLICE_STATION,
			CityEngine.Tool.COAL_POWER]:
		var size := engine.get_tool_size(tool)
		var site := _find_clear_land(size)
		assert_ne(site, Vector2i(-1, -1), "room for tool %d" % tool)
		# Buildings are placed by their centre tile.
		var at := site + Vector2i(1, 1) if size > 1 else site
		var funds := engine.get_funds()
		assert_eq(engine.do_tool(tool, at.x, at.y), CityEngine.ToolResult.OK, "tool %d placed" % tool)
		assert_eq(funds - engine.get_funds(), engine.get_tool_cost(tool), "tool %d cost" % tool)


func test_a_tool_needs_money() -> void:
	engine.generate_map(1234)
	engine.set_funds(0)
	var site := _find_clear_land(1)
	assert_eq(engine.do_tool(CityEngine.Tool.ROAD, site.x, site.y), CityEngine.ToolResult.NO_MONEY)


func test_dragging_a_road_paints_a_line() -> void:
	engine.generate_map(1234)
	engine.set_funds(100000)
	var site := _find_clear_land(6)
	var funds := engine.get_funds()
	engine.tool_drag(CityEngine.Tool.ROAD, site.x, site.y, site.x + 5, site.y)
	for dx in 6:
		assert_ne(engine.get_tile(site.x + dx, site.y) & CityEngine.TILE_INDEX_MASK, 0, "road at +%d" % dx)
	assert_eq(funds - engine.get_funds(), 6 * engine.get_tool_cost(CityEngine.Tool.ROAD))


func test_the_query_tool_shows_zone_status() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.do_tool(CityEngine.Tool.QUERY, 60, 50)
	assert_signal_emitted(engine, "zone_status_shown")
	var params: Array = get_signal_parameters(engine, "zone_status_shown")
	assert_eq(params.slice(6), [60, 50])


func test_budget_request_and_tax_rate() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.request_budget()
	assert_signal_emitted(engine, "budget_requested")
	engine.set_tax_rate(9)
	assert_eq(engine.get_tax_rate(), 9)
	assert_signal_emitted_with_parameters(engine, "tax_rate_changed", [9])
	engine.set_road_percent(0.5)
	engine.set_police_percent(2.0)
	var budget := engine.get_budget()
	assert_eq(budget.tax_rate, 9)
	assert_almost_eq(budget.road_percent, 0.5, 0.0001)
	assert_almost_eq(budget.police_percent, 1.0, 0.0001, "clamped to 1")
	for key in ["tax_income", "cash_flow", "fire_percent", "road_requested", "road_spent", "auto_budget"]:
		assert_has(budget, key)


func test_the_yearly_budget_asks_the_player_when_auto_budget_is_off() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_budget(false)
	_run(1500)  # past a new year
	assert_signal_emitted(engine, "budget_requested")
	assert_gt(engine.get_budget().road_requested, 0)


func test_a_tornado_sends_a_message_and_an_auto_goto() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(true)
	engine.make_tornado()
	assert_signal_emitted(engine, "message_sent")
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_true(message[4], "important")
	assert_signal_emitted(engine, "auto_goto_requested")
	var goto: Array = get_signal_parameters(engine, "auto_goto_requested")
	assert_eq([goto[0], goto[1]], [message[1], message[2]], "goes where the message is")


func test_no_auto_goto_when_it_is_off() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(false)
	engine.make_tornado()
	assert_signal_emitted(engine, "message_sent")
	assert_signal_not_emitted(engine, "auto_goto_requested")


## Every sound_requested emission, as [channel, sound, x, y].
func _sounds() -> Array:
	var sounds := []
	for i in get_signal_emit_count(engine, "sound_requested"):
		sounds.append(get_signal_parameters(engine, "sound_requested", i))
	return sounds


# The 1989 code played a message's sound when it showed the message.
func test_a_message_with_a_sound_plays_it_where_the_message_is() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_tornado()
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_has(_sounds(), ["city", "Siren", message[1], message[2]], "the tornado message's siren")


func test_a_message_without_a_sound_plays_none() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_funds(0)
	var site := _find_clear_land(1)
	engine.tool_down(CityEngine.Tool.ROAD, site.x, site.y)
	assert_signal_emitted(engine, "message_sent", "not enough funds")
	for sound: Array in _sounds():
		assert_eq(sound[0], "interface", "only the tool's own sound: %s" % [sound])


# The 1989 code moved the map to any message with a place, important or not.
func test_auto_goto_follows_an_unimportant_message_with_a_place() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(true)
	engine.make_earthquake()
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_false(message[4], "an earthquake isn't marked important")
	assert_signal_emitted(engine, "auto_goto_requested")
	var goto: Array = get_signal_parameters(engine, "auto_goto_requested")
	assert_eq([goto[0], goto[1]], [message[1], message[2]])


func test_no_auto_goto_for_a_message_without_a_place() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(true)
	engine.set_funds(0)
	var site := _find_clear_land(1)
	engine.tool_down(CityEngine.Tool.ROAD, site.x, site.y)
	assert_signal_emitted(engine, "message_sent")
	assert_signal_not_emitted(engine, "auto_goto_requested")


func test_an_earthquake_makes_a_sound() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_earthquake()
	assert_signal_emitted(engine, "earthquake_started")
	assert_has(_sounds(), ["city", "ExplosionLow", -1, -1], "the quake itself")
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_has(_sounds(), ["city", "Siren", message[1], message[2]], "the earthquake message")


## The message numbers sent so far, in order.
func _messages() -> Array:
	var sent := []
	for i in get_signal_emit_count(engine, "message_sent"):
		sent.append(get_signal_parameters(engine, "message_sent", i)[0])
	return sent


# Local edit 7: 1989's SendMes dropped a picture message that repeated the last
# one, and ClearMes let an important one through every time.
func test_a_repeated_picture_message_is_dropped() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(true)
	engine.make_earthquake()
	var goes: int = get_signal_emit_count(engine, "auto_goto_requested")
	var sirens: int = _sounds().count(["city", "Siren", get_signal_parameters(engine, "message_sent")[1],
		get_signal_parameters(engine, "message_sent")[2]])
	engine.make_earthquake()
	assert_eq(_messages(), [23], "the second earthquake's message is dropped")
	assert_eq(get_signal_emit_count(engine, "auto_goto_requested"), goes, "with its auto-goto")
	assert_eq(get_signal_emit_count(engine, "earthquake_started"), 2, "the quake itself still happens")
	var sirens_after := 0
	for sound: Array in _sounds():
		sirens_after += int(sound[1] == "Siren")
	assert_eq(sirens_after, sirens, "and its siren")


func test_a_different_picture_message_lets_it_show_again() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_earthquake()
	engine.make_flood()
	engine.make_earthquake()
	var sent := _messages()
	assert_eq(sent.count(23), 2, "earthquake, flood, earthquake: %s" % [sent])


func test_an_important_message_always_shows() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_fire_bombs()
	var first := _messages().count(30)
	engine.make_fire_bombs()
	assert_gt(first, 0)
	assert_gt(_messages().count(30), first, "firebombing, marked important, as 1989 cleared before it")
	assert_eq(_messages().filter(func(index: int) -> bool: return index != 30), [], "every bomb reported")
	engine.make_earthquake()
	engine.set_funds(0)
	engine.tool_down(CityEngine.Tool.ROAD, 0, 0)
	engine.make_earthquake()
	assert_eq(_messages().count(23), 2, "an important message in between clears the last picture")


func test_a_load_forgets_the_last_picture_message() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_earthquake()
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_earthquake()
	assert_eq(_messages().count(23), 2)


func test_a_message_without_a_picture_is_never_dropped() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_funds(0)
	var site := _find_clear_land(1)
	for i in 3:
		engine.tool_down(CityEngine.Tool.ROAD, site.x, site.y)
	assert_eq(_messages().count(33), 3, "not enough funds, each time")


# Local edit 8: the engine's own funding setters apply the effect.
func test_funding_setters_change_the_effect_in_the_engine() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	while engine.get_budget().tax_income == 0:
		engine.tick()
	var budget := engine.get_budget()
	assert_gt(budget.road_requested, 0)
	engine.set_road_percent(0.25)
	budget = engine.get_budget()
	assert_eq(budget.road_spent, int(budget.road_requested * 0.25))
	engine.set_fire_percent(-1.0)
	assert_almost_eq(engine.get_budget().fire_percent, 0.0, 0.0001, "clamped to 0")


func test_every_disaster_runs() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_disasters_enabled(true)
	engine.make_fire()
	engine.make_flood()
	engine.make_meltdown()
	engine.make_monster()
	engine.make_fire_bombs()
	engine.make_explosion(60, 50)
	_run(300)
	assert_eq(engine.get_map().size(), CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT)
	assert_true(engine.get_disasters_enabled())


func test_speed_and_pause() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_speed(2)
	assert_eq(engine.get_speed(), 2)
	assert_signal_emitted_with_parameters(engine, "speed_changed", [2])
	engine.pause()
	assert_true(engine.is_paused())
	assert_signal_emitted_with_parameters(engine, "paused_changed", [true])
	assert_eq(engine.get_speed(), 2, "pausing keeps the chosen speed")
	var time := engine.get_city_time()
	_run(200)
	assert_eq(engine.get_city_time(), time, "no time passes while paused")
	engine.resume()
	assert_false(engine.is_paused())
	_run(200)
	assert_gt(engine.get_city_time(), time)
	engine.set_passes(4)
	assert_eq(engine.get_passes(), 4)


func test_generating_a_map() -> void:
	engine.generate_map(42)
	assert_signal_emitted_with_parameters(engine, "map_generated", [42])
	assert_eq(engine.get_scenario(), CityEngine.Scenario.NONE)
	var first := engine.get_map()
	engine.generate_map(42)
	assert_eq(engine.get_map(), first, "the same seed gives the same terrain")
	engine.generate_map(43)
	assert_ne(engine.get_map(), first)


func test_loading_and_saving_a_city() -> void:
	assert_true(engine.load_city("cities/haight.cty"))
	assert_signal_emitted(engine, "city_loaded")
	assert_eq(engine.get_city_name(), "haight")
	_run(100)
	var path := "user://test_roundtrip.cty"
	assert_true(engine.save_city(path))
	assert_signal_emitted(engine, "city_saved")
	var funds := engine.get_funds()
	var time := engine.get_city_time()
	var other: CityEngine = MicropolisCityEngine.new()
	assert_true(other.load_city(path))
	assert_eq(other.get_funds(), funds)
	assert_eq(other.get_city_time(), time)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_bad_loads_fail() -> void:
	assert_false(engine.load_scenario(CityEngine.Scenario.NONE))
	assert_false(engine.load_scenario(99))
	assert_false(engine.load_city("cities/no_such_city.cty"))
	assert_signal_emitted(engine, "city_load_failed")
	var lost: CityEngine = MicropolisCityEngine.new("/no/such/content")
	assert_false(lost.load_scenario(CityEngine.Scenario.DETROIT))


func test_map_and_overlays() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	_run(100)
	var map := engine.get_map()
	assert_eq(map.size(), CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT)
	assert_eq(map[20 * CityEngine.MAP_WIDTH + 30], engine.get_tile(30, 20), "row-major")
	var expected_sizes := {
		CityEngine.Overlay.POPULATION_DENSITY: Vector2i(60, 50),
		CityEngine.Overlay.TERRAIN_DENSITY: Vector2i(30, 25),
		CityEngine.Overlay.POWER_GRID: Vector2i(120, 100),
		CityEngine.Overlay.RATE_OF_GROWTH: Vector2i(15, 13),
	}
	for overlay: int in CityEngine.Overlay.values():
		var size := engine.get_overlay_size(overlay)
		assert_eq(engine.get_overlay(overlay).size(), size.x * size.y, "overlay %d" % overlay)
		if expected_sizes.has(overlay):
			assert_eq(size, expected_sizes[overlay], "overlay %d size" % overlay)
	var population := engine.get_overlay(CityEngine.Overlay.POPULATION_DENSITY)
	assert_gt(Array(population).max(), 0, "Detroit has people on the density map")


func test_graph_history() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	for type: int in CityEngine.HistoryType.values():
		for scale: int in CityEngine.HistoryScale.values():
			assert_eq(engine.get_history(type, scale).size(), CityEngine.HISTORY_LENGTH)
	var residential := engine.get_history(CityEngine.HistoryType.RESIDENTIAL, CityEngine.HistoryScale.SHORT)
	assert_gt(Array(residential).max(), 0)


func test_evaluation() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	_run(100)
	engine.evaluate()
	var evaluation := engine.get_evaluation()
	for key in ["score", "score_delta", "approval", "population", "population_delta",
			"assessed_value", "city_class", "game_level", "problems"]:
		assert_has(evaluation, key)
	assert_between(evaluation.score, 0, 1000)
	assert_between(evaluation.approval, 0, 100)
	assert_lte(evaluation.problems.size(), 4)
	for problem: Dictionary in evaluation.problems:
		assert_between(problem.problem, 0, CityEngine.Problem.size() - 1)
