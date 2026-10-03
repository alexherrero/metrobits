# In the game window: the Micropolis menu's Save City, Save City as...
# and Choose City! (the city chooser, with the eight scenarios, a generated map
# and Load City), the evaluation window, the sprites over the map, and Air
# Crash in the Disasters menu.
extends GutTest

const SAVE_DIR := "user://cities"

var main: Control
var engine: CityEngine


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	main.map_view.size = Vector2(900, 700)
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)


func after_each() -> void:
	for file in ["test_saved.cty", "Detroit.cty"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIR).path_join(file))


func _items(menu: PopupMenu) -> Array:
	var items := []
	for i in menu.item_count:
		if not menu.is_item_separator(i):
			items.append(menu.get_item_text(i))
	return items


func _advance(seconds: float) -> void:
	for frame in roundi(seconds * 60):
		main.advance(1.0 / 60.0)


# Menus -----------------------------------------------------------------------------

func test_the_menus_are_the_originals() -> void:
	assert_eq(_items(main.micropolis_menu), ["About...", "Save City", "Save City as...", "Choose City!", "Quit Playing!"])
	assert_eq(_items(main.disasters_menu), ["Monster", "Fire", "Flood", "Meltdown", "Air Crash", "Tornado",
		"Earthquake", "Enable Disasters"], "1989's order, Air Crash among them")
	assert_eq(_items(main.windows_menu), ["Budget", "Evaluation", "Graph", "Map"],
		"the OLPC's three, and the map the X11 edition's Windows menu had")
	assert_eq(_items(main.options_menu).slice(0, 7), ["Auto Budget", "Auto Bulldoze", "Disasters", "Sound",
		"Animation", "Messages", "Notices"], "whead.tcl's Options (F4), then our Tile Set")
	assert_eq(_items(main.editor_options_menu), ["Auto Goto", "Pallet Panel", "Chalk Overlay"],
		"weditor.tcl's Options (F4, F5)")


func test_the_notice_fills_the_room_under_the_map_and_clips_long_text() -> void:
	main.open_map()
	await wait_process_frames(3)
	var room: Control = main.map_room
	var title: int = main.map_window.get_theme_constant("title_height", "Window")
	assert_almost_eq(room.custom_minimum_size.y, float(title + main.map_window.size.y + 3), 0.5,
		"the map window's room, title bar and frame included")
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.ABOUT)
	await wait_process_frames(3)
	var notice: NoticeBox = main.notice
	assert_gte(notice.global_position.y, room.global_position.y + room.size.y - 0.5, "the notice starts under the map")
	assert_lte(notice.dismiss_button.global_position.y + notice.dismiss_button.size.y,
		notice.global_position.y + notice.size.y + 0.5, "Dismiss stays in the notice")
	assert_lte(notice.text_scroll.size.y, notice.size.y, "the text keeps to its room")
	main.map_window.hide()
	assert_eq(room.custom_minimum_size.y, 0.0, "with the map away, the notice has the whole foot")


func test_about_shows_the_about_notice() -> void:
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.ABOUT)
	assert_eq(main.notice.title_label.text, "About Micropolis", "the OLPC's Message 300")
	var text: String = main.notice.text_label.text
	assert_string_starts_with(text, "Metrobits %s (built on Micropolis): a modified version, restored in Godot.\n" % Notices.version()
		+ "Micropolis is a registered trademark of Micropolis Corporation (Micropolis GmbH) and is licensed here as a "
		+ "courtesy of the owner under the Micropolis Public Name License (www.micropolis.com).\n\n",
		"marked as modified, then the name licence's attribution, first")
	assert_string_contains(text, "Micropolis Version 4.0 Copyright (C) 2007\n    by Electronic Arts.")
	assert_string_contains(text, "    by Don Hopkins, DUX Software.")
	assert_string_contains(text, "    version 3, with additional conditions.")
	assert_string_ends_with(text, "    version 3, with additional conditions.")
	assert_eq(main.notice.title_bar_color(), Color("#ffd700"))
	assert_eq(main.notice.text_label.get_theme_font_size("font_size"), ClassicTheme.MEDIUM,
		"UIShowPictureOn's Medium, as for every notice")


