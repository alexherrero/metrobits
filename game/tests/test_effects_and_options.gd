# The OLPC's effects and stock behaviours: the blinking lightning bolt
# on a zone without power, the earthquake's shake, the Animation, Messages
# and Notices options, the disaster questions, the budget's auto-cancel timer
# and its messages, the editor's Options (Auto Goto, Pallet Panel), and the
# close box asking the quit question.
extends GutTest

var main: Control
var engine: CityEngine


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()


## A new city with one residential zone and no power plant: its centre.
func _unpowered_zone() -> Vector2i:
	main.new_city(9)
	engine.set_funds(100000)
	var map := engine.get_map()
	for y in range(10, 90):
		for x in range(10, 110):
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					clear = clear and (map[(y + dy) * 120 + x + dx] & CityEngine.TILE_INDEX_MASK) == 0
			if clear and engine.do_tool(CityEngine.Tool.RESIDENTIAL, x, y) == CityEngine.ToolResult.OK:
				main.map_view.city_map.sync()
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# The blinking bolt (g_bigmap.c) ---------------------------------------------------

func test_a_zone_without_power_blinks_a_bolt() -> void:
	var zone := _unpowered_zone()
	assert_gt(zone.x, -1, "a zone was built")
	var city_map: CityMap = main.map_view.city_map
	var value := engine.get_map()[zone.y * 120 + zone.x]
	assert_true(value & CityEngine.TILE_ZONE_BIT and not value & CityEngine.TILE_POWERED_BIT, "no power")
	assert_has(city_map.unpowered_zones(), zone.y * 120 + zone.x)
	city_map.set_blinking(true)
	assert_eq(city_map.drawn_tile(zone.x, zone.y), CityMap.LIGHTNING_BOLT, "the bolt (LIGHTNINGBOLT, 827)")
	city_map.set_blinking(false)
	assert_eq(city_map.drawn_tile(zone.x, zone.y), value & CityEngine.TILE_INDEX_MASK, "and the zone again")


func test_powered_zones_dont_blink() -> void:
	var city_map: CityMap = main.map_view.city_map
	city_map.set_blinking(true)
	var map := engine.get_map()
	for i in city_map.unpowered_zones():
		assert_false(map[i] & CityEngine.TILE_POWERED_BIT)
	var powered := 0
	for i in map.size():
		if map[i] & CityEngine.TILE_ZONE_BIT and map[i] & CityEngine.TILE_POWERED_BIT:
			powered += 1
			assert_ne(city_map.drawn_tile(i % 120, i / 120), CityMap.LIGHTNING_BOLT)
	assert_gt(powered, 100, "Detroit's powered zones stay as they are")


func test_the_blink_is_the_second_half_of_each_second() -> void:
	assert_false(CityMap.blink_phase(0))
	assert_false(CityMap.blink_phase(499))
	assert_true(CityMap.blink_phase(500))
	assert_true(CityMap.blink_phase(1999))
	main.advance(1.0 / 60.0)
	main.advance(0.5)
	assert_eq(main.map_view.city_map.blinking, CityMap.blink_phase(Time.get_ticks_msec()),
		"set each time the loop redraws")


# The earthquake's shake (w_tk.c, w_editor.c, w_map.c) ------------------------------

func test_an_earthquake_shakes_the_editor_and_the_map_for_3_seconds() -> void:
	var view: MapView = main.map_view
	var still := view.world.position
	engine.earthquake_started.emit(1)
	assert_eq(view.shake.count, 1, "ShakeNow")
	assert_eq(main.map_window.small_map.shake.count, 1, "the map too")
	var moved := false
	for frame in 30:
		view._process(1.0 / 60.0)
		var offset := view.shake.offset
		assert_between(offset.x, -8.0, 8.0)
		assert_between(offset.y, -8.0, 8.0)
		assert_eq(view.world.position, still + offset, "the picture moves by it")
		moved = moved or offset != Vector2.ZERO
	assert_true(moved)
	engine.earthquake_started.emit(1)
	view._process(1.0 / 60.0)
	assert_eq(view.shake.count, 2, "a second quake adds to it")
	assert_between(view.shake.offset.x, -16.0, 16.0)
	view._process(3.1)
	assert_eq([view.shake.count, view.shake.offset], [0, Vector2.ZERO], "3 seconds after the last, it stops")
	assert_eq(view.world.position, still)


