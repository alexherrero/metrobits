# The OLPC's Chalk and Eraser in their palette slots, with the chalk
# overlay and its option, our four extra tools set apart; and the small
# things: Ctrl to hold a drag to a row or column, Tab, the pan cursor, the key
# to the city, the cheat words, and F10.
extends GutTest

var main: Control
var engine: CityEngine
var view: MapView


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	main.set_paused(true)
	view = main.map_view
	view.size = Vector2(900, 700)
	view.center_on_tile(Vector2i(60, 50))


func _button(at: Vector2, pressed := true, ctrl := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.ctrl_pressed = ctrl
	return event


func _move(to: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = to
	return event


# The palette (weditor.tcl) ---------------------------------------------------------

func test_the_palette_is_weditor_tcls_with_our_four_apart() -> void:
	# weditor.tcl's place lines, in EditorPallets' order.
	var olpc := [Vector2(9, 58), Vector2(47, 58), Vector2(85, 58), Vector2(9, 112), Vector2(47, 112),
		Vector2(85, 112), Vector2(28, 150), Vector2(66, 150), Vector2(6, 188), Vector2(66, 188), Vector2(28, 216),
		Vector2(66, 216), Vector2(1, 254), Vector2(47, 254), Vector2(85, 254), Vector2(1, 300), Vector2(85, 300),
		Vector2(35, 346)]
	var places := Tools.PALETTE.map(func(entry: Array) -> Vector2: return entry[1])
	assert_eq(places.slice(0, 18), olpc)
	assert_eq(Tools.PALETTE[10][0], Tools.CHALK, "Chalk where palletchalk was")
	assert_eq(Tools.PALETTE[11][0], Tools.ERASER, "Eraser where palleteraser was")
	for entry: Array in Tools.PALETTE.slice(18):
		assert_true(entry[0] in [CityEngine.Tool.WATER, CityEngine.Tool.LAND, CityEngine.Tool.FOREST,
			CityEngine.Tool.NETWORK], "ours")
		assert_gte(entry[1].y, Tools.EXTRAS_TOP, "set apart, under the airport")
	assert_same(main.palette.buttons[Tools.CHALK].texture_normal, Content.texture("images/icchlk.png"))
	main.palette.buttons[Tools.ERASER].pressed.emit()
	assert_same(main.palette.buttons[Tools.ERASER].texture_normal, Content.texture("images/icersrhi.png"))
	assert_eq([main.palette.name_label.text, main.palette.cost_label.text], ["Eraser", "free"], "ToolInfo")


func test_x_steps_from_road_to_chalk_to_eraser() -> void:
	main.select_tool(CityEngine.Tool.ROAD)
	main.step_tool(1)
	assert_eq(view.tool, Tools.CHALK)
	main.step_tool(1)
	assert_eq(view.tool, Tools.ERASER)
	main.step_tool(1)
	assert_eq(view.tool, CityEngine.Tool.STADIUM)


# Chalk and Eraser (w_tool.c) -------------------------------------------------------

func test_chalk_draws_a_stroke_from_its_tip() -> void:
	main.select_tool(Tools.CHALK)
	var map := engine.get_map()
	var funds := engine.get_funds()
	view._gui_input(_button(Vector2(400, 300)))
	view._gui_input(_move(Vector2(420, 310)))
	view._gui_input(_move(Vector2(440, 330)))
	view._gui_input(_button(Vector2(440, 330), false))
	view._gui_input(_move(Vector2(500, 400)))
	var strokes := view.chalk.strokes
	assert_eq(strokes.size(), 1)
	assert_eq(strokes[0].size(), 3, "a point at the press and at each move while down")
	assert_eq(strokes[0][0], view.screen_to_world(Vector2(400, 300)) + Vector2(-5, 11), "ChalkTool's x - 5, y + 11")
	assert_true(engine.get_map() == map, "the city untouched")
	assert_eq(engine.get_funds(), funds, "and free")


func test_the_eraser_rubs_out_whole_strokes_near_it() -> void:
	var chalk := view.chalk
	chalk.start(Vector2(100, 100))
	chalk.add(Vector2(200, 100))
	chalk.start(Vector2(500, 500))
	main.select_tool(Tools.ERASER)
	view._gui_input(_button(view.world_to_screen(Vector2(150, 106))))
	assert_eq(chalk.strokes.size(), 1, "the stroke within 8 pixels went, all of it")
	view._gui_input(_move(view.world_to_screen(Vector2(480, 480))))
	assert_eq(chalk.strokes.size(), 1, "a stroke 20 pixels away stays")
	view._gui_input(_move(view.world_to_screen(Vector2(495, 506))))
	assert_eq(chalk.strokes.size(), 0, "dragged onto it, it goes")


func test_a_stroke_meets_a_box_as_inkinbox_tested() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	assert_true(ChalkLayer.touches(line, Rect2(40, -8, 16, 16)), "on its first segment")
	assert_true(ChalkLayer.touches(line, Rect2(92, 50, 16, 16)), "on its second")
	assert_false(ChalkLayer.touches(line, Rect2(40, 40, 16, 16)), "inside its bounds but off both segments")
	assert_true(ChalkLayer.touches(PackedVector2Array([Vector2(5, 5)]), Rect2(0, 0, 16, 16)), "a dot")


func test_chalk_overlay_shows_and_hides_the_chalk_but_the_map_keeps_it() -> void:
	var menu: PopupMenu = main.editor_options_menu
	var index := menu.get_item_index(main.OptionItem.CHALK_OVERLAY)
	assert_true(view.chalk.shown and menu.is_item_checked(index), "shown from the start (view->show_overlay = 1)")
	menu.id_pressed.emit(main.OptionItem.CHALK_OVERLAY)
	assert_false(view.chalk.shown)
	assert_false(menu.is_item_checked(index))
	assert_same(main.map_window.small_map.ink.source, view.chalk, "the map draws the chalk always (DrawMapInk)")


func test_a_new_city_starts_with_no_chalk() -> void:
	view.chalk.start(Vector2(10, 10))
	main.load_scenario(CityEngine.Scenario.BERN)
	assert_eq(view.chalk.strokes.size(), 0, "UINewGame's sim EraseOverlay")


func test_the_chalk_and_eraser_have_their_own_cursors() -> void:
	main.select_tool(Tools.CHALK)
	assert_eq(view.cursor.tool, Tools.CHALK)
	view._gui_input(_move(Vector2(300, 300)))
	assert_eq(view.cursor.pointer, view.screen_to_world(Vector2(300, 300)), "drawn at the pointer, not a tile")
	view._gui_input(_button(Vector2(300, 300)))
	assert_true(view.cursor.pressed, "pressed onto its shadow")
	view._gui_input(_button(Vector2(300, 300), false))
	assert_false(view.cursor.pressed)


# Ctrl, Tab, the pan cursor -----------------------------------------------------------

func test_ctrl_holds_a_drag_to_a_row_after_16_pixels() -> void:
	var start := Vector2(400, 300)
	view._constrain(_button(start, true, true))
	var world_start := view.screen_to_world(start)
	assert_eq(view.screen_to_world(view.constrained(start + Vector2(10, 12))), world_start,
		"held to the start until it has moved 16 pixels")
	var across := view.screen_to_world(view.constrained(start + Vector2(40, 12)))
	assert_eq(across, Vector2(world_start.x + 40 / view.get_zoom(), world_start.y), "then along the row")
	var later := view.screen_to_world(view.constrained(start + Vector2(80, 60)))
	assert_eq(later.y, world_start.y, "and stays on it")
	view._constrain(_button(start, false))
	assert_eq(view.constraint, {}, "until the button comes up")


func test_ctrl_holds_a_road_to_a_column() -> void:
	main.select_tool(CityEngine.Tool.ROAD)
	engine.set_funds(100000)
	var start := view.world_to_screen(Vector2(10, 10) * 16 + Vector2(8, 8))
	view._gui_input(_button(start, true, true))
	view._gui_input(_move(start + Vector2(6, 64)))
	view._gui_input(_move(start + Vector2(20, 120)))
	assert_eq(view.tile_at(view.constrained(start + Vector2(20, 120))).x, view.tile_at(start).x, "held to the column")
	view._gui_input(_button(start + Vector2(20, 120), false))
	var column := view.tile_at(start).x
	var road := 0
	for y in range(10, 18):
		road += int(engine.get_tile(column, y) & CityEngine.TILE_INDEX_MASK != 0)
	assert_gt(road, 4, "the road went down the column")


func test_tab_clicks_where_the_pointer_is() -> void:
	main.select_tool(CityEngine.Tool.QUERY)
	watch_signals(engine)
	view.click_at(view.world_to_screen(Vector2(60, 50) * 16 + Vector2(8, 8)))
	assert_signal_emitted(engine, "zone_status_shown", "the query, at once")
	assert_false(view.cursor.pressed, "down and up")


func test_the_pointer_is_a_hand_and_panning_shows_the_cross() -> void:
	assert_eq(view.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "the editor's -cursor hand2")
	var press := _button(Vector2(300, 300))
	press.button_index = MOUSE_BUTTON_MIDDLE
	view._gui_input(press)
	assert_true(view.cursor.panning, "1989's pan cross instead of the tool (tool mode -1)")
	press.pressed = false
	view._gui_input(press)
	assert_false(view.cursor.panning)


# The key to the city (Message 100, wnotice.tcl) --------------------------------------

func test_the_win_notice_shows_the_key_to_the_city() -> void:
	main._on_message(main.SCENARIO_WON, -1, -1, true, true)
	assert_true(main.notice.picture.visible)
	assert_same(main.notice.picture.texture_normal, Content.olpc_texture("key2city"))
	main.notice.picture.pressed.emit()
	assert_eq(main.sounds.played.back().name, "Computer", "a click on it plays Computer")
	main._on_message(22, 30, 30, true, true)
	assert_false(main.notice.picture.visible, "other notices have none")


# The cheat words (w_keys.c) and F10 -------------------------------------------------

func _type(word: String) -> bool:
	var found := false
	for letter in word:
		found = main.type_letter(letter)
	return found


func test_fund_and_olpc_give_money() -> void:
	var funds := engine.get_funds()
	assert_true(_type("fund"))
	assert_eq(engine.get_funds(), funds + 10000)
	assert_true(_type("olpc"))
	assert_eq(engine.get_funds(), funds + 1010000)
	assert_false(_type("abcd"), "other words do nothing")


func test_every_fifth_fund_brings_an_earthquake() -> void:
	watch_signals(engine)
	for i in 4:
		_type("fund")
	assert_signal_not_emitted(engine, "earthquake_started")
	_type("fund")
	assert_signal_emitted(engine, "earthquake_started", "PunishCnt reached 5")


func test_fart_brings_every_disaster() -> void:
	watch_signals(engine)
	assert_true(_type("fart"))
	var messages := []
	for i in get_signal_emit_count(engine, "message_sent"):
		messages.append(get_signal_parameters(engine, "message_sent", i)[0])
	for expected in [21, 22, 23, 42]:
		assert_has(messages, expected, "monster, tornado, earthquake, flood")
	assert_signal_emitted(engine, "earthquake_started")


func test_nuke_turns_the_city_to_explosions() -> void:
	assert_true(_type("nuke"))
	var exploding := 0
	var built := 0
	for value in engine.get_map():
		var tile := value & CityEngine.TILE_INDEX_MASK
		exploding += int(tile >= 860 and tile <= 862)
		built += int(tile >= 44 and not (tile >= 414 and tile <= 422) and not (tile >= 860 and tile <= 862))
	assert_gt(exploding, 3000, "Detroit's buildings, roads and rails")
	assert_eq(built, 0, "nothing else left standing, but churches")
	assert_eq(view.city_map.shown_tile(60, 50), engine.get_map()[50 * 120 + 60] & CityEngine.TILE_INDEX_MASK,
		"and drawn at once")


func test_will_shuffles_500_pairs_of_tiles() -> void:
	var before := engine.get_map()
	assert_true(_type("will"))
	var after := engine.get_map()
	assert_false(before == after)
	var counts := {}
	for value in before:
		counts[value] = counts.get(value, 0) + 1
	for value in after:
		counts[value] = counts.get(value, 0) - 1
	assert_eq(counts.values().filter(func(n: int) -> bool: return n != 0), [], "the same tiles, moved")


func test_the_heat_words_start_and_stop() -> void:
	for word in ["bobo", "boss", "mack", "donh", "patb", "lucb", "stop"]:
		assert_true(engine.cheat(word), word)


func test_f10_opens_the_first_menu() -> void:
	main.open_first_menu()
	assert_true(main.micropolis_menu.visible, "tk_firstMenu: Micropolis")
	main.micropolis_menu.hide()
