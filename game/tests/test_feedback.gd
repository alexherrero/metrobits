# Messages and their notices, one at a time, with auto-goto, the Query tool's zone report, the
# budget window from the engine and from a button, the Disasters menu and its
# switch, and budget changes that change the sim.
extends GutTest

var main: Control
var engine: CityEngine
var view: MapView


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	view = main.map_view
	view.size = Vector2(900, 700)
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## Runs the game's loop until the map's glide is over.
func _glide_there() -> void:
	for frame in 600:
		if not view.is_gliding():
			return
		main.advance(1.0 / 60.0)


## Runs the engine until the year's taxes are in (the budget has figures).
func _run_to_taxes() -> void:
	while engine.get_budget().tax_income == 0:
		engine.tick()


# Messages ---------------------------------------------------------------------

func test_a_disaster_shows_its_message_notice_and_log_line() -> void:
	watch_signals(engine)
	main.trigger_disaster(main.DisasterItem.TORNADO)
	assert_eq(main.message_label.text, "Tornado reported !!")
	assert_eq(main.message_log.lines[-1], "Tornado reported !!")
	var notice: NoticeBox = main.notice
	assert_true(notice.visible)
	assert_eq(notice.title_label.text, "TORNADO ALERT!")
	assert_string_contains(notice.text_label.text, "tornado has been reported")
	var params: Array = get_signal_parameters(engine, "message_sent")
	assert_eq(notice.place, Vector2i(params[1], params[2]), "about the tornado's place")
	assert_true(notice.view.is_visible_in_tree(), "with a view of it")
	assert_eq(notice.view.center_tile(), notice.place)


func test_alerts_show_one_at_a_time_in_the_head_column() -> void:
	main.trigger_disaster(main.DisasterItem.TORNADO)
	main.trigger_disaster(main.DisasterItem.EARTHQUAKE)
	var notices := main.find_children("*", "NoticeBox", true, false)
	assert_eq(notices.size(), 1, "one notice window, as in 1989")
	assert_eq(main.notice.title_label.text, Notices.for_message(23).title, "the newest replaces the last")
	assert_true(main.get_node("Columns/HeadColumn").is_ancestor_of(main.notice), "not over the map")
	assert_false(main.map_view.is_ancestor_of(main.notice))
	main._on_message(10, -1, -1, true, false)  # high pollution, which has no place
	assert_eq(main.notice.title_label.text, Notices.for_message(10).title)
	assert_false(main.notice.view.is_visible_in_tree(), "no view for a notice with no place")


func test_a_message_without_a_picture_shows_no_notice() -> void:
	main.notice.dismiss()
	main._on_message(1, -1, -1, false, false)
	assert_eq(main.message_label.text, "More residential zones needed.")
	assert_false(main.notice.visible)


func test_a_notice_stays_until_dismissed() -> void:
	main._on_message(22, 30, 40, true, true)
	for frame in 60 * 15:
		main.advance(1.0 / 60.0)
	assert_true(main.notice.visible, "no timer: 1989's notice waited for Dismiss")
	main.notice.dismiss_button.pressed.emit()
	assert_false(main.notice.visible)


