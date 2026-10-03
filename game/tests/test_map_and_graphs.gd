# The original's map window (wmap.tcl; drawn as g_map.c and
# g_smmaps.c drew it), with the whole city, its zones, transport, the
# overlays and the power grid, and the editor's view to drag; and its graph
# window (wgraph.tcl, w_graph.c) over 10 and 120 years.
extends GutTest

var main: Control
var engine: CityEngine
var small_map: SmallMap


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.open_map()
	small_map = main.map_window.small_map


func _press(at: Vector2, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _drag(by: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = by
	return event


func _items(menu: PopupMenu) -> Array:
	var out := []
	for i in menu.item_count:
		out.append(menu.get_item_text(i))
	return out


# The map window --------------------------------------------------------------

func test_the_map_opens_with_the_game_in_the_head_column() -> void:
	await wait_process_frames(3)
	assert_true(main.map_window.visible)
	assert_eq(main.map_window.title, "Micropolis Overall Map")
	assert_lt(main.map_window.position.x, main.HEAD_WIDTH, "in the head column, as the OLPC packed it")
	assert_eq(small_map.custom_minimum_size, Vector2(360, 300), "three pixels a tile")


func test_the_menus_are_wmap_tcls() -> void:
	assert_eq(_items(main.map_window.zones_menu), ["All", "Residential", "Commercial", "Industrial", "Transportation"])
	assert_eq(_items(main.map_window.overlays_menu), ["Population Density", "Rate of Growth", "Land Value",
		"Crime Rate", "Pollution Density", "Traffic Density", "Power Grid", "Fire Coverage", "Police Coverage"])


func test_each_view_has_1989s_title_and_legend() -> void:
	var window: MapWindow = main.map_window
	var legends := {}
	for mode: int in SmallMap.Mode.values():
		var menu: PopupMenu = window.zones_menu if MapWindow.ZONES.has(mode) else window.overlays_menu
		menu.id_pressed.emit(mode)
		assert_eq(small_map.mode, mode)
		assert_eq(window.title, SmallMap.TITLES[mode])
		assert_true(menu.is_item_checked(menu.get_item_index(mode)))
		legends[SmallMap.TITLES[mode]] = window.legend.kind()
	assert_eq(legends, {"Micropolis Overall Map": "", "Residential Zone Map": "", "Commercial Zone Map": "",
		"Industrial Zone Map": "", "Power Grid Map": "", "Transportation Map": "",
		"Population Density Map": "minmax", "Rate of Growth Map": "plusminus", "Traffic Density Map": "minmax",
		"Pollution Desity Map": "minmax", "Crime Rate Map": "minmax", "Land Value Map": "minmax",
		"Fire Coverage Map": "minmax", "Police Coverage Map": "minmax"}, "micropolis.tcl's UISetMapState")


func test_the_whole_city_in_small_tiles() -> void:
	var map := engine.get_map()
	var wrong := 0
	for i in map.size():
		var tile := map[i] & CityEngine.TILE_INDEX_MASK
		wrong += int(small_map.drawn_tile(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH) != (tile if tile < 960 else 0))
	assert_eq(wrong, 0, "every cell shows its tile")


func test_the_small_tiles_average_the_art() -> void:
	var art := CityMap.load_tiles()
	var small := SmallMap.small_tiles(art)
	assert_same(SmallMap.small_tiles(art), small, "made once per art")
	for tile in [0, 2, 21, 244]:
		var source := art.get_region(Rect2i((tile % 16) * 16, (tile / 16) * 16, 16, 16))
		var mean := Color(0, 0, 0)
		var small_mean := Color(0, 0, 0)
		for y in 16:
			for x in 16:
				mean += source.get_pixel(x, y) / 256.0
		for y in 3:
			for x in 3:
				small_mean += small.get_pixel((tile % 16) * 3 + x, (tile / 16) * 3 + y) / 9.0
		for channel in 3:
			assert_almost_eq(small_mean[channel], mean[channel], 0.06, "tile %d, channel %d" % [tile, channel])
	assert_eq(small.get_pixel(0 * 3, 60 * 3), SmallMap.POWERED, "then the power grid's colours")


func test_the_zone_maps_filter_as_1989s() -> void:
	var map := engine.get_map()
	for mode: int in [SmallMap.Mode.RESIDENTIAL, SmallMap.Mode.COMMERCIAL, SmallMap.Mode.INDUSTRIAL,
			SmallMap.Mode.TRANSPORTATION]:
		main.map_window.show_map(mode)
		var kept := 0
		var wrong := 0
		for i in map.size():
			var tile := map[i] & CityEngine.TILE_INDEX_MASK
			var drawn := small_map.drawn_tile(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH)
			wrong += int(drawn != SmallMap.filtered_tile(mode, tile))
			kept += int(drawn != 0 and drawn > 63)
		assert_eq(wrong, 0, SmallMap.TITLES[mode])
		assert_gt(kept, 100, "%s shows some of Detroit" % SmallMap.TITLES[mode])
	# Spot checks against g_smmaps.c's ranges.
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.RESIDENTIAL, 244), 244, "a house stays")
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.RESIDENTIAL, 436), 0, "a shop goes")
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.COMMERCIAL, 436), 436)
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.COMMERCIAL, 244), 0)
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.INDUSTRIAL, 616), 616, "a factory stays")
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.INDUSTRIAL, 244), 0)
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.TRANSPORTATION, 66), 66, "a road stays")
	assert_eq(SmallMap.filtered_tile(SmallMap.Mode.TRANSPORTATION, 212), 0, "a power line goes")