func test_the_shake_draws_no_numbers_from_the_city() -> void:
	var before := engine.get_map()
	var shake := Shake.new()
	shake.start()
	for i in 100:
		shake.step(0.01)
	for i in 50:
		engine.tick()
	var other := MicropolisCityEngine.new()
	other.set_fixed_seed(1989)
	other.load_scenario(CityEngine.Scenario.DETROIT)
	for i in 50:
		other.tick()
	assert_false(before == engine.get_map(), "the city moved on")
	assert_true(engine.get_map() == other.get_map(), "as it would have with no shake")


func test_the_engines_earthquake_starts_the_shake() -> void:
	main.trigger_disaster(main.DisasterItem.EARTHQUAKE)
	assert_eq(main.map_view.shake.count, 1)


# Options: Animation, Messages, Notices ---------------------------------------------

func test_the_options_default_on() -> void:
	for item: int in [main.OptionItem.ANIMATION, main.OptionItem.MESSAGES, main.OptionItem.NOTICES]:
		assert_true(main.options_menu.is_item_checked(main.options_menu.get_item_index(item)))
	assert_true(engine.get_animation() and engine.get_messages() and engine.get_notices())


func test_animation_off_stops_the_tiles_and_leaves_static_rubble() -> void:
	main.options_menu.id_pressed.emit(main.OptionItem.ANIMATION)
	assert_false(engine.get_animation())
	var city_map: CityMap = main.map_view.city_map
	var stepped := city_map.frames_stepped
	for frame in 30:
		main.advance(1.0 / 60.0)
	assert_eq(city_map.frames_stepped, stepped, "no tile animation")
	# The bulldozer's rubble (w_tool.c): SOMETINYEXP, not TINYEXP and a random one.
	var map := engine.get_map()
	for i in map.size():
		var tile := map[i] & CityEngine.TILE_INDEX_MASK
		if tile >= 244 and tile < 249:
			engine.do_tool(CityEngine.Tool.BULLDOZER, i % 120, i / 120)
			assert_eq(engine.get_map()[i] & CityEngine.TILE_INDEX_MASK, 864, "static rubble")
			break
	main.options_menu.id_pressed.emit(main.OptionItem.ANIMATION)
	for frame in 30:
		main.advance(1.0 / 60.0)
	assert_gt(city_map.frames_stepped, stepped, "and on again")


func test_messages_off_keeps_the_message_line_and_log_quiet() -> void:
	main.set_message("Before.")
	main.options_menu.id_pressed.emit(main.OptionItem.MESSAGES)
	assert_false(engine.get_messages())
	var lines: int = main.message_log.lines.size()
	main.trigger_disaster(main.DisasterItem.TORNADO)
	main.set_paused(true)
	assert_eq(main.message_label.text, "Before.", "UISetMessage returned at once")
	assert_eq(main.message_log.lines.size(), lines)


func test_notices_off_shows_none() -> void:
	main.options_menu.id_pressed.emit(main.OptionItem.NOTICES)
	assert_false(engine.get_notices())
	main.trigger_disaster(main.DisasterItem.TORNADO)
	assert_false(main.notice.visible, "UIShowPictureOn returned at once")
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.ABOUT)
	assert_false(main.notice.visible)
	main.options_menu.id_pressed.emit(main.OptionItem.NOTICES)
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.ABOUT)
	assert_true(main.notice.visible)


# Disaster questions (UIDisaster) --------------------------------------------------

func test_each_disaster_asks_first() -> void:
	var dialog: ConfirmationDialog = main.ask_dialog
	watch_signals(engine)
	main.disasters_menu.id_pressed.emit(main.DisasterItem.TORNADO)
	assert_true(dialog.visible)
	assert_eq([dialog.title, dialog.dialog_text], ["Cause a Disaster", "Oh no! Do you really want to spin up a tornado?"])
	assert_eq([dialog.get_ok_button().text, dialog.get_cancel_button().text], ["I guess so.", "No way!"])
	assert_eq((dialog.get_theme_stylebox("embedded_border") as StyleBoxFlat).bg_color, Color("#ff0000"))
	assert_signal_not_emitted(engine, "message_sent", "nothing yet")
	dialog.canceled.emit()
	dialog.hide()
	assert_signal_not_emitted(engine, "message_sent", "No way!")
	main.disasters_menu.id_pressed.emit(main.DisasterItem.TORNADO)
	dialog.confirmed.emit()
	assert_signal_emitted(engine, "message_sent", "I guess so.")
	var asked := {}
	for item: int in main.DISASTER_ACTIONS:
		main.disasters_menu.id_pressed.emit(item)
		asked[item] = dialog.dialog_text.trim_prefix("Oh no! Do you really want to ")
		dialog.hide()
	assert_eq(asked.values(), ["release a monster?", "start a fire?", "bring on a flood?", "have a nuclear meltdown?",
		"crash an airplane?", "spin up a tornado?", "cause an earthquake?"])