func test_clicking_the_notices_view_glides_the_map_there() -> void:
	assert_false(engine.get_auto_goto(), "1989's ComeToMe glided even with auto-goto off")
	main._on_message(22, 30, 40, true, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.notice.view._gui_input(click)
	assert_true(view.is_gliding())
	_glide_there()
	assert_eq(view.tile_at(view.size / 2.0), Vector2i(30, 40))


func test_the_notices_view_draws_what_the_map_shows() -> void:
	main._on_message(22, 30, 40, true, true)
	assert_eq(main.notice.view.center_tile(), Vector2i(30, 40))
	assert_eq(main.notice.view._city_map, main.map_view.city_map, "the editor's map, in its tile art")


func test_messages_read_the_originals_strings() -> void:
	assert_eq(Messages.text(1), "More residential zones needed.")
	assert_eq(Messages.text(22), "Tornado reported !!")
	assert_eq(Messages.text(44), "They're rioting in the streets !!")
	assert_eq(Messages.text(47), "You won the scenario!", "45 on are text.h's")
	assert_eq(Messages.text(0), "")
	assert_eq(Messages.text(99), "")


func test_notices_come_from_the_content() -> void:
	var tornado := Notices.for_message(22)
	assert_eq(tornado.title, "TORNADO ALERT!")
	assert_eq(tornado.color, Color("#ff4f4f"))
	assert_eq(Notices.for_message(10).title, "POLLUTION ALERT!")
	assert_false(Notices.for_message(10).text.contains("<br"), "line breaks, not markup")
	assert_eq(Notices.for_message(1), {})


# Auto-goto ---------------------------------------------------------------------

func test_auto_goto_starts_off_as_the_olpcs_editor_did() -> void:
	# weditor.tcl's AutoGoto.$win 0 and w_x.c's view->auto_goto = 0: the
	# sim's flag was on, but each editor followed only with its own on (F5).
	assert_false(engine.get_auto_goto())
	assert_false(main.editor_options_menu.is_item_checked(main.editor_options_menu.get_item_index(main.OptionItem.AUTO_GOTO)))


func test_the_map_glides_to_a_messages_place() -> void:
	main.editor_options_menu.id_pressed.emit(main.OptionItem.AUTO_GOTO)
	assert_true(engine.get_auto_goto())
	watch_signals(engine)
	view.center_on_tile(Vector2i(5, 5))
	var start := view.camera_position
	main.trigger_disaster(main.DisasterItem.EARTHQUAKE)
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_eq(view.camera_position, start, "no jump")
	assert_true(view.is_gliding())
	main.advance(1.0 / 40.0)
	assert_almost_eq(view.camera_position.distance_to(start), 15.0, 1.0, "a loop at Normal: the first step")
	# Paused, so no later message moves it elsewhere.
	main.set_paused(true)
	_glide_there()
	var moved_to := view.camera_position
	view.center_on_tile(Vector2i(message[1], message[2]))
	assert_eq(moved_to, view.camera_position, "centred on the earthquake")
	assert_ne(moved_to, start)


func test_a_glide_steps_once_a_loop_and_once_a_frame_when_paused() -> void:
	view.center_on_tile(Vector2i(5, 5))
	var start := view.camera_position
	engine.auto_goto_requested.emit(110, 90, "")
	main.set_priority(main.Priority.SLOW)
	for i in 3:
		main.advance(0.1)
		assert_eq(main.last_loops, 1, "a loop each tenth of a second at Slow")
	var at := view.camera_position
	assert_almost_eq(at.distance_to(start), 90.0, 2.0, "three loops, three steps: 15, 30 and 45 map pixels")
	main.set_paused(true)
	main.advance(1.0 / 60.0)
	main.advance(1.0 / 60.0)
	assert_eq(main.last_loops, 0)
	assert_almost_eq(view.camera_position.distance_to(at), 60.0 + 75.0, 2.0,
		"paused, a step a frame, as 1989 drew its editor again after each")


func test_turning_auto_goto_off_stops_a_glide() -> void:
	main.set_option(main.OptionItem.AUTO_GOTO, true)
	view.center_on_tile(Vector2i(5, 5))
	engine.auto_goto_requested.emit(110, 90, "")
	assert_true(view.is_gliding())
	main.editor_options_menu.id_pressed.emit(main.OptionItem.AUTO_GOTO)
	assert_false(view.is_gliding())


func test_the_map_stays_put_with_auto_goto_off() -> void:
	assert_false(engine.get_auto_goto())
	view.center_on_tile(Vector2i(5, 5))
	var before := view.camera_position
	main.trigger_disaster(main.DisasterItem.EARTHQUAKE)
	assert_eq(view.camera_position, before)


const SETTINGS_FILE := "user://test_settings.cfg"


## A game window keeping its settings in SETTINGS_FILE, as the real game keeps
## them in user://settings.cfg.
func _game_with_settings_file() -> Control:
	var game: Control = load("res://main.tscn").instantiate()
	game.settings_path = SETTINGS_FILE
	add_child_autofree(game)
	game.map_view.size = Vector2(900, 700)
	return game


func _remove_settings_file() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))