func test_quitting_asks_first() -> void:
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.QUIT)
	assert_true(main.ask_dialog.visible)
	assert_eq(main.ask_dialog.dialog_text, "Do you want to quit playing Micropolis?")
	assert_eq(main.ask_dialog.get_ok_button().text, "I quit!")
	assert_eq(main.ask_dialog.get_cancel_button().text, "Keep playing.")
	main.ask_dialog.hide()


# Save and load ---------------------------------------------------------------------

func test_save_city_asks_for_a_file_for_a_scenario() -> void:
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.SAVE)
	var dialog: FileDialog = main.file_dialog
	assert_true(dialog.visible, "a scenario has no file of its own")
	assert_eq(dialog.file_mode, FileDialog.FILE_MODE_SAVE_FILE)
	assert_eq(dialog.title, "Choose a File to Save the City")
	assert_eq(dialog.current_dir.simplify_path(), ProjectSettings.globalize_path(SAVE_DIR).simplify_path())
	assert_eq(dialog.current_file, "Detroit.cty")
	dialog.hide()


func test_save_as_then_save_then_load_it_back() -> void:
	_advance(2.0)
	var path := ProjectSettings.globalize_path(SAVE_DIR).path_join("test_saved.cty")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	main.file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	main._on_file_chosen(path.trim_suffix(".cty"))
	assert_true(FileAccess.file_exists(path), ".cty added")
	assert_eq(engine.get_city_name(), "test_saved", "named after the file")
	assert_eq(main.city_file, path)
	assert_eq(main.message_log.lines[-1], "Saved the city in \"%s\"." % path, "UIDidSaveCity, in the log")
	assert_eq(main.message_log.tags[-1], "status")
	var saved_time := engine.get_city_time()
	_advance(2.0)
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.SAVE)
	assert_false(main.file_dialog.visible, "Save City saves to the city's own file")
	assert_gt(engine.get_city_time(), saved_time)
	var later_time := engine.get_city_time()
	var later_funds := engine.get_funds()
	main.load_scenario(CityEngine.Scenario.TOKYO)
	assert_true(main.load_city(path))
	assert_eq(engine.get_city_time(), later_time, "the second save")
	assert_eq(engine.get_funds(), later_funds)
	assert_eq(engine.get_city_name(), "test_saved")
	assert_eq(main.map_view.city_map.sync(), 0, "the map redrawn")


func test_a_city_from_the_content_folder_is_never_saved_over() -> void:
	assert_true(main.load_city("cities/haight.cty"))
	assert_eq(main.city_file, Content.path("cities/haight.cty"))
	main.save_city()
	assert_true(main.file_dialog.visible, "asks for a file instead")
	main.file_dialog.hide()


func test_a_file_that_wont_load_says_so() -> void:
	assert_false(main.load_city("user://no_such_city.cty"))
	assert_eq(main.message_log.lines[-1], "Unable to load a city from the file named \"user://no_such_city.cty\".",
		"UIDidntLoadCity's words")
	assert_eq(main.message_log.tags[-1], "alert", "in red")
	assert_eq(engine.get_city_name(), "Detroit", "the city stays")


# The city chooser (F2: wscen.tcl and micropolis.tcl's ScenarioButtons) ------------

func _choose_city() -> NewCityScreen:
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.CHOOSE_CITY)
	assert_true(main.ask_dialog.visible)
	assert_eq(main.ask_dialog.dialog_text, "Do you want to abandon this city and choose another one?")
	assert_eq(main.ask_dialog.get_ok_button().text, "Another city!")
	main.ask_dialog.confirmed.emit()
	main.ask_dialog.hide()
	return main.new_city_screen