# The budget's timer and messages ---------------------------------------------------

func test_the_budget_auto_cancels_after_30_seconds() -> void:
	main.request_budget()
	await wait_process_frames(2)
	var budget: BudgetWindow = main.budget_window
	assert_true(budget.visible)
	assert_eq(budget.timer_button.text, "Auto Cancel In 30 Seconds (click to disable)")
	budget.tick_timer(5)
	assert_eq(budget.timer_button.text, "Auto Cancel In 25 Seconds (click to disable)")
	var tax := engine.get_tax_rate()
	budget.tax_slider.value = tax + 3
	assert_eq(budget.timer_seconds, 30, "a change starts it again")
	budget.tick_timer(30)
	assert_true(budget.visible, "0 is still shown")
	budget.tick_timer(1)
	assert_false(budget.visible, "then it cancels")
	assert_eq(engine.get_tax_rate(), tax, "the changes put back")
	assert_eq(main.message_label.text, "The budget was reset.")
	assert_false(engine.is_paused(), "and the city goes on")


func test_the_timer_can_be_turned_off_and_on() -> void:
	main.request_budget()
	await wait_process_frames(2)
	var budget: BudgetWindow = main.budget_window
	budget.timer_button.pressed.emit()
	assert_eq(budget.timer_button.text, "Enable Auto Cancel (currently disabled)")
	budget.tick_timer(100)
	assert_true(budget.visible, "no timeout while it's off")
	budget.timer_button.pressed.emit()
	assert_eq(budget.timer_seconds, 30, "on again, from 30")


func test_reset_and_the_close_box_say_the_budget_was_reset() -> void:
	main.request_budget()
	await wait_process_frames(2)
	var budget: BudgetWindow = main.budget_window
	budget.reset()
	assert_eq(main.message_label.text, "The budget was reset.")
	assert_true(budget.visible)
	budget.close_requested.emit()
	assert_false(budget.visible, "the close box is Cancel (wbudget.tcl's delete protocol)")
	assert_false(engine.is_paused())


# The editor's Options, and the close box -------------------------------------------

func test_pallet_panel_hides_and_shows_the_palette() -> void:
	var menu: PopupMenu = main.editor_options_menu
	assert_true(menu.is_item_checked(menu.get_item_index(main.OptionItem.PALLET_PANEL)))
	menu.id_pressed.emit(main.OptionItem.PALLET_PANEL)
	assert_false(main.palette.visible, "SetEditorControls 0: the palette unpacked")
	assert_false(menu.is_item_checked(menu.get_item_index(main.OptionItem.PALLET_PANEL)))
	await wait_process_frames(2)
	assert_eq(main.map_view.global_position.x, main.palette.get_parent().global_position.x, "the map takes its room")
	menu.id_pressed.emit(main.OptionItem.PALLET_PANEL)
	assert_true(main.palette.visible)


func test_auto_goto_is_in_the_editors_options() -> void:
	var menu: PopupMenu = main.editor_options_menu
	var index := menu.get_item_index(main.OptionItem.AUTO_GOTO)
	assert_eq(menu.is_item_checked(index), engine.get_auto_goto())
	menu.id_pressed.emit(main.OptionItem.AUTO_GOTO)
	assert_eq(menu.is_item_checked(index), engine.get_auto_goto())
	assert_eq(main.options_menu.get_item_index(main.OptionItem.AUTO_GOTO), -1, "not in the head's Options")


func test_the_close_box_asks_the_quit_question() -> void:
	assert_false(get_tree().auto_accept_quit, "the game decides")
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(main.ask_dialog.visible, "DeleteHeadWindow: UIQuit")
	assert_eq(main.ask_dialog.title, "Quit Playing Micropolis")
	main.ask_dialog.hide()