func test_turning_auto_goto_off_lasts_through_loads_and_restarts() -> void:
	_remove_settings_file()
	var game := _game_with_settings_file()
	assert_false(game.engine.get_auto_goto(), "off by default, as the OLPC's editor")
	game.editor_options_menu.id_pressed.emit(game.OptionItem.AUTO_GOTO)
	assert_true(game.engine.get_auto_goto())
	game.load_scenario(CityEngine.Scenario.TOKYO)
	assert_true(game.engine.get_auto_goto(), "a load keeps it on")
	var on := _game_with_settings_file()
	assert_true(on.engine.get_auto_goto(), "and so does the next launch")
	on.editor_options_menu.id_pressed.emit(on.OptionItem.AUTO_GOTO)
	assert_false(on.engine.get_auto_goto())
	on.load_scenario(CityEngine.Scenario.TOKYO)
	assert_false(on.engine.get_auto_goto(), "a load keeps it off")
	var again := _game_with_settings_file()
	assert_false(again.engine.get_auto_goto(), "and so does the next launch")
	assert_false(again.editor_options_menu.is_item_checked(again.editor_options_menu.get_item_index(again.OptionItem.AUTO_GOTO)))
	again.map_view.center_on_tile(Vector2i(5, 5))
	var before: Vector2 = again.map_view.camera_position
	again.trigger_disaster(again.DisasterItem.EARTHQUAKE)
	assert_eq(again.map_view.camera_position, before, "the map stays put")
	_remove_settings_file()


# A scenario's end (1.9a), as 1989's doScenarioScore, UILoseGame and
# UIWinGame had it --------------------------------------------------------------

## Runs the game at Super Fast until a scenario's end, with the budget
## window continued as it comes; returns the message: won (47) or lost (48).
func _play_to_the_end(scenario: CityEngine.Scenario) -> int:
	engine.set_fixed_seed(1989)
	main.load_scenario(scenario)
	main.set_priority(main.Priority.SUPER_FAST)
	watch_signals(engine)
	for frame in 5000:
		main.advance(1.0 / 60.0)
		await get_tree().process_frame
		if main.budget_window.visible:
			main.budget_window.close(false)
		for i in get_signal_emit_count(engine, "message_sent"):
			var index: int = get_signal_parameters(engine, "message_sent", i)[0]
			if index == main.SCENARIO_WON or index == main.SCENARIO_LOST:
				return index
	return -1


func test_a_lost_scenario_pauses_and_asks_with_one_answer_then_opens_the_chooser() -> void:
	assert_eq(await _play_to_the_end(CityEngine.Scenario.SAN_FRANCISCO), main.SCENARIO_LOST,
		"San Francisco, left alone, is lost in 1911")
	assert_eq(engine.get_year(), 1911)
	assert_signal_emitted(engine, "game_lost")
	assert_true(engine.is_paused(), "sim Pause")
	assert_eq(main.message_label.text, "Time pauses.")
	var dialog: ConfirmationDialog = main.ask_dialog
	assert_true(dialog.visible, "AskQuestion")
	assert_eq(dialog.title, "IMPEACHMENT NOTICE!", "titled as the notice")
	assert_string_starts_with(dialog.dialog_text, "The entire population of this city has finally had enough")
	assert_eq(dialog.ok_button_text, "Ok")
	assert_false(dialog.get_cancel_button().visible, "one answer")
	var title_bar := dialog.get_theme_stylebox("embedded_border") as StyleBoxFlat
	assert_eq(title_bar.bg_color, Color("#ff0000"), "in red")
	dialog.get_ok_button().pressed.emit()
	assert_true(main.new_city_screen.visible, "Ok: UIPickScenarioMode")
	# The next question is 1989's two-answer kind again; UISelectCity titled
	# it in red too.
	main.ask_to_choose_city()
	assert_true(dialog.get_cancel_button().visible)
	assert_eq(dialog.title, "Choose Another City")
	assert_eq((dialog.get_theme_stylebox("embedded_border") as StyleBoxFlat).bg_color, Color("#ff0000"))