## The middle of a button on the painting.
func _at(id: String) -> Vector2:
	return NewCityScreen.BUTTONS[NewCityScreen.button_index(id)].rect.get_center()


func _click(screen: NewCityScreen, id: String) -> void:
	screen.press_at(_at(id))
	screen.release_at(_at(id))


func test_choose_city_opens_the_painted_chooser_on_a_new_map() -> void:
	var detroit := engine.get_map()
	var screen := _choose_city()
	assert_true(screen.visible)
	assert_true(engine.is_paused(), "the game waits behind it")
	assert_false(engine.get_map() == detroit, "a map generated at once, as UIPickScenarioMode did")
	assert_eq(screen.name_edit.text, "NowHere", "UIGenerateCityNow's name")
	assert_eq([engine.get_game_level(), engine.get_funds()], [0, 20000], "at Easy, with its funds")
	assert_eq(screen.canvas.size, Vector2(1200, 900), "the OLPC's 1200 x 900 screen")
	assert_eq(screen.preview.position, Vector2(534, 48), "the map view where wscen.tcl placed it")
	assert_eq(screen.preview.custom_minimum_size, Vector2(360, 300), "three pixels a tile")
	var map := engine.get_map()
	for i in [0, 1234, 6000, 11999]:
		assert_eq(screen.preview.drawn_tile(i % 120, i / 120), map[i] & CityEngine.TILE_INDEX_MASK, "it shows the engine's map")
	assert_eq(screen.history.size(), 1)
	assert_eq(screen.picture(NewCityScreen.button_index("left")), "leftdisabled", "no map before it")
	assert_eq(screen.picture(NewCityScreen.button_index("right")), "rightdisabled", "nor after")
	assert_eq(screen.picture(NewCityScreen.button_index("easy")), "checkbox1checked", "Easy checked")


func test_the_buttons_are_scenariobuttons() -> void:
	var places := {}
	for button: Dictionary in NewCityScreen.BUTTONS:
		places[button.id] = button.rect
	assert_eq(places.size(), 18)
	assert_eq(places.load, Rect2(70, 238, 157, 90))
	assert_eq(places.play, Rect2(625, 376, 180, 50))
	assert_eq(places.hard, Rect2(982, 246, 190, 70))
	assert_eq(places.scenario8, Rect2(937, 638, 209, 188))
	var order := NewCityScreen.BUTTONS.filter(func(b: Dictionary) -> bool: return b.action == "scenario").map(
		func(b: Dictionary) -> int: return b.param)
	assert_eq(order, [1, 2, 3, 4, 5, 8, 7, 6], "the painting's order: Tokyo, Rio, Boston, Detroit below")


func test_the_pointer_shows_the_hover_pictures() -> void:
	var screen := _choose_city()
	var load := NewCityScreen.button_index("load")
	assert_eq(screen.picture(load), "", "the painting shows through")
	screen.point_at(_at("load"))
	assert_eq(screen.picture(load), "button1hilite")
	screen.point_at(Vector2(5, 5))
	assert_eq([screen.hovered, screen.picture(load)], [-1, ""], "off it again")
	screen.point_at(_at("easy"))
	assert_eq(screen.picture(NewCityScreen.button_index("easy")), "checkbox1hilitechecked", "checked, under the pointer")
	screen.point_at(_at("hard"))
	assert_eq(screen.picture(NewCityScreen.button_index("hard")), "checkbox3hilite")
	screen.point_at(_at("left"))
	assert_eq(screen.hovered, -1, "a disabled arrow can't be pointed at")
	screen.point_at(_at("scenario5"))
	assert_eq(screen.picture(NewCityScreen.button_index("scenario5")), "scenario5hilite")


func test_a_click_acts_on_release_over_the_button_it_went_down_on() -> void:
	var screen := _choose_city()
	screen.press_at(_at("generate"))
	screen.release_at(_at("about"))
	assert_eq(screen.history.size(), 1, "down on one, up on another: nothing")
	_click(screen, "generate")
	assert_eq(screen.history.size(), 2, "Generate New Terrain")
	var canvas := screen.canvas
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = _at("generate")
	canvas._gui_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	canvas._gui_input(release)
	assert_eq(screen.history.size(), 3, "through the painting's own input")


