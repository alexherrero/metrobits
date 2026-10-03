# The game window: a city loads and runs at once, at speed 3, with no key press
# (upstream's step A1), and the map and head follow it. The Priority menu and
# keys are in test_start_and_pace.
extends GutTest

var main: Control


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_a_city_loads_and_runs_at_speed_3_with_no_key_press() -> void:
	var engine: CityEngine = main.engine
	assert_eq(engine.get_city_name(), "Detroit", "the tests start on Detroit")
	assert_eq(engine.get_speed(), 3)
	assert_false(engine.is_paused())
	var time := engine.get_city_time()
	for frame in 120:
		main.advance(1.0 / 60.0)
	assert_gt(engine.get_city_time(), time, "two seconds of frames moved the date on")
	assert_eq(main.map_view.city_map.sync(), 0, "the map already shows every change")
	assert_eq(main.head.date_label.text, HeadPanel.format_date(engine.get_year(), engine.get_month()))


func test_a_long_frame_doesnt_leave_a_backlog() -> void:
	var loop: float = 1.0 / main.loops_per_second()
	main.advance(0.5 * loop)
	assert_almost_eq(main._clock, 0.5 * loop, 0.00001, "not a loop yet")
	main.advance(1.0)
	assert_lte(main.last_loops, ceili(main.loops_per_second() * main.MAX_CATCH_UP), "a stall catches up only so far")
	assert_lte(main._clock, loop + 0.00001, "at most a loop carried over")


func test_clicking_the_logo_pauses_and_resumes() -> void:
	# whead.tcl bound TogglePause to the logo, not the gauge (F3).
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = DemandGauge.LOGO_AT + Vector2(10, 10)
	main.head.gauge._gui_input(click)
	assert_true(main.engine.is_paused())
	main.head.gauge._gui_input(click)
	assert_false(main.engine.is_paused())


func test_animated_tiles_move_only_while_the_sim_runs() -> void:
	var city_map: CityMap = main.map_view.city_map
	main.engine.make_fire()
	for frame in 30:
		main.advance(1.0 / 60.0)
	main.engine.pause()
	main.advance(1.0 / 60.0)
	var before := []
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			before.append(city_map.shown_tile(x, y))
	for frame in 30:
		main.advance(1.0 / 60.0)
	var after := []
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			after.append(city_map.shown_tile(x, y))
	assert_eq(after, before, "nothing moves while paused")
	main.engine.resume()
	for frame in 30:
		main.advance(1.0 / 60.0)
	after.clear()
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			after.append(city_map.shown_tile(x, y))
	assert_ne(after, before, "tiles animate again")


func test_arguments() -> void:
	assert_eq(main.parse_args(PackedStringArray(["--scenario=rio", "--benchmark", "x"])),
		{scenario = "rio", benchmark = true})
	assert_eq(main.scenario_from_arg("detroit"), CityEngine.Scenario.DETROIT)
	assert_eq(main.scenario_from_arg("San-Francisco"), CityEngine.Scenario.SAN_FRANCISCO)
	assert_eq(main.scenario_from_arg("3"), CityEngine.Scenario.HAMBURG)
	assert_eq(main.scenario_from_arg("nowhere"), CityEngine.Scenario.NONE)


func test_loading_another_city_redraws_the_map() -> void:
	assert_true(main.load_city("cities/haight.cty"))
	assert_eq(main.engine.get_speed(), 3)
	assert_eq(main.map_view.city_map.sync(), 0)
	var tile: int = main.engine.get_tile(60, 50) & CityEngine.TILE_INDEX_MASK
	assert_eq(main.map_view.city_map.shown_tile(60, 50), tile)