func test_a_won_scenario_shows_its_notice_and_plays_on() -> void:
	watch_signals(main.notice)
	assert_eq(await _play_to_the_end(CityEngine.Scenario.BERN), main.SCENARIO_WON,
		"Bern, left alone, is won in 1975: its traffic stays light")
	# A win doesn't pause, so the rest of the frame's loops at Super Fast run on.
	assert_gte(engine.get_year(), 1975)
	assert_signal_not_emitted(engine, "game_lost")
	assert_false(main.ask_dialog.visible, "no question")
	assert_false(engine.is_paused(), "it plays on")
	var time := engine.get_city_time()
	for frame in 5:
		main.advance(1.0 / 60.0)
	assert_gt(engine.get_city_time(), time)


func test_the_scenario_notices_are_1989s() -> void:
	var won := Notices.for_message(main.SCENARIO_WON)
	var lost := Notices.for_message(main.SCENARIO_LOST)
	assert_eq(won.title, "YOU'RE A WINNER!")
	assert_eq(won.color, Color("#7fff7f"))
	assert_eq(lost.title, "IMPEACHMENT NOTICE!")
	assert_eq(lost.color, Color("#ff4f4f"))


# Tile art ----------------------------------------------------------------

func test_the_tile_art_is_the_olpcs_alone() -> void:
	var config := ConfigFile.new()
	config.set_value("options", "tile_set", "classic")
	config.save(SETTINGS_FILE)
	var game := _game_with_settings_file()
	var city_map: CityMap = game.map_view.city_map
	assert_eq(city_map.tiles.get_width(), 256, "images/tiles.png, 16 tiles to a row, whatever an old file says")
	assert_same(city_map.tiles, CityMap.load_tiles())
	var items := []
	for i in game.options_menu.item_count:
		items.append(game.options_menu.get_item_text(i))
	assert_false(items.has("Tile Set"), "no Tile Set in Options")
	_remove_settings_file()


func test_the_settings_file_can_be_edited_by_hand() -> void:
	var config := ConfigFile.new()
	config.set_value("options", "auto_goto", false)
	config.save(SETTINGS_FILE)
	var game := _game_with_settings_file()
	assert_false(game.engine.get_auto_goto())
	_remove_settings_file()


func test_the_tests_never_write_the_players_settings() -> void:
	assert_eq(Settings.default_path, "", "tests/pre_run.gd keeps settings in memory")
	assert_eq(main.settings.path, "")


# Query --------------------------------------------------------------------------

func test_the_query_tool_opens_the_zone_status_notice() -> void:
	watch_signals(engine)
	main.select_tool(CityEngine.Tool.QUERY)
	var zone := Vector2i(-1, -1)
	for i in CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT:
		if engine.get_map()[i] & CityEngine.TILE_ZONE_BIT:
			zone = Vector2i(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH)
			break
	main.notice.dismiss()
	view.click_tile(zone)
	assert_true(main.notice.visible)
	assert_eq(main.notice.title_label.text, "Query Zone Status")
	var params: Array = get_signal_parameters(engine, "zone_status_shown")
	assert_eq(main.notice.text_label.text, Notices.zone_status(params[0], params[1], params[2],
		params[3], params[4], params[5]))
	assert_string_starts_with(main.notice.text_label.text, "Zone: ")
	assert_eq(main.notice.place, zone, "with a view of the zone, as 1989's had")
	main.notice.dismiss()
	assert_false(main.notice.visible)


