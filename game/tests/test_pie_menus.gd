# The OLPC editor's pie menus (weditor.tcl's toolpie, zonepie and
# buildpie; micropolis.tcl's PieMenuDown, PieMenuMotion and PieMenuUp;
# w_piem.c's layout, hit test and popup delay), on the right button and
# Shift with the left; right-drag panning gives way, the middle button,
# Space and the trackpad still pan.
extends GutTest

var main: Control
var engine: CityEngine
var pie: PieMenus
var sounds: Sounds

const AT := Vector2(700, 450)


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	main.set_paused(true)
	pie = main.pie_menus
	sounds = main.sounds


func _press(at: Vector2, pressed := true, button := MOUSE_BUTTON_RIGHT, shift := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	return event


func _move(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	return event


func _played() -> Array:
	return sounds.played.map(func(play: Dictionary) -> String: return play.name)


func _flick(by: Vector2, from := AT) -> void:
	pie.handle(_move(from + by * 0.5))
	pie.handle(_move(from + by))
	pie.handle(_press(from + by, false))


# The definitions (weditor.tcl) ------------------------------------------------------

func test_the_three_pies_are_weditor_tcls() -> void:
	var labels := {}
	for name: String in PieMenus.PIES:
		labels[name] = PieMenus.PIES[name].items.map(func(item: Dictionary) -> String: return item.label)
	assert_eq(labels.tool, ["Road", "Bulldozer", "Zone", "Wire", "Rail", "Chalk", "Build", "Eraser"])
	assert_eq(labels.zone, ["Query", "Police", "Ind", "Com", "Res", "Fire"])
	assert_eq(labels.build, ["Airport", "Nuclear", "Seaport", "Park", "Stadium", "Coal"])
	var shape := {}
	for name: String in PieMenus.PIES:
		var spec: Dictionary = PieMenus.PIES[name]
		shape[name] = [spec.title, spec.radius, spec.initial]
	assert_eq(shape, {tool = ["Tool", 26, 0], zone = ["Zone", 20, 270], build = ["Build", 25, 270]},
		"-title, -fixedradius, -initialangle")
	var tool_items: Array = PieMenus.PIES.tool.items
	assert_eq(tool_items[1].offset, Vector2(5, 17), "Bulldozer's -xoffset 5 -yoffset 17")
	assert_eq([tool_items[2].pie, tool_items[6].pie], ["zone", "build"], "Zone and Build are pies")
	assert_eq(PieMenus.PIES.build.items[5].offset, Vector2(-11, -10), "Coal's offsets")
	var tools := []
	for name: String in PieMenus.PIES:
		for item: Dictionary in PieMenus.PIES[name].items:
			if item.has("tool"):
				tools.append(item.tool)
	assert_eq(tools.size(), 18, "every 1989 tool, chalk and eraser among them")


# Slices (CalcPieMenuItem) ---------------------------------------------------------

func test_the_pointers_direction_picks_the_slice() -> void:
	var picks := {}
	for pair: Array in [["right", Vector2(40, 0)], ["up right", Vector2(30, -30)], ["up", Vector2(0, -40)],
			["up left", Vector2(-30, -30)], ["left", Vector2(-40, 0)], ["down left", Vector2(-30, 30)],
			["down", Vector2(0, 40)], ["down right", Vector2(30, 30)]]:
		picks[pair[0]] = PieMenus.PIES.tool.items[PieMenus.item_at("tool", pair[1])].label
	assert_eq(picks, {"right": "Road", "up right": "Bulldozer", "up": "Zone", "up left": "Wire", "left": "Rail",
		"down left": "Chalk", "down": "Build", "down right": "Eraser"}, "counter-clockwise from the right")
	assert_eq(PieMenus.item_at("tool", Vector2(4, 4)), -1, "inside the 8-pixel dead zone")
	assert_eq(PieMenus.PIES.zone.items[PieMenus.item_at("zone", Vector2(0, 40))].label, "Query",
		"the Zone pie starts at the bottom (-initialangle 270)")
	assert_eq(PieMenus.PIES.build.items[PieMenus.item_at("build", Vector2(0, -40))].label, "Park")


func test_the_layout_follows_layoutpiemenu() -> void:
	var layout := PieMenus.lay_out("tool", Content.olpc_font(), ClassicTheme.MEDIUM)
	var center := Vector2(layout.center)
	var road: Rect2i = layout.items[0].rect
	var build: Rect2i = layout.items[6].rect
	assert_gt(float(road.position.x), center.x, "Road to the right of the centre")
	assert_gt(float(build.position.y), center.y, "Build below it")
	assert_eq(road.size, Vector2i(Palette.icon_texture("icroadhi").get_size()) + Vector2i(6, 6),
		"its picture, plus 2 x the active border + 2")
	var title: Rect2i = layout.title_rect
	for box: Dictionary in layout.items:
		assert_lt(title.position.y, box.rect.position.y, "the title on top")
	for i in layout.items.size():
		for j in range(i + 1, layout.items.size()):
			assert_false(Rect2(layout.items[i].rect).intersects(Rect2(layout.items[j].rect)), "items %d and %d apart" % [i, j])


# Picking (PieMenuDown, PieMenuMotion, PieMenuUp) ----------------------------------------

func test_a_flick_picks_a_tool_before_the_pie_shows_and_earns_5() -> void:
	var funds := engine.get_funds()
	main.map_view._gui_input(_press(AT))
	assert_true(pie.is_open(), "the right button opens the Tool pie")
	assert_true(pie.is_pending(), "not drawn yet: 250 ms of rest first")
	assert_has(_played(), "Woosh", "the Tool pie's -preview")
	assert_eq([sounds.played.back().volume, sounds.played.back().db], [40, 0.0], "asked for 40, played at full")
	main.map_view._gui_input(_move(AT + Vector2(30, -30)))
	main.map_view._gui_input(_press(AT + Vector2(30, -30), false))
	assert_false(pie.is_open())
	assert_eq(main.map_view.tool, CityEngine.Tool.BULLDOZER, "a flick up and right: Bulldozer")
	assert_eq(engine.get_funds(), funds + 5, "the mouse-ahead reward")
	assert_has(_played(), "Bulldozer", "its label said")
	assert_has(_played(), "Aaah")


func test_once_the_pie_shows_a_pick_earns_nothing() -> void:
	var funds := engine.get_funds()
	pie.open(AT)
	pie.step(0.3)
	assert_true(pie.shown)
	_flick(Vector2(40, 0))
	assert_eq(main.map_view.tool, CityEngine.Tool.ROAD)
	assert_eq(engine.get_funds(), funds)


func test_moving_puts_off_the_pie() -> void:
	pie.open(AT)
	pie.step(0.2)
	pie.handle(_move(AT + Vector2(3, 0)))
	pie.step(0.1)
	assert_false(pie.shown, "each move waits again (defer)")
	pie.step(0.2)
	assert_true(pie.shown)


func test_a_click_shows_the_pie_and_a_second_click_picks() -> void:
	pie.open(AT)
	pie.handle(_press(AT, false))
	assert_true(pie.shown, "released in the middle: shown at once")
	assert_eq(pie.state, PieMenus.State.CLICKED_UP)
	pie.handle(_move(AT + Vector2(-30, -30)))
	assert_eq(pie.active, -1, "nothing tracks between clicks")
	pie.handle(_press(AT + Vector2(-30, -30)))
	assert_eq(pie.active, 3, "the press tracks: Wire")
	pie.handle(_press(AT + Vector2(-30, -30), false))
	assert_eq(main.map_view.tool, CityEngine.Tool.WIRE)
	assert_false(pie.is_open())


func test_zone_opens_its_pie_where_the_pointer_is() -> void:
	pie.open(AT)
	_flick(Vector2(0, -40))
	assert_eq([pie.pie, pie.state], ["zone", PieMenus.State.SELECTED_UP], "Zone's own pie")
	assert_eq(pie.center, AT + Vector2(0, -40), "centred where the flick ended")
	assert_has(_played(), "Zone")
	var zone_at := pie.center
	pie.handle(_press(zone_at, true))
	_flick(Vector2(-35, -20), zone_at)
	assert_eq(main.map_view.tool, CityEngine.Tool.RESIDENTIAL, "up and left in the Zone pie: Res")


func test_build_then_a_click_in_it() -> void:
	pie.open(AT)
	_flick(Vector2(0, 40))
	assert_eq(pie.pie, "build")
	var at := pie.center
	pie.handle(_press(at))
	pie.handle(_press(at + Vector2(0, -40), false))
	assert_eq(main.map_view.tool, CityEngine.Tool.PARK, "Park, at the top")


func test_a_second_release_in_the_middle_cancels_with_oop() -> void:
	var tool: int = main.map_view.tool
	pie.open(AT)
	pie.handle(_press(AT, false))
	pie.handle(_press(AT))
	pie.handle(_press(AT, false))
	assert_false(pie.is_open())
	assert_has(_played(), "Oop", "CancelPie")
	assert_eq(main.map_view.tool, tool, "no tool picked")


func test_a_plain_click_past_an_open_pie_cancels_it_and_goes_to_the_editor() -> void:
	main.select_tool(CityEngine.Tool.QUERY)
	watch_signals(engine)
	pie.open(AT)
	pie.handle(_press(AT, false))
	main.map_view.size = Vector2(900, 700)
	var inside: Vector2 = main.map_view.get_global_transform() * (main.map_view.size / 2.0)
	pie._gui_input(_press(inside, true, MOUSE_BUTTON_LEFT))
	assert_false(pie.is_open(), "CancelPie")
	assert_signal_emitted(engine, "zone_status_shown", "then EditorToolDown")


func test_shift_and_the_left_button_open_it_too() -> void:
	main.map_view._gui_input(_press(AT, true, MOUSE_BUTTON_LEFT, true))
	assert_true(pie.is_open(), "InitPie's <Shift-1>")
	pie.cancel()


func test_the_right_button_no_longer_pans_but_the_middle_does() -> void:
	var view: MapView = main.map_view
	var before := view.camera_position
	var middle := _press(Vector2(300, 300), true, MOUSE_BUTTON_MIDDLE)
	view._gui_input(middle)
	var drag := _move(Vector2(330, 300))
	drag.relative = Vector2(30, 0)
	view._gui_input(drag)
	middle.pressed = false
	view._gui_input(middle)
	assert_eq(view.camera_position, before - Vector2(30, 0), "the middle button pans")
	view._gui_input(_press(Vector2(300, 300)))
	assert_true(pie.is_open(), "the right button is the pie's")
	pie.cancel()