func test_the_power_grid() -> void:
	main.map_window.show_map(SmallMap.Mode.POWER_GRID)
	var map := engine.get_map()
	var counts := {powered = 0, unpowered = 0, conductive = 0, wrong = 0}
	for i in map.size():
		var value := map[i]
		var tile := value & CityEngine.TILE_INDEX_MASK
		var drawn := small_map.drawn_tile(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH)
		var expected := 0
		if tile <= 63:
			expected = tile
		elif value & CityEngine.TILE_ZONE_BIT:
			var powered := bool(value & CityEngine.TILE_POWERED_BIT)
			expected = 960 + (0 if powered else 1)
			counts["powered" if powered else "unpowered"] += 1
		elif value & CityEngine.TILE_CONDUCTIVE_BIT:
			expected = 962
			counts.conductive += 1
		counts.wrong += int(drawn != expected)
	assert_eq(counts.wrong, 0, "terrain as it is, zone centres red or blue, conductors gray, the rest bare")
	assert_gt(counts.powered, 0)
	assert_gt(counts.conductive, 0)


func test_1989s_value_classes() -> void:
	assert_eq([SmallMap.level(49), SmallMap.level(50), SmallMap.level(100), SmallMap.level(150),
		SmallMap.level(200)], [SmallMap.Value.NONE, SmallMap.Value.LOW, SmallMap.Value.MEDIUM,
		SmallMap.Value.HIGH, SmallMap.Value.VERY_HIGH], "GetCI")
	assert_eq(SmallMap.classify(SmallMap.Mode.POLLUTION, 40), SmallMap.Value.LOW, "pollution counts 10 more")
	var growth := [101, 21, 20, -20, -21, -101].map(func(v: int) -> int:
		return SmallMap.classify(SmallMap.Mode.RATE_OF_GROWTH, v))
	assert_eq(growth, [SmallMap.Value.VERY_PLUS, SmallMap.Value.PLUS, SmallMap.Value.NONE, SmallMap.Value.NONE,
		SmallMap.Value.MINUS, SmallMap.Value.VERY_MINUS])
	assert_eq(SmallMap.VALUE_COLORS.slice(1), [SmallMap.LIGHT_GRAY, SmallMap.YELLOW, SmallMap.ORANGE, SmallMap.RED,
		SmallMap.DARK_GREEN, SmallMap.LIGHT_GREEN, SmallMap.ORANGE, SmallMap.YELLOW], "valMap")


func test_the_overlays_show_the_engines_data() -> void:
	for i in 500:
		engine.tick()
	for mode: int in SmallMap.OVERLAYS:
		main.map_window.show_map(mode)
		var which: int = SmallMap.OVERLAYS[mode]
		var data := engine.get_overlay(which)
		var size := engine.get_overlay_size(which)
		var expected := 0
		for value in data:
			expected += int(SmallMap.classify(mode, value) != SmallMap.Value.NONE)
		var blocks: Array = small_map.overlay.blocks
		assert_eq(blocks.size(), expected, SmallMap.TITLES[mode])
		var side := 360 / size.x
		assert_true(side == 6 or side == 24, "half-size maps in 6-pixel blocks, eighth-size in 24")
		if not blocks.is_empty():
			assert_eq(blocks[0].rect.size, Vector2(side, side))
		if mode == SmallMap.Mode.POLLUTION or mode == SmallMap.Mode.LAND_VALUE:
			assert_gt(blocks.size(), 0, "Detroit has some")
	main.map_window.show_map(SmallMap.Mode.ALL)
	assert_eq(small_map.overlay.blocks, [], "no overlay on the city map")