func test_zone_status_reads_the_originals_tables() -> void:
	assert_eq(Notices.zone_status(11, 1, 6, 9, 14, 18),
		"Zone: Residential\nDensity: Low\nValue: Lower Class\nCrime: Safe\nPollution: Moderate\nGrowth: Stable")
	assert_string_starts_with(Notices.zone_status(29, 1, 5, 9, 13, 17), "Zone: Clear", "bare land")


# Budget -------------------------------------------------------------------------

func test_the_budget_opens_when_the_engine_asks_and_pauses_the_game() -> void:
	engine.set_auto_budget(false)
	var year := engine.get_year()
	while engine.get_year() == year or engine.get_budget().tax_income == 0:
		main.advance(1.0 / 60.0)
	await _frames()
	assert_true(main.budget_window.visible, "the year's budget asks the player")
	assert_true(engine.is_paused())
	assert_eq(main.message_label.text, "Pausing to set the budget ...")
	main.budget_window.close(false)
	assert_false(main.budget_window.visible)
	assert_false(engine.is_paused(), "Continue resumes")
	assert_eq(main.message_label.text, "The budget wasn't changed.")


func test_the_budget_button_opens_it_and_changes_apply() -> void:
	_run_to_taxes()
	main.budget_button.pressed.emit()
	await _frames()
	var budget: BudgetWindow = main.budget_window
	assert_true(budget.visible)
	assert_true(engine.is_paused())
	assert_ne(budget.collected_label.text, "$0")
	budget.tax_slider.value = 12
	assert_eq(engine.get_tax_rate(), 12)
	assert_eq(budget.tax_label.text, "12%")
	budget.sliders.road.value = 40
	assert_almost_eq(engine.get_budget().road_percent, 0.4, 0.001)
	var requested: int = engine.get_budget().road_requested
	assert_eq(budget.request_labels.road.text, "40%% of %s = %s" % [HeadPanel.format_money(requested),
		HeadPanel.format_money(int(requested * 0.4))])
	budget.close(false)
	assert_eq(main.message_label.text, "The budget was changed.")
	assert_false(engine.is_paused())
	assert_eq(engine.get_tax_rate(), 12, "kept")


func test_cancel_and_reset_put_the_figures_back() -> void:
	_run_to_taxes()
	main.request_budget()
	await _frames()
	var budget: BudgetWindow = main.budget_window
	budget.tax_slider.value = 3
	budget.sliders.fire.value = 10
	budget.reset()
	assert_eq(engine.get_tax_rate(), 7)
	assert_almost_eq(engine.get_budget().fire_percent, 1.0, 0.001)
	budget.sliders.police.value = 0
	budget.close(true)
	assert_almost_eq(engine.get_budget().police_percent, 1.0, 0.001, "cancel undoes it")
	assert_eq(main.message_label.text, "The budget was reset.", "BudgetCancel is BudgetReset, then close")


func test_a_budget_opened_while_paused_stays_paused() -> void:
	engine.pause()
	main.request_budget()
	await _frames()
	main.budget_window.close(false)
	assert_true(engine.is_paused())


func test_clicking_the_funds_opens_the_budget_as_in_1989() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.head.funds_label.gui_input.emit(click)
	await _frames()
	assert_true(main.budget_window.visible)


func test_the_auto_budget_button() -> void:
	main.request_budget()
	await _frames()
	var budget: BudgetWindow = main.budget_window
	assert_true(engine.get_auto_budget())
	assert_eq(budget.auto_budget_button.text, "Disable Auto Budget (currently enabled)")
	budget.auto_budget_button.pressed.emit()
	assert_false(engine.get_auto_budget())
	assert_eq(budget.auto_budget_button.text, "Enable Auto Budget (currently disabled)")


# Budget changes change the sim ----------------------------------------------------