func test_generate_and_the_arrows_step_through_the_maps_shown() -> void:
	var screen := _choose_city()
	var first := engine.get_map()
	_click(screen, "generate")
	var second := engine.get_map()
	assert_false(second == first, "a new map")
	assert_eq(screen.picture(NewCityScreen.button_index("left")), "", "the left arrow wakes up")
	_click(screen, "left")
	assert_true(engine.get_map() == first, "the first map back")
	assert_eq(screen.name_edit.text, "NowHere")
	_click(screen, "right")
	assert_true(engine.get_map() == second, "and the second")
	assert_false(screen.is_enabled(NewCityScreen.button_index("right")), "the right arrow stops at the last map")
	_click(screen, "right")
	assert_eq(screen.history.size(), 2, "it doesn't generate one")


func test_a_scenario_is_shown_first_then_played() -> void:
	var screen := _choose_city()
	screen.point_at(_at("scenario1"))
	var found := Notices.for_scenario(1)
	assert_eq(screen.description_text(), "%s\n\n%s" % [found.title, found.text], "its title and story")
	assert_true(screen.description.get_parent().visible)
	assert_eq(screen.description.get_parent().position, Vector2(232, 170), "where UpdateScenarioButton put it")
	_click(screen, "scenario1")
	assert_true(screen.visible, "shown, not started")
	assert_eq(engine.get_scenario(), CityEngine.Scenario.DULLSVILLE)
	assert_true(engine.is_paused())
	assert_eq(screen.name_edit.text, "Dullsville", "the entry follows the engine's name")
	assert_eq(engine.get_funds(), 5000, "Dullsville's own funds, for now")
	assert_eq(screen.preview.drawn_tile(60, 50), engine.get_map()[50 * 120 + 60] & CityEngine.TILE_INDEX_MASK)
	_click(screen, "play")
	assert_false(screen.visible)
	assert_false(engine.is_paused())
	assert_eq(engine.get_scenario(), CityEngine.Scenario.DULLSVILLE)
	assert_eq(main.notice.title_label.text, found.title, "its notice, as UIUseThisMap showed it")
	assert_eq(engine.get_funds(), 20000, "Play set Easy's funds again, as UIUseThisMap's sim GameLevel did")


func test_each_scenario_plays_from_the_painting_with_its_notice() -> void:
	for scenario: int in NewCityScreen.SCENARIO_ORDER:
		var screen := _choose_city()
		_click(screen, NewCityScreen.scenario_button(scenario))
		_click(screen, "play")
		assert_eq(engine.get_scenario(), scenario)
		# Play This Map sets the entry's name, which the engine cleans, as the
		# OLPC's setCityName did: "San Francisco" plays as "San_Francisco".
		assert_eq(engine.get_city_name(), NewCityScreen.scenario_title(scenario).replace(" ", "_"))
		assert_eq(main.notice.title_label.text, Notices.for_scenario(scenario).title)
		assert_eq(main.map_view.city_map.sync(), 0)
	assert_eq(NewCityScreen.scenario_title(2), "San Francisco")
	assert_eq(NewCityScreen.scenario_tagline(8), "Coastal Flooding")


func test_play_this_map_at_the_level_checked() -> void:
	var screen := _choose_city()
	var map := engine.get_map()
	_click(screen, "medium")
	assert_eq([engine.get_game_level(), engine.get_funds()], [1, 10000], "a level sets its funds at once")
	assert_eq(screen.picture(NewCityScreen.button_index("medium")), "checkbox2hilitechecked")
	_click(screen, "hard")
	screen.name_edit.text = "Pixelburg"
	_click(screen, "play")
	assert_false(screen.visible)
	assert_eq(engine.get_city_name(), "Pixelburg")
	assert_eq([engine.get_game_level(), engine.get_funds(), engine.get_tax_rate()], [2, 5000, 7])
	assert_eq(engine.get_speed(), 3)
	assert_false(engine.is_paused())
	assert_true(engine.get_map() == map, "the map shown is the map played")
	assert_eq(main.city_file, "")