func test_the_traffic_map_is_drawn_over_transport() -> void:
	main.map_window.show_map(SmallMap.Mode.TRAFFIC_DENSITY)
	assert_eq(small_map.drawn_tile(0, 0), SmallMap.filtered_tile(SmallMap.Mode.TRANSPORTATION,
		engine.get_tile(0, 0) & CityEngine.TILE_INDEX_MASK), "drawLilTransMap under it")


func test_the_view_rectangle_is_the_editors_view() -> void:
	var world: Rect2 = main.map_view.visible_world_rect()
	var view := small_map.view_rect()
	assert_almost_eq(view.position, (world.position * 3.0 / 16.0).floor(), Vector2(0.01, 0.01))
	assert_almost_eq(view.size, (world.size * 3.0 / 16.0).floor(), Vector2(0.01, 0.01))


func test_dragging_the_rectangle_moves_the_editor() -> void:
	main.map_view.zoom_at(0.5 / main.map_view.get_zoom(), main.map_view.size / 2.0)
	main.map_view.center_on_tile(Vector2i(60, 50))
	var before: Vector2 = main.map_view.camera_position
	var view := small_map.view_rect()
	small_map._gui_input(_press(view.get_center()))
	small_map._gui_input(_drag(Vector2(3, -3)))
	small_map._gui_input(_press(view.get_center(), false))
	assert_eq(main.map_view.camera_position, before + Vector2(16, -16), "16/3 of the editor's pixels for each")
	# Away from the rectangle, as in 1989, a drag does nothing.
	before = main.map_view.camera_position
	var away := small_map.view_rect().position - Vector2(20, 20)
	small_map._gui_input(_press(away))
	small_map._gui_input(_drag(Vector2(5, 5)))
	small_map._gui_input(_press(away, false))
	assert_eq(main.map_view.camera_position, before)


func test_the_map_follows_the_city() -> void:
	engine.set_funds(100000)
	var site := Vector2i(-1, -1)
	for y in range(5, 95):
		for x in range(5, 115):
			if engine.get_tile(x, y) & CityEngine.TILE_INDEX_MASK == 0 and site.x < 0:
				site = Vector2i(x, y)
	engine.do_tool(CityEngine.Tool.ROAD, site.x, site.y)
	main.map_window.refresh()
	assert_eq(small_map.drawn_tile(site.x, site.y), engine.get_tile(site.x, site.y) & CityEngine.TILE_INDEX_MASK)
	assert_ne(small_map.drawn_tile(site.x, site.y), 0)


func test_windows_map_reopens_it() -> void:
	main.map_window.hide()
	main.windows_menu.id_pressed.emit(main.WindowItem.MAP)
	assert_true(main.map_window.visible)


# The graph window ------------------------------------------------------------

func test_the_graph_window_is_wgraph_tcls() -> void:
	main.windows_menu.id_pressed.emit(main.WindowItem.GRAPH)
	var window: GraphWindow = main.graph_window
	assert_true(window.visible)
	assert_eq(window.switches.map(func(b: TextureButton) -> String: return b.tooltip_text.get_slice(":", 0)),
		["Residential", "Commercial", "Industrial", "Cash Flow", "Crime", "Pollution"])
	assert_eq(window.year_buttons.map(func(b: TextureButton) -> String: return b.tooltip_text), ["10 Years", "120 Years"])
	assert_eq(window.graph.mask, GraphView.ALL, "every graph on, as InitGraph")
	assert_eq(window.graph.history_scale, CityEngine.HistoryScale.SHORT, "over 10 years")
	window.switches[4].pressed.emit()
	assert_eq(window.graph.mask, GraphView.ALL & ~(1 << 4), "crime off")
	assert_same(window.switches[4].texture_normal, Content.olpc_texture("grcrim"), "off: its plain picture")
	assert_same(window.switches[0].texture_normal, Content.olpc_texture("grreshi"), "on: its hi picture")
	window.year_buttons[1].pressed.emit()
	assert_eq(window.graph.history_scale, CityEngine.HistoryScale.LONG)
	assert_same(window.year_buttons[1].texture_normal, Content.olpc_texture("gr120hi"))


func test_a_new_game_starts_the_graphs_afresh() -> void:
	var window: GraphWindow = main.graph_window
	window.toggle(0)
	window.set_years(CityEngine.HistoryScale.LONG)
	main.load_scenario(CityEngine.Scenario.BERN)
	assert_eq([window.graph.mask, window.graph.history_scale], [GraphView.ALL, CityEngine.HistoryScale.SHORT])