## Road tiles: roads, bridges and their traffic (ROADBASE to LASTROAD).
func _road_tiles(city: CityEngine) -> int:
	var count := 0
	for value in city.get_map():
		var tile := value & CityEngine.TILE_INDEX_MASK
		if tile >= 64 and tile <= 206:
			count += 1
	return count


func _detroit_after_taxes() -> CityEngine:
	var city: CityEngine = MicropolisCityEngine.new()
	city.set_fixed_seed(1989)
	city.load_scenario(CityEngine.Scenario.DETROIT)
	while city.get_budget().tax_income == 0:
		city.tick()
	return city


func test_a_funding_level_applies_at_once() -> void:
	var city := _detroit_after_taxes()
	city.set_road_percent(0.5)
	var budget := city.get_budget()
	assert_eq(budget.road_spent, int(budget.road_requested * 0.5), "this year's spending follows it")


func test_cutting_road_funding_lets_roads_decay() -> void:
	var funded := _detroit_after_taxes()
	var cut := _detroit_after_taxes()
	cut.set_road_percent(0.0)
	for i in 1500:
		funded.tick()
		cut.tick()
	assert_lt(_road_tiles(cut), _road_tiles(funded) - 20, "unfunded roads crumble")


func test_a_high_tax_rate_cuts_demand() -> void:
	var low := _detroit_after_taxes()
	var high := _detroit_after_taxes()
	low.set_tax_rate(0)
	high.set_tax_rate(20)
	for i in 600:
		low.tick()
		high.tick()
	assert_lt(high.get_demand().x, low.get_demand().x, "residential demand")
	assert_lt(high.get_population(), low.get_population() + 1)


# Disasters ----------------------------------------------------------------------

func test_the_disasters_menu_triggers_each_disaster() -> void:
	watch_signals(engine)
	var expected := {
		main.DisasterItem.TORNADO: 22, main.DisasterItem.EARTHQUAKE: 23,
		main.DisasterItem.MONSTER: 21, main.DisasterItem.FLOOD: 42,
	}
	for item: int in expected:
		main.disasters_menu.id_pressed.emit(item)
		main.ask_dialog.confirmed.emit()
		var indices := []
		for i in get_signal_emit_count(engine, "message_sent"):
			indices.append(get_signal_parameters(engine, "message_sent", i)[0])
		assert_has(indices, expected[item], "item %d" % item)
	assert_signal_emitted(engine, "earthquake_started")
	# A fire starts on a random burnable tile; it may take a few tries.
	var burning := false
	for attempt in 10:
		main.disasters_menu.id_pressed.emit(main.DisasterItem.FIRE)
		main.ask_dialog.confirmed.emit()
		for i in get_signal_emit_count(engine, "message_sent"):
			burning = burning or get_signal_parameters(engine, "message_sent", i)[0] == 20
	assert_true(burning, "a fire")


func test_a_meltdown_needs_a_nuclear_plant() -> void:
	main.load_scenario(CityEngine.Scenario.BOSTON)
	watch_signals(engine)
	main.disasters_menu.id_pressed.emit(main.DisasterItem.MELTDOWN)
	main.ask_dialog.confirmed.emit()
	assert_signal_emitted_with_parameters(engine, "message_sent", [43, get_signal_parameters(engine, "message_sent")[1],
		get_signal_parameters(engine, "message_sent")[2], true, true])
	assert_eq(main.notice.title_label.text, Notices.for_message(43).title)


func test_the_switch_turns_disasters_off_and_on() -> void:
	var menu: PopupMenu = main.disasters_menu
	var index := menu.get_item_index(main.DisasterItem.ENABLED)
	assert_true(engine.get_disasters_enabled())
	assert_true(menu.is_item_checked(index))
	menu.id_pressed.emit(main.DisasterItem.ENABLED)
	assert_false(engine.get_disasters_enabled())
	assert_false(menu.is_item_checked(index))
	var options: PopupMenu = main.options_menu
	assert_false(options.is_item_checked(options.get_item_index(main.OptionItem.DISASTERS)), "Options agrees")
	options.id_pressed.emit(main.OptionItem.DISASTERS)
	assert_true(engine.get_disasters_enabled())
	assert_true(menu.is_item_checked(index))