func test_load_city_shows_the_city_with_notice_49() -> void:
	var screen := _choose_city()
	_click(screen, "load")
	var dialog: FileDialog = main.file_dialog
	assert_true(dialog.visible)
	assert_eq(dialog.file_mode, FileDialog.FILE_MODE_OPEN_FILE)
	assert_eq(dialog.title, "Choose a City to Load")
	assert_eq(dialog.current_dir.simplify_path(), Content.path("cities").simplify_path())
	dialog.hide()
	var path := Content.path("cities/kyoto.cty")
	main._on_file_chosen(path)
	assert_true(screen.visible, "shown in the chooser, not started")
	assert_eq(engine.get_city_name(), "kyoto")
	assert_true(engine.is_paused())
	assert_eq(screen.game_level, -1, "a loaded city keeps its level, so none is checked")
	for id in ["easy", "medium", "hard"]:
		assert_eq(screen.picture(NewCityScreen.button_index(id)), "", id)
	assert_eq(screen.description_text(), "Restore a Saved City\n\nThis city was saved in the file named: " + path,
		"notice 49, in the panel: a quality-of-life addition")
	var funds := engine.get_funds()
	_click(screen, "play")
	assert_false(screen.visible)
	assert_eq(engine.get_city_name(), "kyoto")
	assert_eq(engine.get_funds(), funds, "its own funds")
	assert_eq(main.city_file, path)


func test_generate_shows_notice_48_in_the_panel() -> void:
	var screen := _choose_city()
	var found := Notices.for_message(NewCityScreen.NEW_CITY_NOTICE)
	assert_eq(found.title, "Start a New City")
	assert_eq(screen.description_text(), "Start a New City\n\n" + found.text, "a quality-of-life addition")
	_click(screen, "scenario2")
	screen.point_at(Vector2(5, 5))
	assert_eq(screen.description_text(), "", "a scenario has no notice here")
	assert_false(screen.description.get_parent().visible)
	_click(screen, "left")
	assert_string_starts_with(screen.description_text(), "Start a New City", "back to the map")


func test_about_shows_the_about_city() -> void:
	var screen := _choose_city()
	_click(screen, "about")
	assert_true(screen.visible)
	assert_eq(engine.get_city_name(), "about", "cities/about.cty, as DoAbout loaded it")
	assert_eq(screen.description_text(), "Restore a Saved City\n\nThis city was saved in the file named: cities/about.cty")
	assert_eq(screen.history[-1], {kind = "city", path = "cities/about.cty"})


func test_quit_asks_first() -> void:
	var screen := _choose_city()
	_click(screen, "quit")
	var dialog: ConfirmationDialog = main.ask_dialog
	assert_true(dialog.visible, "UIQuit's question")
	assert_eq([dialog.title, dialog.dialog_text], ["Quit Playing Micropolis", "Do you want to quit playing Micropolis?"])
	assert_eq([dialog.get_ok_button().text, dialog.get_cancel_button().text], ["I quit!", "Keep playing."])
	assert_eq((dialog.get_theme_stylebox("embedded_border") as StyleBoxFlat).bg_color, Color("#ff0000"), "titled in red")
	dialog.hide()
	assert_true(screen.visible)


# Evaluation ------------------------------------------------------------------------