func test_1989s_colours_and_scaling() -> void:
	assert_eq(GraphView.COLORS, [Color("#00e600"), Color("#0000e6"), Color("#ffff00"), Color("#007f00"),
		Color("#ff0000"), Color("#997f4c")], "HistColor")
	var values := PackedInt32Array()
	values.resize(120)
	values[0] = 300
	values[119] = 999
	assert_eq(GraphView.rci_factor([values]), 128.0 / 300, "the oldest isn't counted")
	values[0] = 100
	assert_eq(GraphView.rci_factor([values]), 1.0, "no scaling up to 128")
	var plotted := GraphView.plotted(values, 2.0)
	assert_eq(plotted[119], 200, "newest last, scaled")
	assert_eq(plotted[0], 255, "clamped to 255")


func test_the_graph_plots_the_engines_history() -> void:
	var view: GraphView = main.graph_window.graph
	var year := engine.get_year()
	while engine.get_year() < year + 2:
		engine.tick()
	var plots: Array = view.plots()
	assert_eq(plots.size(), 6)
	var residential: PackedInt32Array = plots[CityEngine.HistoryType.RESIDENTIAL]
	assert_gt(residential[119], 0, "Detroit has people")
	assert_eq(residential[119], mini(int(engine.get_history(CityEngine.HistoryType.RESIDENTIAL,
		CityEngine.HistoryScale.SHORT)[0] * GraphView.rci_factor([engine.get_history(0, 0),
		engine.get_history(1, 0), engine.get_history(2, 0)])), 255))
	assert_true(engine.history_changed.is_connected(view.queue_redraw), "redrawn when the engine's census changes")


func test_the_year_lines_as_1989_drew_them() -> void:
	var view: GraphView = main.graph_window.graph
	while engine.get_city_time() % 48 != 20:
		engine.tick()
	var year := engine.get_year()
	var month := (engine.get_city_time() / 4) % 12
	var marks := view.year_marks()
	assert_eq(marks[0].x, 120.0 - month)
	assert_eq(marks[0].label, str(year))
	assert_eq(marks[1].x, 120.0 - month - 12)
	assert_eq(marks[1].label, str(year - 1))
	assert_ne(marks[0].lift, marks[1].lift, "labels alternate high and low")
	view.history_scale = CityEngine.HistoryScale.LONG
	marks = view.year_marks()
	assert_eq(marks[0].label, "%d0" % (year / 10), "decades over 120 years")
	assert_eq(marks[0].x, (1200 - 10 * (year % 10)) / 10.0)


# The OLPC head's small graph (whead.tcl's graphview, Range 10, Mask 7):
# residential, commercial and industrial over 10 years, between the demand
# gauge and the numbers; a click shows or hides the graph window
# (ToggleGraphOf).
func test_the_heads_small_graph_is_rci_over_10_years_beside_the_gauge() -> void:
	var graph: GraphView = main.head.graph
	assert_eq(graph.mask, 0b000111, "residential, commercial and industrial")
	assert_eq(graph.history_scale, CityEngine.HistoryScale.SHORT, "10 years")
	var row: Control = main.head.gauge.get_parent().get_parent()
	assert_eq(graph.get_parent().get_parent(), row, "in the gauge's frame (whead.tcl's f1.frame)")
	assert_eq(graph.get_parent().get_index(), main.head.gauge.get_parent().get_index() + 1, "just after the gauge")
	await get_tree().process_frame
	assert_gt(graph.size.x, 60.0, "it takes the room between the gauge and the numbers")
	assert_true(graph.global_position.x > main.head.gauge.global_position.x + main.head.gauge.size.x)
	assert_true(graph.global_position.x + graph.size.x < main.head.date_label.global_position.x)


func test_the_heads_small_graph_plots_the_engines_history() -> void:
	for i in 3000:
		engine.tick()
	var graph: GraphView = main.head.graph
	var window_graph: GraphView = main.graph_window.graph
	var plots := graph.plots()
	var full := window_graph.plots()
	for type in 3:
		assert_eq(plots[type], full[type], "%s as the graph window plots it" % GraphView.NAMES[type])
	assert_true(engine.history_changed.is_connected(graph.queue_redraw), "and it redraws when the history does")


func test_a_click_on_the_small_graph_shows_or_hides_the_graph_window() -> void:
	assert_false(main.graph_window.visible)
	main.head.graph.gui_input.emit(_press(Vector2(10, 10)))
	assert_true(main.graph_window.visible, "shown")
	main.head.graph.gui_input.emit(_press(Vector2(10, 10), false))
	assert_true(main.graph_window.visible, "a release does nothing")
	main.head.graph.gui_input.emit(_press(Vector2(10, 10)))
	assert_false(main.graph_window.visible, "hidden again")
