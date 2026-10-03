# Every tool can be picked by pointer and by key and placed by click or
# drag, funds drop by its cost, failures show feedback, and pan and zoom still
# work alongside the tools.
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
	engine.generate_map(1234)
	view.city_map.reset()
	engine.set_funds(1000000)


func _key(keycode: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _button(button: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	return event


func _motion(at: Vector2, relative := Vector2.ZERO) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	return event


## The point on screen over the middle of a tile.
func _screen(tile: Vector2i) -> Vector2:
	return view.world_to_screen((Vector2(tile) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE)


func _click(tile: Vector2i) -> void:
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, _screen(tile)))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, _screen(tile)))


func _drag(from: Vector2i, to: Vector2i) -> void:
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, _screen(from)))
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in range(1, steps + 1):
		var at := Vector2(from).lerp(Vector2(to), float(i) / steps)
		view._gui_input(_motion(_screen(Vector2i(at.round()))))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, _screen(to)))


func _tile(at: Vector2i) -> int:
	return engine.get_tile(at.x, at.y) & CityEngine.TILE_INDEX_MASK


## The top-left of a size x size square of bare dirt, near the view's middle.
func _clear_land(size: int) -> Vector2i:
	var middle := view.tile_at(view.size / 2.0)
	for radius in 40:
		for y in range(middle.y - radius, middle.y + radius + 1):
			for x in range(middle.x - radius, middle.x + radius + 1):
				if _is_clear(Vector2i(x, y), size):
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func _is_clear(at: Vector2i, size: int) -> bool:
	for dy in range(-1, size + 1):
		for dx in range(-1, size + 1):
			var x := at.x + dx
			var y := at.y + dy
			if x < 0 or y < 0 or x >= CityEngine.MAP_WIDTH or y >= CityEngine.MAP_HEIGHT:
				return false
			if _tile(Vector2i(x, y)) != 0:
				return false
	return true


func test_every_tool_is_in_the_palette_with_a_distinct_key() -> void:
	var tools := Tools.ordered()
	assert_eq(tools.size(), CityEngine.Tool.size() + 2, "all 20 tools, and the OLPC's Chalk and Eraser")
	assert_eq(tools.slice(10, 12), [Tools.CHALK, Tools.ERASER], "in 1989's order")
	var keys := {}
	for tool: int in CityEngine.Tool.values():
		assert_has(tools, tool)
		assert_true(Tools.NAMES.has(tool) and Tools.KEYS.has(tool) and Tools.CURSOR_COLORS.has(tool), "tool %d" % tool)
		keys[Tools.KEYS[tool]] = true
		assert_true(Tools.ICONS.has(tool) or Tools.ICON_TILES.has(tool), "an icon for %d" % tool)
	assert_eq(keys.size(), CityEngine.Tool.size(), "no two tools share a key")
	assert_false(keys.has(Tools.NEXT_KEY) or keys.has(Tools.PREVIOUS_KEY))


func test_every_tool_can_be_picked_by_pointer() -> void:
	var palette: Palette = main.palette
	for tool: int in Tools.ordered():
		palette.buttons[tool].pressed.emit()
		assert_eq(view.tool, tool)
		assert_eq(palette.name_label.text, Tools.NAMES[tool])
		assert_eq(palette.cost_label.text, Tools.cost_label(Tools.cost(engine, tool)))
		var icon: String = Tools.ICONS.get(tool, "")
		if icon != "":
			assert_same(palette.buttons[tool].texture_normal, Palette.icon_texture(icon + "hi"),
				"%s shows its highlighted icon" % icon)
	assert_eq(palette.cost_label.text, Tools.cost_label(Tools.cost(engine, Tools.ordered()[-1])))


func test_only_the_selected_tool_is_highlighted() -> void:
	var palette: Palette = main.palette
	main.select_tool(CityEngine.Tool.ROAD)
	main.select_tool(CityEngine.Tool.RAILROAD)
	assert_same(palette.buttons[CityEngine.Tool.ROAD].texture_normal, Content.olpc_texture("icroad"),
		"the OLPC's own Road icon")
	assert_same(palette.buttons[CityEngine.Tool.RAILROAD].texture_normal, Content.texture("images/icrailhi.png"))


func test_costs_show_as_the_original_did() -> void:
	assert_eq(Tools.cost_label(0), "free")
	assert_eq(Tools.cost_label(5), "$5")
	assert_eq(Tools.cost_label(10000), "$10,000")