func test_the_options_menu() -> void:
	var options: PopupMenu = main.options_menu
	for item: int in [main.OptionItem.AUTO_BUDGET, main.OptionItem.AUTO_BULLDOZE]:
		var before := options.is_item_checked(options.get_item_index(item))
		options.id_pressed.emit(item)
		assert_ne(options.is_item_checked(options.get_item_index(item)), before)
	assert_false(engine.get_auto_budget())
	assert_false(engine.get_auto_bulldoze())


# Upstream's definition of done ------------------------------------------------------

# micropolis-playable-game-readiness.md §7, item by item, in our app.
func test_upstreams_definition_of_done() -> void:
	watch_signals(engine)
	# 1. City loads and sim runs without pressing a number key.
	var time := engine.get_city_time()
	for frame in 120:
		main.advance(1.0 / 60.0)
	assert_gt(engine.get_city_time(), time, "1: the sim runs")
	# 2. User selects Road/Bulldoze/Zone/Query from visible UI.
	for tool: int in [CityEngine.Tool.ROAD, CityEngine.Tool.BULLDOZER, CityEngine.Tool.RESIDENTIAL,
			CityEngine.Tool.QUERY]:
		assert_true(main.palette.buttons[tool].is_visible_in_tree(), "2: a visible button")
		main.palette.buttons[tool].pressed.emit()
		assert_eq(view.tool, tool)
	# 3. Left-click places tool; funds decrease; map updates.
	main.palette.buttons[CityEngine.Tool.ROAD].pressed.emit()
	var dirt := -1
	for i in CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT:
		if engine.get_map()[i] == 0:
			dirt = i
			break
	var site := Vector2i(dirt % CityEngine.MAP_WIDTH, dirt / CityEngine.MAP_WIDTH)
	view.center_on_tile(site)
	var funds := engine.get_funds()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.world_to_screen((Vector2(site) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE)
	view._gui_input(click)
	click = click.duplicate()
	click.pressed = false
	view._gui_input(click)
	assert_lt(engine.get_funds(), funds, "3: funds decrease")
	assert_ne(view.city_map.shown_tile(site.x, site.y), 0, "3: the map shows the road")
	# 4. HUD shows funds, date, demand changing over time.
	var date: String = main.head.date_label.text
	for frame in 300:
		main.advance(1.0 / 60.0)
	assert_ne(main.head.date_label.text, date, "4: the date changes")
	assert_eq(main.head.funds_label.text, "Funds: " + HeadPanel.format_money(engine.get_funds()))
	assert_eq(main.head.gauge.demand, engine.get_demand(), "4: demand")
	# 5. Query click shows zone stats panel.
	main.palette.buttons[CityEngine.Tool.QUERY].pressed.emit()
	view.click_tile(site)
	assert_eq(main.notice.title_label.text, "Query Zone Status", "5: the zone status")
	# 6. Engine message (e.g. tornado sighted) appears as on-screen toast.
	main.disasters_menu.id_pressed.emit(main.DisasterItem.TORNADO)
	main.ask_dialog.confirmed.emit()
	assert_true(main.notice.visible)
	assert_eq(main.notice.title_label.text, "TORNADO ALERT!", "6: its notice")
	# 7. Pan/zoom still works alongside tools.
	view.center_on_tile(Vector2i(60, 50))
	var before := view.camera_position
	view.pan_by_screen(Vector2(40, 0))
	view.zoom_at(1.5, view.size / 2.0)
	assert_ne(view.camera_position, before, "7: pan")
	assert_almost_eq(view.get_zoom(), 1.5, 0.0001, "7: zoom")
