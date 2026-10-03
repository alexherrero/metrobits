## The game's soak, headless, through the real game window:
##   godot --headless --path game --script res://tools/soak.gd -- --out=<dir> [--years=50]
## .harness/soak.sh runs it with the native soak (extension/native/soak.cpp),
## twice over, and compares them.
##
## 1. Each of the 8 scenarios, chosen as the city chooser chooses it, runs at
##    Super Fast (the OLPC's top Priority) to its end, with the budget window
##    continued each year as it comes. The city is recorded at the moment the
##    engine sends the won or lost message, which is the same tick every run,
##    so the native soak must record it alike. Then what 1989 did after
##    (UILoseGame, UIWinGame): the notice shows; after a loss the game pauses
##    and asks, in red, with one answer, Ok, which opens the city chooser; after
##    a win it plays on.
## 2. A new city on a generated map, from the chooser's Play This Map: a coal
##    plant, a power line, three roads joined at one end, and 66 zones
##    (housing above each road, shops and industry below, with two fire
##    stations and a police station among them), built with the palette's
##    tools through the editor as a player would, with Auto Budget on. It runs
##    at Fast, 7 loops a frame whatever the clock, so every tool lands on a
##    known tick: the tools and a checkpoint each year go to build.txt, which
##    the native soak replays and checks. It must pass 10,000 people.
## 3. Half way through its 50 years, Save City as... saves it: saving must
##    leave it as it was; and the saved file must carry on alike in the game's
##    engine and a new one.
##
## game.txt gets only what repeats run to run; the log gets the timings. Exits
## 1 if a check fails. The game keeps its settings in memory.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
extends SceneTree