func test_every_tool_can_be_picked_by_key() -> void:
	# The chalk and the eraser had no key in 1989 (X and Z reach them).
	for tool: int in Tools.ordered().filter(Tools.is_engine_tool):
		main._unhandled_key_input(_key(Tools.KEYS[tool]))
		main._unhandled_key_input(_key(Tools.KEYS[tool], false))
		assert_eq(view.tool, tool, "key %s" % OS.get_keycode_string(Tools.KEYS[tool]))
		assert_eq(main.palette.selected, tool)


func test_x_and_z_step_through_the_palette() -> void:
	var order := Tools.ordered()
	main.select_tool(order[0])
	main._unhandled_key_input(_key(Tools.NEXT_KEY))
	assert_eq(view.tool, order[1])
	main._unhandled_key_input(_key(Tools.PREVIOUS_KEY))
	main._unhandled_key_input(_key(Tools.PREVIOUS_KEY))
	assert_eq(view.tool, order[-1], "wraps around")


func test_holding_a_key_while_clicking_springs_back() -> void:
	main.select_tool(CityEngine.Tool.ROAD)
	var site := _clear_land(1)
	main._unhandled_key_input(_key(KEY_B))
	assert_eq(view.tool, CityEngine.Tool.BULLDOZER)
	_click(site)
	main._unhandled_key_input(_key(KEY_B, false))
	assert_eq(view.tool, CityEngine.Tool.ROAD, "used while held: back to the road")
	main._unhandled_key_input(_key(KEY_B))
	main._unhandled_key_input(_key(KEY_B, false))
	assert_eq(view.tool, CityEngine.Tool.BULLDOZER, "a tap keeps the bulldozer")


func test_every_building_tool_places_by_click_and_charges_its_cost() -> void:
	for tool: int in Tools.ordered().filter(Tools.is_engine_tool):
		if tool in [CityEngine.Tool.QUERY, CityEngine.Tool.BULLDOZER, CityEngine.Tool.LAND, CityEngine.Tool.WATER]:
			continue
		main.select_tool(tool)
		var size := engine.get_tool_size(tool)
		var corner := _clear_land(size)
		assert_ne(corner, Vector2i(-1, -1), "room for tool %d" % tool)
		var at := corner + (Vector2i(1, 1) if size > 1 else Vector2i.ZERO)
		var funds := engine.get_funds()
		_click(at)
		assert_eq(funds - engine.get_funds(), engine.get_tool_cost(tool), "%s's cost" % Tools.NAMES[tool])
		assert_ne(_tile(corner), 0, "%s built" % Tools.NAMES[tool])
		assert_eq(view.city_map.shown_tile(corner.x, corner.y), _tile(corner), "and drawn at once")


# The engine's terrain tools: Water runs the bulldozer first, so it needs
# something to clear (it fails on bare dirt); Land turns anything but dirt back
# into dirt, except trees, which the bulldozer clears first.
func test_the_terrain_tools_by_click() -> void:
	var site := _clear_land(1)
	main.select_tool(CityEngine.Tool.FOREST)
	_click(site)
	assert_between(_tile(site), 21, 43, "trees")
	main.select_tool(CityEngine.Tool.WATER)
	_click(site)
	assert_eq(_tile(site), 2, "water over the trees")
	main.select_tool(CityEngine.Tool.LAND)
	_click(site)
	assert_eq(_tile(site), 0, "land over the water")


func test_the_bulldozer_clears_by_click() -> void:
	var site := _clear_land(1)
	main.select_tool(CityEngine.Tool.ROAD)
	_click(site)
	assert_ne(_tile(site), 0)
	var funds := engine.get_funds()
	main.select_tool(CityEngine.Tool.BULLDOZER)
	_click(site)
	assert_eq(_tile(site), 0, "the road is gone")
	assert_eq(funds - engine.get_funds(), engine.get_tool_cost(CityEngine.Tool.BULLDOZER))


func test_dragging_paints_roads_rail_and_wire() -> void:
	for tool: int in [CityEngine.Tool.ROAD, CityEngine.Tool.RAILROAD, CityEngine.Tool.WIRE]:
		var start := _clear_land(8)
		main.select_tool(tool)
		var funds := engine.get_funds()
		_drag(start, start + Vector2i(7, 0))
		for dx in 8:
			assert_ne(_tile(start + Vector2i(dx, 0)), 0, "%s at +%d" % [Tools.NAMES[tool], dx])
		assert_eq(funds - engine.get_funds(), 8 * engine.get_tool_cost(tool), Tools.NAMES[tool])


func test_dragging_the_bulldozer_clears_a_line() -> void:
	var start := _clear_land(8)
	main.select_tool(CityEngine.Tool.ROAD)
	_drag(start, start + Vector2i(0, 5))
	main.select_tool(CityEngine.Tool.BULLDOZER)
	_drag(start, start + Vector2i(0, 5))
	for dy in 6:
		assert_eq(_tile(start + Vector2i(0, dy)), 0, "cleared at +%d" % dy)


