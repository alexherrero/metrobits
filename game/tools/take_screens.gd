## Drives the real game window through scripted steps and saves screenshots
## for the planning session's review. Run it windowed, not headless:
##   godot --path game --script res://tools/take_screens.gd -- --out=<dir> --seed=1989
## --only=<step> takes only that step's screens (1.6, 1.7, 1.7a, 1.8, 1.8a, 1.9,
## 1.9a, F1 to F6, 4.1, 4.4 and 3.4).
## The game keeps its settings in memory, so the player's settings.cfg is
## neither read nor changed. It starts as the game does, on the city chooser.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
extends SceneTree

var main: Control
var out := ""


func _initialize() -> void:
	var args: Dictionary = load("res://main.gd").parse_args(OS.get_cmdline_user_args())
	out = str(args.get("out", "user://screens"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	main = load("res://main.tscn").instantiate()
	main.settings_path = ""
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	var args: Dictionary = main.parse_args(OS.get_cmdline_user_args())
	var only := str(args.get("only", ""))
	var steps := {"1.6": _building, "1.7": _feedback, "1.7a": _review_fixes, "1.8": _beyond_stages,
		"1.8a": _start_and_pace, "1.9": _maps_and_graphs, "1.9a": _before_play,
		"F1": _olpc_assets, "F2": _painted_chooser, "F3": _head_window, "F4": _effects, "F5": _chalk_and_small_things, "F6": _pie_menus, "4.1": _about, "4.4": _font_smoothing, "3.4": _gpl_art_only}
	for step: String in steps:
		if only == "" or only == step:
			await steps[step].call()
	Content.note_used()
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


## Runs the game at a Priority (default Normal).
func _play(priority: int = 2) -> void:
	main.set_priority(priority)
	main.set_paused(false)


func _save(name: String, points := Rect2()) -> Image:
	var image := await _grab(points)
	var path := ProjectSettings.globalize_path(out).path_join(name)
	var error := image.save_png(path)
	print("screen %s: %s" % [path, error_string(error)])
	return image


## The window as drawn, or a part of it given in points.
func _grab(points := Rect2()) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if points.has_area():
		var scale := root.content_scale_factor
		image = image.get_region(Rect2i(points.position * scale, points.size * scale))
	return image


## A window's rectangle in points, with its title bar and frame.
func _window_rect(window: Window) -> Rect2:
	var title := window.get_theme_constant("title_height", "Window")
	return Rect2(Vector2(window.position) - Vector2(4, title + 4), Vector2(window.size) + Vector2(8, title + 8))


## The top-left of a size x size square of bare dirt nearest `near`.
func _clear_land(near: Vector2i, size: int) -> Vector2i:
	var engine: CityEngine = main.engine
	for radius in 60:
		for y in range(near.y - radius, near.y + radius + 1):
			for x in range(near.x - radius, near.x + radius + 1):
				var clear := x > 0 and y > 0 and x + size < CityEngine.MAP_WIDTH and y + size < CityEngine.MAP_HEIGHT
				for dy in range(-1, size + 1) if clear else []:
					for dx in range(-1, size + 1):
						if engine.get_tile(x + dx, y + dy) & CityEngine.TILE_INDEX_MASK != 0:
							clear = false
				if clear:
					return Vector2i(x, y)
	return near


## 1.6: a new city laid out by clicks and drags, a ghost at the pointer,
## and the message when money runs out.
func _building() -> void:
	var view: MapView = main.map_view
	var engine: CityEngine = main.engine
	main.new_city(4)
	var origin := _clear_land(Vector2i(60, 50), 14)
	view.center_on_tile(origin + Vector2i(8, 6))
	main.set_paused(true)
	main.select_tool(CityEngine.Tool.ROAD)
	for y in [0, 4, 8]:
		view.click_tile(origin + Vector2i(0, y))
		view.drag_tiles(origin + Vector2i(0, y), origin + Vector2i(12, y))
	view.drag_tiles(origin, origin + Vector2i(0, 8))
	view.drag_tiles(origin + Vector2i(12, 0), origin + Vector2i(12, 8))
	var zones := [CityEngine.Tool.RESIDENTIAL, CityEngine.Tool.RESIDENTIAL, CityEngine.Tool.COMMERCIAL,
		CityEngine.Tool.INDUSTRIAL, CityEngine.Tool.RESIDENTIAL, CityEngine.Tool.POLICE_STATION]
	for i in zones.size():
		main.select_tool(zones[i])
		view.click_tile(origin + Vector2i(2 + (i % 3) * 4, 2 + (i / 3) * 4))
	main.select_tool(CityEngine.Tool.WIRE)
	view.click_tile(origin + Vector2i(13, 2))
	view.drag_tiles(origin + Vector2i(13, 2), origin + Vector2i(16, 2))
	main.select_tool(CityEngine.Tool.COAL_POWER)
	view.click_tile(origin + Vector2i(17, 2))
	_play()
	await _seconds(2.0)
	main.select_tool(CityEngine.Tool.INDUSTRIAL)
	view.cursor.tile = origin + Vector2i(6, 11)
	view.cursor.visible = true
	await _frames(3)
	await _save("1.6-building.png")
	engine.set_funds(0)
	main.select_tool(CityEngine.Tool.ROAD)
	view.click_tile(origin + Vector2i(6, 12))
	view.cursor.tile = origin + Vector2i(6, 12)
	await _frames(3)
	await _save("1.6-no-money.png")


## 1.7: a disaster's toast and auto-goto, the Query tool's report, the
## budget window, and the Disasters menu.
func _feedback() -> void:
	var view: MapView = main.map_view
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	await _seconds(1.0)
	main.trigger_disaster(main.DisasterItem.TORNADO)
	await _seconds(1.5)
	await _save("1.7-tornado-toast.png")
	main.select_tool(CityEngine.Tool.QUERY)
	var zone := Vector2i(-1, -1)
	for y in range(40, 60):
		for x in range(40, 80):
			if zone == Vector2i(-1, -1) and engine.get_tile(x, y) & CityEngine.TILE_ZONE_BIT:
				zone = Vector2i(x, y)
	view.center_on_tile(zone)
	view.click_tile(zone)
	view.cursor.tile = zone
	view.cursor.visible = true
	await _frames(3)
	await _save("1.7-query.png")
	# Past the first year's taxes, so the budget has figures.
	while engine.get_budget().tax_income == 0:
		engine.tick()
	main.map_view.city_map.sync()
	main.message_log.add("(ran to %s)" % HeadPanel.format_date(engine.get_year(), engine.get_month()))
	main.request_budget()
	await _frames(5)
	await _save("1.7-budget.png")
	main.budget_window.close(false)
	var bar_menu: PopupMenu = main.disasters_menu
	bar_menu.popup(Rect2i(Vector2i(118, 26), Vector2i.ZERO))
	await _frames(5)
	await _save("1.7-disasters-menu.png")
	bar_menu.hide()


## 1.7a: the city in both tile sets, and alerts one at a time at the foot of
## the head column, clear of the map and the budget window.
func _review_fixes() -> void:
	var view: MapView = main.map_view
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.set_paused(true)
	view.center_on_tile(Vector2i(62, 50))
	await _frames(5)
	await _save("1.7a-tiles-olpc.png")
	_play()
	main.trigger_disaster(main.DisasterItem.TORNADO)
	await _seconds(1.0)
	await _save("1.7a-alert-tornado.png")
	main.trigger_disaster(main.DisasterItem.EARTHQUAKE)
	await _seconds(0.5)
	main.trigger_disaster(main.DisasterItem.FLOOD)
	await _seconds(0.5)
	main.trigger_disaster(main.DisasterItem.FIRE)
	await _seconds(1.0)
	await _save("1.7a-alerts-run.png")
	main.trigger_disaster(main.DisasterItem.MONSTER)
	await _frames(3)
	main.request_budget()
	await _frames(5)
	await _save("1.7a-alert-and-budget.png")
	main.budget_window.close(false)


## Centres the editor on the first live sprite of a type, at a zoom. Returns it.
func _look_at_sprite(type: int, zoom: float) -> Dictionary:
	var view: MapView = main.map_view
	view.zoom_at(zoom / view.get_zoom(), view.size / 2.0)
	var sprite: Dictionary = view.sprites.find(type)
	if not sprite.is_empty():
		view.camera_position = SpriteLayer.center_of(sprite)
	return sprite


## Runs the game until a sprite of a type is live, up to `seconds`.
func _wait_for_sprite(type: int, seconds: float) -> Dictionary:
	var waited := 0.0
	while waited < seconds:
		var sprite: Dictionary = main.map_view.sprites.find(type)
		if not sprite.is_empty():
			return sprite
		await _seconds(0.1)
		waited += 0.1
	return {}


## 1.8: the city chooser, the evaluation, the sprites (a tornado caught
## moving, the monster, trains, ships and the helicopter), an air crash, and
## the file chooser.
func _beyond_stages() -> void:
	var view: MapView = main.map_view
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	await _frames(3)
	main.open_city_chooser()
	await _frames(5)
	await _save("1.8-new-city.png")
	main.new_city_screen.activate("medium")
	main.new_city_screen.activate("generate")
	main.new_city_screen.name_edit.text = "Pixelburg"
	await _frames(5)
	await _save("1.8-new-city-next-map.png")
	main.new_city_screen.activate("play")
	await _frames(10)
	await _save("1.8-new-city-playing.png")

	# The evaluation, after Detroit's first year.
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	var year := engine.get_year()
	while engine.get_year() == year or engine.get_evaluation().problems.is_empty():
		engine.tick()
	view.city_map.sync()
	view.sprites.sync()
	main.open_evaluation()
	await _frames(5)
	await _save("1.8-evaluation.png")
	main.evaluation_window.hide()

	# A tornado, caught moving: two screens half a second apart.
	_play()
	var tornado := {}
	for attempt in 10:
		main.trigger_disaster(main.DisasterItem.TORNADO)
		await _seconds(0.6)
		tornado = main.map_view.sprites.find(CityEngine.SpriteType.TORNADO)
		if not tornado.is_empty():
			break
	_look_at_sprite(CityEngine.SpriteType.TORNADO, 2.0)
	await _frames(2)
	await _save("1.8-tornado-1.png")
	await _seconds(0.5)
	await _save("1.8-tornado-2.png")

	# The monster, in Tokyo. Before local edit 12 the engine killed a monster
	# whose first step was on river water, which most were, so until one lives.
	main.load_scenario(CityEngine.Scenario.TOKYO)
	for attempt in 20:
		main.trigger_disaster(main.DisasterItem.MONSTER)
		await _seconds(1.5)
		if not main.map_view.sprites.find(CityEngine.SpriteType.MONSTER).is_empty():
			break
	_look_at_sprite(CityEngine.SpriteType.MONSTER, 2.0)
	await _frames(2)
	await _save("1.8-monster.png")

	# Traffic: a train, a ship and the helicopter, in a city with all three.
	main.load_scenario(CityEngine.Scenario.TOKYO)
	engine.set_disasters_enabled(false)
	for type: int in [CityEngine.SpriteType.TRAIN, CityEngine.SpriteType.SHIP, CityEngine.SpriteType.HELICOPTER]:
		var sprite := await _wait_for_sprite(type, 20.0)
		if sprite.is_empty():
			print("no sprite of type %d" % type)
			continue
		_look_at_sprite(type, 3.0)
		await _frames(2)
		await _save("1.8-sprite-%s.png" % CityEngine.SpriteType.keys()[type].to_lower())

	# An air crash: the plane in the air, then its explosion and its fire.
	var plane := await _wait_for_sprite(CityEngine.SpriteType.AIRPLANE, 60.0)
	if not plane.is_empty():
		_play(main.Priority.SLOW)
		_look_at_sprite(CityEngine.SpriteType.AIRPLANE, 3.0)
		await _frames(2)
		await _save("1.8-air-crash-1-plane.png")
		main.trigger_disaster(main.DisasterItem.AIR_CRASH)
		var crash := SpriteLayer.center_of(_look_at_sprite(CityEngine.SpriteType.EXPLOSION, 3.0))
		# The explosion lasts 12 ticks, a fifth of a second.
		await _frames(5)
		main.set_paused(true)
		await _frames(2)
		await _save("1.8-air-crash-2-explosion.png")
		_play(main.Priority.SLOW)
		await _seconds(3.0)
		view.camera_position = crash
		await _frames(2)
		await _save("1.8-air-crash-3-fire.png")
	else:
		print("no plane took off")

	# Save City as...
	main.set_paused(true)
	main.ask_to_save_city()
	await _frames(5)
	await _save("1.8-save-city-as.png")
	main.file_dialog.hide()


## 1.8a: the chooser the game opens on, Tokyo's own monster on the rampage,
## and the Priority menu.
func _start_and_pace() -> void:
	var view: MapView = main.map_view
	var engine: CityEngine = main.engine
	main.open_city_chooser()
	await _frames(5)
	await _save("1.8a-chooser-at-start.png")

	# Tokyo's Monster Attack: the scenario sets its monster off by itself.
	main.new_city_screen.activate(NewCityScreen.scenario_button(CityEngine.Scenario.TOKYO))
	main.new_city_screen.activate("play")
	main.notice.dismiss()
	engine.set_auto_goto(false)
	_play()
	var monster := await _wait_for_sprite(CityEngine.SpriteType.MONSTER, 10.0)
	if monster.is_empty():
		print("Tokyo's monster didn't come")
	await _seconds(6.0)
	_look_at_sprite(CityEngine.SpriteType.MONSTER, 1.5)
	await _frames(2)
	await _save("1.8a-tokyo-monster-1.png")
	await _seconds(4.0)
	_look_at_sprite(CityEngine.SpriteType.MONSTER, 1.5)
	await _frames(2)
	await _save("1.8a-tokyo-monster-2.png")

	# The Priority menu, open.
	var bar: MenuBar = main.priority_menu.get_parent()
	var x := 0.0
	for i in bar.get_menu_count():
		if bar.get_menu_popup(i) == main.priority_menu:
			break
		x += bar.get_theme_font("font").get_string_size(bar.get_menu_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1,
			bar.get_theme_font_size("font_size")).x + 16
	main.priority_menu.popup(Rect2i(Vector2i(bar.global_position + Vector2(x, bar.size.y)), Vector2i.ZERO))
	await _frames(5)
	await _save("1.8a-priority-menu.png")
	main.priority_menu.hide()


## 1.9: every one of the map window's views, the whole game with the map, and
## the graph window over 10 and 120 years, on Detroit two years on.
func _maps_and_graphs() -> void:
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	engine.set_auto_goto(false)
	for i in 1600:
		engine.tick()
	main.map_view.city_map.sync()
	main.map_view.sprites.sync()
	main.map_view.center_on_tile(Vector2i(50, 40))
	main.set_paused(true)
	main.open_map()
	await _frames(5)
	await _save("1.9-map-window.png")
	var window: MapWindow = main.map_window
	for mode: int in SmallMap.Mode.values():
		window.show_map(mode)
		await _frames(3)
		var slug: String = SmallMap.TITLES[mode].to_lower().replace(" ", "-").replace("micropolis-", "")
		await _save("1.9-map-%02d-%s.png" % [mode, slug], _window_rect(window))
	window.show_map(SmallMap.Mode.ALL)
	main.open_graph()
	await _frames(5)
	await _save("1.9-graph-10-years.png")
	main.graph_window.set_years(CityEngine.HistoryScale.LONG)
	await _frames(5)
	await _save("1.9-graph-120-years.png")
	main.graph_window.hide()


## F1: the OLPC's own assets in use, on Detroit two years on: the whole
## window (DejaVu LGC Sans, Tk's colours and bevels); the graph window's
## picture switches, all on over 10 years, then Crime off over 120; the map's
## small tiles (tilessm.xpm) and its legends (legendmm.xpm, legendpm.xpm).
func _olpc_assets() -> void:
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_auto_goto(false)
	for i in 1600:
		engine.tick()
	main.map_view.city_map.sync()
	main.map_view.sprites.sync()
	main.map_view.center_on_tile(Vector2i(50, 40))
	main.set_paused(true)
	main.open_map()
	main.open_graph()
	await _frames(5)
	await _save("F1-window.png")
	await _save("F1-graph-window.png", _window_rect(main.graph_window))
	main.graph_window.toggle(CityEngine.HistoryType.CRIME)
	main.graph_window.set_years(CityEngine.HistoryScale.LONG)
	await _frames(3)
	await _save("F1-graph-window-crime-off-120-years.png", _window_rect(main.graph_window))
	main.graph_window.hide()
	var window: MapWindow = main.map_window
	await _save("F1-small-map.png", _window_rect(window))
	window.show_map(SmallMap.Mode.CRIME)
	await _frames(3)
	await _save("F1-map-legend-crime.png", _window_rect(window))
	window.show_map(SmallMap.Mode.RATE_OF_GROWTH)
	await _frames(3)
	await _save("F1-map-legend-rate-of-growth.png", _window_rect(window))
	window.show_map(SmallMap.Mode.ALL)


## F2: the painted chooser: as the game opens on it (a map generated,
## notice 48 in the panel); the pointer on Load City and on Medium; the
## pointer on Hamburg, with its story; Hamburg shown in the map; the About
## city with notice 49; the Quit question; and the game after Play This Map.
func _painted_chooser() -> void:
	var screen: NewCityScreen = main.new_city_screen
	main.open_city_chooser()
	await _frames(5)
	await _save("F2-chooser.png")
	screen.point_at(NewCityScreen.BUTTONS[NewCityScreen.button_index("load")].rect.get_center())
	await _frames(2)
	await _save("F2-hover-load-city.png")
	screen.point_at(NewCityScreen.BUTTONS[NewCityScreen.button_index("medium")].rect.get_center())
	await _frames(2)
	await _save("F2-hover-medium.png")
	var hamburg: Vector2 = NewCityScreen.BUTTONS[NewCityScreen.button_index("scenario3")].rect.get_center()
	screen.point_at(hamburg)
	await _frames(2)
	await _save("F2-hover-hamburg.png")
	screen.press_at(hamburg)
	screen.release_at(hamburg)
	screen.point_at(Vector2(700, 200))
	await _frames(3)
	await _save("F2-hamburg-shown.png")
	screen.activate("about")
	await _frames(3)
	await _save("F2-about-city.png")
	screen.activate("quit")
	await _frames(3)
	await _save("F2-quit-question.png")
	main.ask_dialog.hide()
	screen.activate("left")
	screen.activate("play")
	await _frames(10)
	await _save("F2-hamburg-playing.png")


## F3: the head window on Detroit a year on: running (the green logo), the
## tax slider moved to 9%, the log with a year's messages, its Score line and
## a red line from a city that wouldn't save; then stopped (the red logo);
## and the evaluation from a click on the gauge.
func _head_window() -> void:
	var engine: CityEngine = main.engine
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	engine.set_auto_goto(false)
	for i in 700:
		engine.tick()
	main.map_view.city_map.sync()
	main.map_view.sprites.sync()
	main.head.tax_slider.value = 9
	engine.city_save_failed.emit("/Volumes/XO/detroit.cty")
	await _frames(5)
	var head_rect := Rect2(Vector2.ZERO, Vector2(main.HEAD_WIDTH, main.message_log.global_position.y
		+ main.message_log.size.y))
	await _save("F3-head-running.png", head_rect)
	await _save("F3-window.png")
	main.toggle_pause()
	await _frames(3)
	await _save("F3-head-stopped.png", head_rect)
	main.toggle_pause()
	main.toggle_evaluation()
	await _frames(5)
	await _save("F3-evaluation-from-the-gauge.png")
	main.evaluation_window.hide()


## F4: a new city with zones and no power, its bolts on and off; an
## earthquake's shake, two frames; the Options menu with Animation, Messages
## and Notices; a disaster's question; the budget with its timer; the
## editor's Options menu; and the editor with the Pallet Panel off.
func _effects() -> void:
	var engine: CityEngine = main.engine
	main.new_city(9)
	engine.set_funds(100000)
	var site := _clear_land(Vector2i(60, 50), 11)
	for dy in 3:
		for dx in 3:
			engine.do_tool(CityEngine.Tool.RESIDENTIAL if (dx + dy) % 2 == 0 else CityEngine.Tool.COMMERCIAL,
				site.x + 1 + dx * 3, site.y + 1 + dy * 3)
	main.map_view.city_map.sync()
	main.map_view.center_on_tile(site + Vector2i(5, 5))
	main.map_view.zoom_at(2.0, main.map_view.size / 2.0)
	main.set_paused(true)
	main.notice.dismiss()
	var editor_rect := Rect2(main.map_view.global_position, main.map_view.size)
	main.map_view.city_map.set_blinking(false)
	await _frames(3)
	await _save("F4-bolts-off.png", editor_rect)
	main.map_view.city_map.set_blinking(true)
	await _frames(3)
	await _save("F4-bolts-on.png", editor_rect)
	main.map_view.city_map.set_blinking(false)
	main.map_view.zoom_at(0.5, main.map_view.size / 2.0)

	main.load_scenario(CityEngine.Scenario.SAN_FRANCISCO)
	main.notice.dismiss()
	main.set_paused(true)
	main.open_map()
	engine.earthquake_started.emit(1)
	engine.earthquake_started.emit(1)
	for shot in 2:
		main.map_view.shake.step(1.0 / 60.0)
		main.map_view._clamp_camera()
		main.map_window.small_map._process(1.0 / 60.0)
		await _frames(1)
		await _save("F4-earthquake-shake-%d.png" % (shot + 1))
	main.map_view.shake.stop()
	main.map_window.small_map.shake.stop()
	main.map_window.small_map._process(0.0)
	main.map_view._clamp_camera()

	var bar: MenuBar = main.options_menu.get_parent()
	var x := 0.0
	for i in bar.get_menu_count():
		if bar.get_menu_popup(i) == main.options_menu:
			break
		x += bar.get_theme_font("font").get_string_size(bar.get_menu_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1,
			bar.get_theme_font_size("font_size")).x + 16
	main.options_menu.popup(Rect2i(Vector2i(bar.global_position + Vector2(x, bar.size.y)), Vector2i.ZERO))
	await _frames(5)
	await _save("F4-options-menu.png")
	main.options_menu.hide()
	main.disasters_menu.id_pressed.emit(main.DisasterItem.EARTHQUAKE)
	await _frames(5)
	await _save("F4-disaster-question.png")
	main.ask_dialog.hide()
	main.request_budget()
	await _frames(5)
	main.budget_window.tick_timer(4)
	await _frames(3)
	await _save("F4-budget-timer.png")
	main.budget_window.close(false)
	var editor_bar: MenuBar = main.editor_options_menu.get_parent()
	main.editor_options_menu.popup(Rect2i(Vector2i(editor_bar.global_position + Vector2(0, editor_bar.size.y)),
		Vector2i.ZERO))
	await _frames(5)
	await _save("F4-editor-options-menu.png")
	main.editor_options_menu.hide()
	main.set_option(main.OptionItem.PALLET_PANEL, false)
	await _frames(5)
	await _save("F4-pallet-panel-off.png")
	main.set_option(main.OptionItem.PALLET_PANEL, true)


## F5: the palette with Chalk and Eraser in their slots and our four apart;
## chalk on Detroit, with its cursor, in the editor and the map; the eraser's
## cursor; the pan cross; and the win notice's key to the city.
func _chalk_and_small_things() -> void:
	var view: MapView = main.map_view
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	main.set_paused(true)
	main.open_map()
	main.select_tool(Tools.CHALK)
	await _frames(3)
	var palette_rect := Rect2(main.palette.global_position, main.palette.size)
	await _save("F5-palette.png", palette_rect)
	# A ring and an arrow in chalk, drawn as a player would.
	var middle := view.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	for stroke: Array in [_ring(middle + Vector2(-60, -40), 70.0), [middle + Vector2(60, 120),
			middle + Vector2(20, 40), middle + Vector2(0, 70), middle + Vector2(20, 40), middle + Vector2(50, 60)]]:
		press.pressed = true
		press.position = stroke[0]
		view._gui_input(press)
		for point: Vector2 in stroke.slice(1):
			var move := InputEventMouseMotion.new()
			move.position = point
			view._gui_input(move)
		press.pressed = false
		view._gui_input(press)
	var hover := InputEventMouseMotion.new()
	hover.position = middle + Vector2(140, 20)
	view._gui_input(hover)
	view.cursor.visible = true
	main.map_window.small_map.refresh()
	await _frames(3)
	await _save("F5-chalk.png")
	main.select_tool(Tools.ERASER)
	view._gui_input(hover)
	await _frames(2)
	await _save("F5-eraser-cursor.png", Rect2(view.global_position + hover.position - Vector2(80, 80), Vector2(160, 160)))
	var pan := InputEventMouseButton.new()
	pan.button_index = MOUSE_BUTTON_MIDDLE
	pan.pressed = true
	pan.position = hover.position
	view._gui_input(pan)
	view._gui_input(hover)
	await _frames(2)
	await _save("F5-pan-cross.png", Rect2(view.global_position + hover.position - Vector2(80, 80), Vector2(160, 160)))
	pan.pressed = false
	view._gui_input(pan)
	main.select_tool(CityEngine.Tool.BULLDOZER)
	main._on_message(main.SCENARIO_WON, -1, -1, true, true)
	await _frames(5)
	await _save("F5-key-to-the-city.png", Rect2(main.notice.global_position, main.notice.size))


## Points round a circle in the view, for a chalk stroke.
func _ring(center: Vector2, radius: float) -> Array:
	var points := []
	for i in 33:
		points.append(center + Vector2.from_angle(TAU * i / 32.0) * radius)
	return points


## F6: the three pie menus over Detroit, each shown with an item pointed at:
## Tool (Bulldozer), Zone (Res) and Build (Park).
func _pie_menus() -> void:
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	main.set_paused(true)
	var pie: PieMenus = main.pie_menus
	var at: Vector2 = main.map_view.global_position + main.map_view.size / 2.0
	var area := Rect2(at - Vector2(130, 130), Vector2(260, 260))
	pie.open(at)
	pie.show_pie()
	pie.handle(_mouse_move(at + Vector2(30, -30)))
	await _frames(3)
	await _save("F6-tool-pie.png", area)
	await _save("F6-tool-pie-window.png")
	pie.handle(_mouse_move(at + Vector2(0, -40)))
	pie.handle(_mouse_button(at + Vector2(0, -40), false))
	pie.show_pie()
	var zone_at := pie.center
	pie.handle(_mouse_button(zone_at, true))
	pie.handle(_mouse_move(zone_at + Vector2(-35, -20)))
	await _frames(3)
	await _save("F6-zone-pie.png", Rect2(zone_at - Vector2(130, 130), Vector2(260, 260)))
	pie.cancel()
	pie.open(at)
	pie.handle(_mouse_move(at + Vector2(0, 40)))
	pie.handle(_mouse_button(at + Vector2(0, 40), false))
	pie.show_pie()
	var build_at := pie.center
	pie.handle(_mouse_button(build_at, true))
	pie.handle(_mouse_move(build_at + Vector2(0, -40)))
	await _frames(3)
	await _save("F6-build-pie.png", Rect2(build_at - Vector2(130, 130), Vector2(260, 260)))
	pie.cancel()


func _mouse_move(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	return event


func _mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


## 4.1: the About notice, the OLPC's Message 300 marked as a
## modified version, in the head column.
func _about() -> void:
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.set_paused(true)
	main.micropolis_menu.id_pressed.emit(main.MicropolisItem.ABOUT)
	await _frames(5)
	await _save("4.1-about.png", Rect2(main.notice.global_position, main.notice.size))
	await _save("4.1-about-window.png")


## 3.4: the game opens on the city chooser, with no splash,
## and the Options menu has no Tile Set.
func _gpl_art_only() -> void:
	main.open_city_chooser()
	await _frames(5)
	await _save("3.4-start.png")
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.set_paused(true)
	main.notice.dismiss()
	main.options_menu.popup(Rect2i(Vector2i(80, 26), Vector2i.ZERO))
	await _frames(5)
	await _save("3.4-options-menu.png", Rect2(Vector2.ZERO, Vector2(360, 260)))
	main.options_menu.hide()


## 4.4: the same screens with DejaVu antialiased (as the game draws it) and
## without (as the OLPC's X core fonts drew it): the window
## with Detroit's notice, the budget window, and the chooser's description
## panel.
func _font_smoothing() -> void:
	var font := Content.olpc_font()
	for pass_name: String in ["smooth", "plain"]:
		font.antialiasing = (TextServer.FONT_ANTIALIASING_GRAY if pass_name == "smooth"
			else TextServer.FONT_ANTIALIASING_NONE)
		font.hinting = TextServer.HINTING_LIGHT if pass_name == "smooth" else TextServer.HINTING_NORMAL
		main.load_scenario(CityEngine.Scenario.DETROIT)
		main.set_paused(true)
		main.open_map()
		await _frames(5)
		await _save("4.4-%s-window.png" % pass_name)
		main.request_budget()
		await _frames(5)
		await _save("4.4-%s-budget.png" % pass_name, _window_rect(main.budget_window))
		main.budget_window.close(false)
		main.open_city_chooser()
		var screen: NewCityScreen = main.new_city_screen
		screen.point_at(NewCityScreen.BUTTONS[NewCityScreen.button_index("scenario3")].rect.get_center())
		await _frames(5)
		await _save("4.4-%s-chooser.png" % pass_name, Rect2(Vector2(200, 0), Vector2(720, 470)))
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT


## 1.9a: the head's small graph on Detroit four years on; auto-goto gliding
## from the map's corner to a tornado at Slow, a screen at each step, and a
## sheet of them; a scenario won (Bern) and one lost (San Francisco), each run
## straight to a month before its end, then at Normal.
func _before_play() -> void:
	var engine: CityEngine = main.engine
	var view: MapView = main.map_view
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.notice.dismiss()
	engine.set_auto_budget(true)
	for i in 3100:
		engine.tick()
	view.city_map.sync()
	view.sprites.sync()
	main.set_paused(true, true)
	await _frames(5)
	await _save("1.9a-head-graph.png", main.head.get_global_rect())
	await _save("1.9a-mini-graph-window.png")

	engine.set_auto_goto(true)
	view.center_on_tile(Vector2i(0, 0))
	main.set_priority(main.Priority.SLOW)
	main.set_paused(false, true)
	main.trigger_disaster(main.DisasterItem.TORNADO)
	var editor := view.get_global_rect()
	var frames: Array[Image] = [await _save("1.9a-glide-00.png", editor)]
	var last := view.camera_position
	while view.is_gliding() and frames.size() < 40:
		await process_frame
		if view.camera_position != last:
			last = view.camera_position
			frames.append(await _save("1.9a-glide-%02d.png" % frames.size(), editor))
	await _seconds(0.3)
	frames.append(await _save("1.9a-glide-%02d.png" % frames.size(), editor))
	_save_sheet(frames, "1.9a-glide-sheet.png", 4)

	for ending: Array in [[CityEngine.Scenario.BERN, "1.9a-won-bern.png"],
			[CityEngine.Scenario.SAN_FRANCISCO, "1.9a-lost-san-francisco.png"]]:
		await _to_the_end(ending[0])
		await _frames(10)
		await _save(ending[1])
		main.ask_dialog.hide()


## Runs a scenario's engine straight to a month before its end (a Super Fast
## frame can run past it by years), then the game at Normal to the end,
## continuing the budget window as it comes.
func _to_the_end(scenario: int) -> void:
	var engine: CityEngine = main.engine
	var ended := [false]
	var on_message := func(index: int, _x: int, _y: int, _picture: bool, _important: bool) -> void:
		if index == main.SCENARIO_WON or index == main.SCENARIO_LOST:
			ended[0] = true
	engine.message_sent.connect(on_message)
	main.load_scenario(scenario)
	main.notice.dismiss()
	engine.set_auto_goto(false)
	var end_time: int = {CityEngine.Scenario.BERN: 3602, CityEngine.Scenario.SAN_FRANCISCO: 530}[scenario]
	while engine.get_city_time() < end_time - 4:
		engine.tick()
	main.map_view.city_map.sync()
	main.map_view.sprites.sync()
	main.set_priority(main.Priority.NORMAL)
	while not ended[0]:
		await process_frame
		if main.budget_window.visible:
			main.budget_window.close(false)
	engine.message_sent.disconnect(on_message)
	await _frames(2)
	if main.budget_window.visible:
		main.budget_window.close(false)


## Frames side by side, `columns` to a row, each at half size.
func _save_sheet(frames: Array[Image], name: String, columns: int) -> void:
	var size := frames[0].get_size() / 2
	var rows := ceili(frames.size() / float(columns))
	var sheet := Image.create(size.x * columns + 4 * (columns - 1), size.y * rows + 4 * (rows - 1), false,
		frames[0].get_format())
	sheet.fill(Color.BLACK)
	for i in frames.size():
		var small := frames[i].duplicate() as Image
		small.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, size), Vector2i(i % columns, i / columns) * (size + Vector2i(4, 4)))
	var path := ProjectSettings.globalize_path(out).path_join(name)
	print("sheet %s: %s" % [path, error_string(sheet.save_png(path))])