const SEED := 1989
## The generated map the city is built on, and where on it.
const MAP_SEED := 9
const SCENARIO_NAMES := ["", "dullsville", "san_francisco", "hamburg", "bern", "tokyo", "detroit", "boston", "rio"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## Frames a scenario may take at Super Fast, and loops a Fast frame runs.
const MAX_FRAMES := 20000
const FAST_LOOPS := 7
## The build: a coal plant at the left, a power line down beside it, and
## ROADS roads across, joined at the right, with ZONES_A_SIDE zones above and
## below each.
const ROADS := 3
const ZONES_A_SIDE := 11
const BUILD_SIZE := Vector2i(5 + 3 * ZONES_A_SIDE + 1, 7 * ROADS + 1)
## Slots given to services, by road and place along it, above and below: an
## unattended city with no fire station burned down within 15 years.
const ABOVE := {Vector2i(0, 2): CityEngine.Tool.FIRE_STATION, Vector2i(2, 8): CityEngine.Tool.FIRE_STATION}
const BELOW := {Vector2i(1, 5): CityEngine.Tool.POLICE_STATION}

var main: Control
var engine: CityEngine
var out := ""
var years := 50
var lines := PackedStringArray()
var build := PackedStringArray()
var failures := 0
## Engine ticks since the built city started.
var ticks := 0
var _ended := ""
## The notice's title as the scenario's end showed it.
var _notice_title := ""
## Whether a loss's Ok left the city chooser open for the next scenario.
var _chooser_after_loss := false


func _initialize() -> void:
	var args: Dictionary = load("res://main.gd").parse_args(OS.get_cmdline_user_args())
	out = ProjectSettings.globalize_path(str(args.get("out", "user://soak")))
	years = int(args.get("years", "50"))
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://main.tscn").instantiate()
	main.settings_path = ""
	root.add_child(main)
	engine = main.engine
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	# The soak runs the game's loop itself, a frame at a time. (Godot turned
	# the game's _process on when it became ready.)
	main.set_process(false)
	# After the game's own handler, which shows the notice; at Super Fast a
	# later notice may replace it within the frame, as it would have in 1989.
	engine.message_sent.connect(func(index: int, _x: int, _y: int, _picture: bool, _important: bool) -> void:
		if (index == main.SCENARIO_WON or index == main.SCENARIO_LOST) and _ended == "":
			_ended = ("won " if index == main.SCENARIO_WON else "lost ") + state(engine)
			_notice_title = main.notice.title_label.text if main.notice.visible else "")
	engine.set_fixed_seed(SEED)
	_say("soak: game, seed %d" % SEED)
	for scenario in range(1, 9):
		var started := Time.get_ticks_msec()
		await _scenario(scenario)
		print("%s: %.1f s" % [SCENARIO_NAMES[scenario], (Time.get_ticks_msec() - started) / 1000.0])
	var started := Time.get_ticks_msec()
	await _built_city()
	print("built: %.1f s" % [(Time.get_ticks_msec() - started) / 1000.0])
	_say("SOAK FAILED (%d)" % failures if failures else "SOAK OK")
	var file := FileAccess.open(out.path_join("game.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file = FileAccess.open(out.path_join("build.txt"), FileAccess.WRITE)
	file.store_string("\n".join(build) + "\n")
	Content.note_used()
	quit(1 if failures else 0)


# The scenarios ---------------------------------------------------------------

func _scenario(scenario: int) -> void:
	var name: String = SCENARIO_NAMES[scenario]
	_ended = ""
	# As the chooser starts one after a loss's Ok opened it: picked, then Play
	# This Map. The first loads directly, as the engine's own soak does: the
	# chooser the game opens on would set Easy's funds (play_this_map).
	if _chooser_after_loss:
		main.new_city_screen.activate(NewCityScreen.scenario_button(scenario))
		main.new_city_screen.activate("play")
	else:
		main.load_scenario(scenario)
	_check(engine.get_scenario() == scenario, name + ": it loads")
	main.set_priority(main.Priority.SUPER_FAST)
	var frames := 0
	while _ended == "" and frames < MAX_FRAMES:
		await _frame(1.0 / 60.0)
		frames += 1
	_check(_ended != "", name + ": it ends")
	_say("%s ends %s" % [name, _ended])
	# A scenario ends at a year's end, when the budget window comes too.
	await _frame(0.0)
	await _frames(1)
	var lost := _ended.begins_with("lost")
	var dialog: ConfirmationDialog = main.ask_dialog
	var title := str(Notices.for_message(main.SCENARIO_LOST if lost else main.SCENARIO_WON).title)
	_check(_notice_title == title, name + ": its notice shows, " + title)
	if lost:
		_check(engine.is_paused(), name + ": a loss pauses the game")
		_check(dialog.visible and dialog.title == title and dialog.ok_button_text == "Ok"
			and not dialog.get_cancel_button().visible, name + ": and asks, with one answer, Ok")
		dialog.get_ok_button().pressed.emit()
		await _frames(2)
		_check(main.new_city_screen.visible, name + ": Ok opens the city chooser")
		_chooser_after_loss = main.new_city_screen.visible
		_say("%s then: the notice \"%s\", paused, the question with Ok, then the city chooser" % [name, title])
	else:
		_chooser_after_loss = false
		_check(not engine.is_paused() and not dialog.visible, name + ": a win plays on, with no question")
		var time := engine.get_city_time()
		for frame in 10:
			await _frame(1.0 / 60.0)
		_check(engine.get_city_time() > time, name + ": the city goes on after a win")
		_say("%s then: the notice \"%s\", and the city plays on" % [name, title])


# The built city ----------------------------------------------------------------

func _built_city() -> void:
	# From the chooser, as a player would: a map, then Play This Map.
	main.open_city_chooser()
	main.new_city_screen.make_history({kind = "map", seed = MAP_SEED})
	main.new_city_screen.name_edit.text = "SoakVille"
	main.new_city_screen.activate("play")
	var at := _build_site()
	_check(at.x >= 0, "built: the map has room for the city")
	if at.x < 0:
		return
	ticks = 0
	build.append_array([
		"# The game's soak's build, replayed by extension/native/soak.cpp: a generated map,",
		"# the new city's settings, the tools and options on the ticks they came, and checkpoints.",
		"map_seed %d" % MAP_SEED, "name %s" % engine.get_city_name(), "level %d" % engine.get_game_level(),
		"funds %d" % engine.get_funds(), "tax %d" % engine.get_tax_rate(), "auto_goto %d" % int(engine.get_auto_goto()),
	])
	_checkpoint()
	_option("auto_budget", main.OptionItem.AUTO_BUDGET)
	_lay_out(at)
	_say("built on map %d at %d,%d: %d zones and %d stations, funds left %d" % [MAP_SEED, at.x, at.y,
		2 * ZONES_A_SIDE * ROADS - ABOVE.size() - BELOW.size(), ABOVE.size() + BELOW.size(), engine.get_funds()])
	_checkpoint()
	main.set_priority(main.Priority.FAST)
	var begin := engine.get_city_time()
	var end := begin + years * 48
	var passed := false
	var saved := false
	var mid_file := out.path_join("game-built-mid.cty")
	var year := engine.get_year()
	var count := 0
	while engine.get_city_time() < end:
		count += 1
		await _frame(0.1, count % 20 == 0)
		if engine.get_year() != year:
			year = engine.get_year()
			_checkpoint()
		if not passed and engine.get_population() > 10000:
			passed = true
			_say("built passes 10000 in %s %d with pop=%d" % [MONTHS[engine.get_month()], engine.get_year(),
				engine.get_population()])
		if not saved and engine.get_city_time() >= begin + years * 24:
			saved = true
			var before := state(engine)
			_check(main.save_city_as(mid_file), "built: Save City as... saves it")
			_check(state(engine) == before, "built: saving leaves the city as it was")
			_checkpoint()
	_checkpoint()
	_check(passed, "built: the city passed 10,000 people")
	_say("built ran %s" % state(engine))
	# The saved city, in the game's engine and in a new one.
	_check(main.load_city(mid_file), "built: the game loads the saved city")
	main.set_priority(main.Priority.FAST)
	while engine.get_city_time() < end:
		count += 1
		await _frame(0.1, count % 20 == 0)
	var fresh: CityEngine = MicropolisCityEngine.new()
	fresh.set_fixed_seed(SEED)
	_check(fresh.load_city(mid_file), "built: a new engine loads the saved city")
	fresh.set_speed(3)
	fresh.resume()
	while fresh.get_city_time() < end:
		for i in FAST_LOOPS:
			fresh.tick()
	_check(state(engine) == state(fresh), "built: the saved city carries on alike in the game and a new engine: %s, %s"
		% [state(engine), state(fresh)])
	_say("built reloaded %s" % state(fresh))
	fresh = null


## The top-left of a BUILD_SIZE stretch of land (dirt or trees) nearest the
## map's middle, or (-1, -1).
func _build_site() -> Vector2i:
	var map := engine.get_map()
	var middle := Vector2i(CityEngine.MAP_WIDTH, CityEngine.MAP_HEIGHT) / 2 - BUILD_SIZE / 2
	for radius in 60:
		for y in range(middle.y - radius, middle.y + radius + 1):
			for x in range(middle.x - radius, middle.x + radius + 1):
				if maxi(absi(x - middle.x), absi(y - middle.y)) == radius and _is_land(map, Rect2i(Vector2i(x, y), BUILD_SIZE)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _is_land(map: PackedInt32Array, area: Rect2i) -> bool:
	if area.position.x < 1 or area.position.y < 1 or area.end.x >= CityEngine.MAP_WIDTH or area.end.y >= CityEngine.MAP_HEIGHT:
		return false
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var tile := map[y * CityEngine.MAP_WIDTH + x] & CityEngine.TILE_INDEX_MASK
			if tile != 0 and (tile < 21 or tile > 43):
				return false
	return true


## The city, from its top-left: the trees cleared, a coal plant, a power line
## down beside it, and ROADS roads joined by one down the right, each with
## housing above it and shops and industry below; each row of zones touches
## the next road's, so the power runs through them from the line.
func _lay_out(at: Vector2i) -> void:
	for y in BUILD_SIZE.y:
		_use(CityEngine.Tool.BULLDOZER, at + Vector2i(0, y), at + Vector2i(BUILD_SIZE.x - 1, y))
	_use(CityEngine.Tool.COAL_POWER, at + Vector2i(1, 1))
	_use(CityEngine.Tool.WIRE, at + Vector2i(4, 0), at + Vector2i(4, BUILD_SIZE.y - 1))
	for road in ROADS:
		var y := 3 + 7 * road
		_use(CityEngine.Tool.ROAD, at + Vector2i(5, y), at + Vector2i(5 + 3 * ZONES_A_SIDE - 1, y))
		for i in ZONES_A_SIDE:
			var x := 6 + 3 * i
			var slot := Vector2i(road, i)
			_use(ABOVE.get(slot, CityEngine.Tool.RESIDENTIAL), at + Vector2i(x, y - 2))
			var shops := CityEngine.Tool.COMMERCIAL if i % 2 == 0 else CityEngine.Tool.INDUSTRIAL
			_use(BELOW.get(slot, shops), at + Vector2i(x, y + 2))
	_use(CityEngine.Tool.ROAD, at + Vector2i(BUILD_SIZE.x - 1, 3), at + Vector2i(BUILD_SIZE.x - 1, 3 + 7 * (ROADS - 1)))


## A tool from the palette, clicked at `from` and dragged to `to`, through the
## editor as a player's pointer would, and written down for the replay.
func _use(tool: int, from: Vector2i, to := Vector2i(-1, -1)) -> void:
	main.select_tool(tool)
	main.map_view.click_tile(from)
	build.append("op %d down %d %d %d" % [ticks, tool, from.x, from.y])
	if to.x >= 0 and to != from:
		main.map_view.drag_tiles(from, to)
		build.append("op %d drag %d %d %d %d %d" % [ticks, tool, from.x, from.y, to.x, to.y])


## An option turned on from the Options menu, and written down.
func _option(name: String, item: int) -> void:
	main.options_menu.id_pressed.emit(item)
	var on: bool = main.options_menu.is_item_checked(main.options_menu.get_item_index(item))
	build.append("op %d %s %d" % [ticks, name, int(on)])


func _checkpoint() -> void:
	build.append("check %d %s" % [ticks, state(engine)])


# Helpers -------------------------------------------------------------------------

## The game's loop for delta seconds, then (unless not wait) a frame for its
## deferred work; the budget window, if the engine asked for it, is continued,
## as a player's Continue With These Figures, which changes nothing.
func _frame(delta: float, wait := true) -> void:
	main.advance(delta)
	ticks += main.last_loops
	if wait:
		await process_frame
	if main.budget_window.visible:
		main.budget_window.close(false)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## A city as the native soak prints it.
static func state(city: CityEngine) -> String:
	return "%s %d time=%d pop=%d funds=%d score=%d map=%08x" % [MONTHS[city.get_month()], city.get_year(),
		city.get_city_time(), city.get_population(), city.get_funds(), city.get_evaluation().score,
		map_hash(city.get_map())]


## FNV-1a, 32 bits, over the tiles by rows, as the native soak hashes them.
static func map_hash(map: PackedInt32Array) -> int:
	var h := 2166136261
	for tile in map:
		h = ((h ^ (tile & 0xffff)) * 16777619) & 0xffffffff
	return h


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		_say("FAIL: " + what)


func _say(line: String) -> void:
	lines.append(line)
	print(line)