func test_the_evaluation_window_shows_the_engines_evaluation() -> void:
	_advance(3.0)
	main.windows_menu.id_pressed.emit(main.WindowItem.EVALUATION)
	var window: EvaluationWindow = main.evaluation_window
	assert_true(window.visible)
	var evaluation := engine.get_evaluation()
	assert_eq(window.heading.text, "City Evaluation  %d" % engine.get_year())
	assert_eq(window.approval_label.text, "%d%%\n%d%%" % [evaluation.approval, 100 - evaluation.approval])
	assert_string_starts_with(window.stats_label.text, "%d\n%d\n\n$" % [evaluation.population,
		evaluation.population_delta])
	assert_string_contains(window.stats_label.text, EvaluationWindow.CLASSES[evaluation.city_class])
	assert_eq(window.score_label.text, "%d\n%d" % [evaluation.score, evaluation.score_delta])
	var names := window.problem_names.text.split("\n", false)
	assert_gt(names.size(), 0, "Detroit has problems")
	assert_eq(names[0], EvaluationWindow.PROBLEMS[evaluation.problems[0].problem], "the worst first")
	assert_eq(window.problem_votes.text.split("\n", false)[0], "%d%%" % evaluation.problems[0].votes)


func test_the_evaluation_keeps_up_while_open() -> void:
	main.open_evaluation()
	var window: EvaluationWindow = main.evaluation_window
	window.heading.text = ""
	watch_signals(engine)
	while get_signal_emit_count(engine, "evaluation_changed") == 0:
		engine.tick()
	assert_eq(window.heading.text, "City Evaluation  %d" % engine.get_year(), "the new evaluation shows")
	window.hide()


func test_opening_the_evaluation_draws_no_random_numbers() -> void:
	var other: CityEngine = MicropolisCityEngine.new()
	other.set_fixed_seed(1989)
	other.load_scenario(CityEngine.Scenario.DETROIT)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	for i in 300:
		engine.tick()
		other.tick()
		if i % 50 == 0:
			main.open_evaluation()
	assert_true(engine.get_map() == other.get_map())


# Sprites ---------------------------------------------------------------------------

func test_the_sprites_are_drawn_over_the_map() -> void:
	var layer: SpriteLayer = main.map_view.sprites
	assert_eq(layer.get_parent(), main.map_view.world)
	assert_lt(layer.get_index(), main.map_view.cursor.get_index(), "under the tool cursor")
	assert_gt(layer.get_index(), main.map_view.city_map.get_index(), "over the tiles")
	main.trigger_disaster(main.DisasterItem.MONSTER)
	var monster := layer.find(CityEngine.SpriteType.MONSTER)
	assert_false(monster.is_empty(), "the layer has the engine's monster")
	assert_eq(layer.sprites, engine.get_sprites())


func test_a_tornado_moves_across_the_map() -> void:
	engine.set_fixed_seed(7)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.trigger_disaster(main.DisasterItem.TORNADO)
	var layer: SpriteLayer = main.map_view.sprites
	var start := layer.find(CityEngine.SpriteType.TORNADO)
	assert_false(start.is_empty())
	_advance(0.3)
	var later := layer.find(CityEngine.SpriteType.TORNADO)
	assert_false(later.is_empty(), "still spinning")
	assert_ne(Vector2(later.x, later.y), Vector2(start.x, start.y), "it moved")
	assert_eq(main.notice.view.following, CityEngine.SpriteType.TORNADO, "its notice follows it, as 1989's did")
	main.notice.view._process(0.0)
	assert_eq(main.notice.view.center, SpriteLayer.center_of(later))


func test_air_crash_from_the_menu() -> void:
	watch_signals(engine)
	main.disasters_menu.id_pressed.emit(main.DisasterItem.AIR_CRASH)
	assert_eq(main.ask_dialog.dialog_text, "Oh no! Do you really want to crash an airplane?")
	main.ask_dialog.confirmed.emit()
	assert_signal_emitted(engine, "message_sent")
	assert_eq(get_signal_parameters(engine, "message_sent")[0], 24)
	assert_eq(main.message_label.text, "A plane has crashed !")
	assert_eq(main.notice.title_label.text, Notices.for_message(24).title)
	assert_false(main.map_view.sprites.find(CityEngine.SpriteType.EXPLOSION).is_empty(), "the explosion shows")