func test_a_diagonal_drag_paints_a_connected_line() -> void:
	var start := _clear_land(8)
	main.select_tool(CityEngine.Tool.ROAD)
	_drag(start, start + Vector2i(4, 3))
	assert_ne(_tile(start), 0)
	assert_ne(_tile(start + Vector2i(4, 3)), 0)


func test_no_money_shows_a_message() -> void:
	engine.set_funds(0)
	main.select_tool(CityEngine.Tool.ROAD)
	_click(_clear_land(1))
	assert_eq(main.message_label.text, "Insufficient funds to build that.")


func test_building_on_something_shows_bulldoze_first() -> void:
	engine.set_auto_bulldoze(false)
	var site := _clear_land(3)
	main.select_tool(CityEngine.Tool.ROAD)
	_click(site + Vector2i(1, 1))
	main.select_tool(CityEngine.Tool.RESIDENTIAL)
	_click(site + Vector2i(1, 1))
	assert_eq(main.message_label.text, "Area must be bulldozed first.")


func test_the_cursor_shows_the_footprint_and_a_ghost_at_the_hovered_tile() -> void:
	main.select_tool(CityEngine.Tool.RESIDENTIAL)
	view._gui_input(_motion(_screen(Vector2i(40, 30))))
	assert_eq(view.cursor.tile, Vector2i(40, 30))
	assert_eq(view.cursor.footprint(), Rect2i(39, 29, 3, 3), "centred on a 3x3 zone")
	main.select_tool(CityEngine.Tool.AIRPORT)
	assert_eq(view.cursor.footprint(), Rect2i(39, 29, 6, 6), "the airport's corner tile")
	main.select_tool(CityEngine.Tool.ROAD)
	assert_eq(view.cursor.footprint(), Rect2i(40, 30, 1, 1))
	assert_eq(view.cursor.tool, CityEngine.Tool.ROAD)
	assert_true(Tools.GHOST_TILES.has(CityEngine.Tool.ROAD))


func test_the_ghost_is_what_the_tool_builds() -> void:
	# Each building's ghost tiles are the ones the engine lays down.
	for tool: int in [CityEngine.Tool.RESIDENTIAL, CityEngine.Tool.STADIUM, CityEngine.Tool.AIRPORT,
			CityEngine.Tool.COAL_POWER]:
		main.select_tool(tool)
		var size := engine.get_tool_size(tool)
		var corner := _clear_land(size)
		_click(corner + Vector2i(1, 1))
		assert_eq(_tile(corner), Tools.GHOST_TILES[tool], Tools.NAMES[tool])
		assert_eq(_tile(corner + Vector2i(size - 1, size - 1)), Tools.GHOST_TILES[tool] + size * size - 1)


func test_pan_and_zoom_still_work_with_a_tool() -> void:
	main.select_tool(CityEngine.Tool.ROAD)
	var funds := engine.get_funds()
	var before := view.camera_position
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, true, Vector2(300, 300)))
	view._gui_input(_motion(Vector2(330, 300), Vector2(30, 0)))
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, false, Vector2(330, 300)))
	assert_eq(view.camera_position, before - Vector2(30, 0), "a middle drag pans")
	var space := _key(KEY_SPACE)
	view._gui_input(space)
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, Vector2(300, 300)))
	view._gui_input(_motion(Vector2(300, 340), Vector2(0, 40)))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, Vector2(300, 340)))
	view._gui_input(_key(KEY_SPACE, false))
	assert_eq(view.camera_position, before - Vector2(30, 40), "Space and a left drag pan")
	assert_eq(engine.get_funds(), funds, "and build nothing")
	var wheel := _button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(300, 300))
	view._gui_input(wheel)
	assert_gt(view.get_zoom(), 1.0)
	var site := _clear_land(1)
	_click(site)
	assert_ne(_tile(site), 0, "clicks still build when zoomed")


func test_tile_icons_for_the_tools_without_originals() -> void:
	var tiles := CityMap.load_tiles()
	var normal := Palette.tile_icon(tiles, 2, false)
	var selected := Palette.tile_icon(tiles, 2, true)
	assert_eq(normal.get_size(), Vector2i(34, 34))
	assert_eq(normal.get_pixel(4, 3), Color.BLACK, "a dithered well")
	assert_eq(selected.get_pixel(4, 3), Color.WHITE, "white when selected")
	assert_eq(normal.get_pixel(10, 10), selected.get_pixel(10, 10), "the same tile in both")
