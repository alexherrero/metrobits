## The game window, laid out like the OLPC Micropolis: on the left the
## head window (menus, the demand gauge, date, funds, population, speed); on
## the right the editor, with its message line on top and the tool palette at
## the side of the map.
##
## It opens on the city chooser, as the OLPC did, unless the command line
## names a city. The OLPC's code asked for a splash picture first, but its
## release never had one.
##
## Keys: 0 pauses and resumes, 1 to 3 set the Priority to Slow, Normal and
## Fast; each of the engine's tools has a key (Tools.KEYS), X and Z step
## through the palette, and holding a tool's key while clicking uses it and
## switches back on release. Tab clicks where the pointer is, F10 opens the
## Micropolis menu, and the OLPC's cheat words work as typed (type_letter).
## The right button, or Shift with the left, over the editor opens the OLPC's
## pie menus (PieMenus).
##
## Feedback, as the original gave it: every message in the editor's message
## line and the head's log; for a message with a picture, its notice, one at a
## time at the foot of the head column, with a view of the place it's about;
## the map gliding to a message's place, as 1989's editor did, and skidding to
## a stop (auto-goto, on from the start as in 1989 unless the player turned it
## off: the editor's Options, then Auto Goto, kept in settings.cfg; a click on the notice's
## view glides there too); the Query tool's report as a notice; the budget
## window, when the engine asks at the year's end and from the Budget button;
## and a scenario's end, as 1989's: its notice, and after a loss, a pause and
## the question that leads to the city chooser.
##
## Sound: the original's effects, for the engine's sounds and messages, the
## tools, the palette and pausing (Sounds); Options, then Sound, turns them
## off, kept in settings.cfg.
##
## The tile art is the OLPC version's unless the player chose the Windows
## edition's (Options, then Tile Set, kept in settings.cfg). The
## engine's sprites (trains, planes, helicopters, ships, buses, the monster,
## the tornado and explosions) move over the map.
##
## The rest of the original, from its menus: Micropolis (About..., Save City,
## Save City as..., Choose City! for the city chooser with the scenarios, a
## generated map and Load City, and Quit Playing!), Disasters with Air Crash,
## and Windows (Budget, Evaluation, Graph, Map). The map window, with 1989's
## zone maps and overlays, opens with the game in the head column, where the
## OLPC packed its map; the graph window opens at the top of the editor, where
## the OLPC packed its graph.
##
## It owns the engine, through CityEngine only, and runs its loop at
## the OLPC's Priority: each loop is one engine tick, which simulates
## (the engine's speed stays at 3, as the OLPC's did) and moves the sprites,
## and each loop steps the tile animation, as 1989's sim_loop did, so the
## sim, the sprites and the animation all keep the Priority's pace.
##
## Command line, after `--`:
##   --scenario=<1-8 or name>   load a scenario instead of opening the chooser
##   --city=<path>              load a .cty file, e.g. cities/haight.cty
##   --seed=<n>                 fix the random seed before the load
##   --priority=<0-4 or name>   start at this Priority (0 super slow, 2
##                              normal, 4 super fast); --paused starts paused
##   --center=<x>,<y>           centre the map on this tile
##   --zoom=<z>                 start at this zoom
##   --tool=<name>              select a tool, e.g. road, coal_power
##   --hover=<x>,<y>            show the tool cursor over this tile
##   --screenshot=<file.png>    after --after seconds (default 5), save the
##                              window to the file and quit
##   --benchmark                pan across the whole map, print the frame
##                              rate, and quit (--sprites: with a tornado and
##                              a monster set off first; --graph: with the
##                              graph window open as well as the map's)
##   --settings=<file>          keep settings in this file instead of
##                              user://settings.cfg (see settings.gd)
##   --new-city                 open the city chooser once the city loads
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
extends Control

## The OLPC's Priority menu, slowest first (SetPriority's index).
enum Priority { SUPER_SLOW, SLOW, NORMAL, FAST, SUPER_FAST }
const PRIORITY_NAMES := ["Super Slow", "Slow", "Normal", "Fast", "Super Fast"]
## Loops a second at each Priority, from SetPriority's delays between loops:
## 500,000, 100,000, 25,000 and 5,000 microseconds. Super Fast's was 5, as
## many as the machine could run, so it runs as many as fit in
## SUPER_FAST_SHARE of each of the display's frames (the shortest interval
## between frames lately: a screen's reported rate can be wrong).
const LOOPS_PER_SECOND := [2.0, 10.0, 40.0, 200.0, INF]
const SUPER_FAST_SHARE := 0.5
## A stall catches up at most this long a stretch of loops, so it doesn't
## snowball.
const MAX_CATCH_UP := 1.0 / 30.0
## The OLPC started every game at Normal (its global Priority, 2).
const DEFAULT_PRIORITY := Priority.NORMAL
## The Priority menu's Pause item, and the keys for its items.
const PAUSE_ITEM := 100
const PRIORITY_KEYS := {PAUSE_ITEM: "0", Priority.SLOW: "1", Priority.NORMAL: "2", Priority.FAST: "3"}
const FIRST_TOOL := CityEngine.Tool.BULLDOZER
## The OLPC's HeadPanelWidth (360), which its map filled, and the map
## window's frame either side.
const HEAD_WIDTH := 360 + 2 * 4

## Where the game starts when the command line names no city: NONE opens the
## city chooser. The GUT pre-run hook sets a scenario, so the
## tests start on a city.
static var start_scenario := CityEngine.Scenario.NONE

enum OptionItem { AUTO_BUDGET, AUTO_BULLDOZE, DISASTERS, AUTO_GOTO, SOUND, ANIMATION, MESSAGES, NOTICES,
	PALLET_PANEL, CHALK_OVERLAY }
enum MicropolisItem { ABOUT, SAVE, SAVE_AS, CHOOSE_CITY, QUIT }
enum DisasterItem { MONSTER, FIRE, FLOOD, MELTDOWN, TORNADO, EARTHQUAKE, AIR_CRASH, ENABLED = 100 }
## What each disaster's question asks (UIDisaster's "Oh no! Do you really
## want to ..."), from whead.tcl's Disasters menu.
const DISASTER_ACTIONS := {
	DisasterItem.MONSTER: "release a monster?", DisasterItem.FIRE: "start a fire?",
	DisasterItem.FLOOD: "bring on a flood?", DisasterItem.MELTDOWN: "have a nuclear meltdown?",
	DisasterItem.AIR_CRASH: "crash an airplane?", DisasterItem.TORNADO: "spin up a tornado?",
	DisasterItem.EARTHQUAKE: "cause an earthquake?",
}
enum WindowItem { BUDGET, EVALUATION, GRAPH, MAP }
## A new city's funds by game level, as 1989's SetGameLevelFunds set them.
const LEVEL_FUNDS := [20000, 10000, 5000]
## The notice views follow these sprites for these messages, as 1989's did
## (FollowView): the monster, the tornado, and the traffic helicopter.
const FOLLOW := {21: CityEngine.SpriteType.MONSTER, 22: CityEngine.SpriteType.TORNADO,
	41: CityEngine.SpriteType.HELICOPTER}
## Where Save City as... starts. Nothing is ever saved into the content folder.
const CITIES_DIR := "user://cities"
## The engine's messages for a scenario won and lost (doScenarioScore), 1989's
## pictures 100 and 200.
const SCENARIO_WON := 47
const SCENARIO_LOST := 48
## The title colour of 1989's questions: after a loss, Choose City! and Quit
## ([Color . #ff0000 #ffffff]).
const QUESTION_COLOR := Color("#ff0000")
const LOST_COLOR := QUESTION_COLOR

## How many times About Metrobits has been shown (the tests read it).
var app_about_count := 0
var engine: CityEngine
var head: HeadPanel
var map_view: MapView
var message_label: Label
var palette: Palette
var micropolis_menu: PopupMenu
var priority_menu: PopupMenu
var options_menu: PopupMenu
## The editor's own Options menu (weditor.tcl): Auto Goto and Pallet Panel.
var editor_options_menu: PopupMenu
var disasters_menu: PopupMenu
var windows_menu: PopupMenu
var message_log: MessageLog
## The notice showing, one at a time: an alert or the Query tool's report.
var notice: NoticeBox
## The room the map window takes at the top of the head column's foot.
var map_room: Control
var budget_window: BudgetWindow
var budget_button: Button
var evaluation_window: EvaluationWindow
var graph_window: GraphWindow
var map_window: MapWindow
var new_city_screen: NewCityScreen
var sounds: Sounds
## The editor's pie menus, over everything while one is open.
var pie_menus: PieMenus
## Save City as... and Load City's file chooser.
var file_dialog: FileDialog
## 1989's questions: choose another city, quit.
var ask_dialog: ConfirmationDialog
## The .cty file the city came from or was last saved to, as an absolute path,
## or "" for a scenario or a generated map.
var city_file := ""
## The player's saved preferences, from settings_path (set it before _ready).
var settings: Settings
var settings_path := Settings.default_path

## The loop's pace.
var priority := DEFAULT_PRIORITY
## How long the last advance() took, sim ticks and map redraw, in microseconds.
var last_advance_usec := 0
## How many loops the last advance() ran.
var last_loops := 0

var _clock := 0.0
var _frame_interval := 1.0 / 60.0
var _args := {}
## The tool key being held, the tool from before it, and whether it's been used.
var _held_key := KEY_NONE
var _tool_before_hold := -1
var _used_while_held := false
var _paused_before_budget := false
## The last four letters typed, for the OLPC's cheat words (w_keys.c's LastKeys).
var _last_keys := ""


func _init() -> void:
	engine = MicropolisCityEngine.new()
	sounds = Sounds.new()
	add_child(sounds)


func _ready() -> void:
	_args = parse_args(OS.get_cmdline_user_args())
	settings = Settings.new(str(_args.get("settings", settings_path)))
	if DisplayServer.get_name() != "headless":
		_size_window()
	theme = ClassicTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	var tiles := CityMap.load_tiles()
	map_view.setup(engine, tiles)
	head.setup(engine)
	palette.setup(engine, tiles)
	notice.view.setup(map_view.city_map, map_view.sprites)
	graph_window.setup(engine)
	map_window.setup(engine, tiles, map_view)
	# 1989's ComeToMe glided the editor there, even with auto-goto off.
	notice.view.clicked.connect(map_view.glide_to_tile)
	notice.picture_clicked.connect(func() -> void: sounds.play("Computer"))
	# The pie menus pick tools (EditorSetTool), say their labels and pay the
	# mouse-ahead reward; a plain click past an open pie goes to the editor.
	pie_menus.tool_chosen.connect(select_tool)
	pie_menus.sound_wanted.connect(func(sound: String, volume: int) -> void: sounds.play(sound, 100, volume))
	pie_menus.rewarded.connect(func(dollars: int) -> void: engine.set_funds(engine.get_funds() + dollars))
	pie_menus.passed_on.connect(func(event: InputEventMouseButton) -> void:
		var local := event.duplicate() as InputEventMouseButton
		local.position = map_view.get_global_transform().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, map_view.size).has_point(local.position):
			map_view._gui_input(local))
	new_city_screen.setup(engine, tiles)
	new_city_screen.scenario_wanted.connect(preview_scenario)
	new_city_screen.map_wanted.connect(preview_map)
	new_city_screen.city_wanted.connect(preview_city)
	new_city_screen.level_wanted.connect(set_game_level)
	new_city_screen.play_requested.connect(play_this_map)
	new_city_screen.load_requested.connect(ask_to_load_city)
	new_city_screen.quit_requested.connect(ask_to_quit)
	# The chooser's level and name follow the engine's (UISetGameLevel,
	# UISetCityName), as its checkboxes and City Name entry did.
	engine.game_level_changed.connect(new_city_screen.show_level)
	engine.city_name_changed.connect(func(city_name: String) -> void: new_city_screen.name_edit.text = city_name)
	file_dialog.file_selected.connect(_on_file_chosen)
	# UIDidntSaveCity: the reason in red in the log, and Sorry.
	engine.city_save_failed.connect(func(path: String) -> void:
		message_log.add("Unable to save the city to the file named \"%s\"." % path, "alert")
		sounds.play("Sorry", 85))
	engine.evaluation_changed.connect(_on_evaluation)
	# DoEarthQuake: the editor and the map shake for 3 seconds.
	engine.earthquake_started.connect(func(_strength: int) -> void:
		map_view.shake.start()
		map_window.small_map.shake.start())
	# The window's close box asks the quit question, as the OLPC's delete
	# protocol did (DeleteHeadWindow, DeleteScenarioWindow).
	get_tree().auto_accept_quit = false
	palette.tool_selected.connect(select_tool)
	palette.tool_selected.connect(sounds.on_palette_pick)
	sounds.enabled = settings.sound
	engine.sound_requested.connect(sounds.on_engine_sound)
	engine.tool_applied.connect(sounds.on_tool_applied)
	map_view.tool_started.connect(func(tool: int) -> void:
		if tool == CityEngine.Tool.BULLDOZER:
			sounds.play("Rumble"))
	map_view.tool_used.connect(func(_tool: int) -> void: _used_while_held = _held_key != KEY_NONE)
	select_tool(FIRST_TOOL)
	engine.message_sent.connect(_on_message)
	engine.auto_goto_requested.connect(func(x: int, y: int, _text: String) -> void:
		map_view.glide_to_tile(Vector2i(x, y)))
	# UIDidStopPan's Skid, at volume 25.
	map_view.glide_stopped.connect(func() -> void: sounds.play("Skid", 100, 25))
	engine.zone_status_shown.connect(_on_zone_status)
	engine.game_lost.connect(_on_game_lost)
	engine.budget_requested.connect(func() -> void: _open_budget.call_deferred())
	engine.options_changed.connect(_show_options)
	budget_window.finished.connect(_on_budget_finished)
	budget_window.was_reset.connect(func() -> void: set_message("The budget was reset."))
	budget_window.cancelled.connect(_resume_after_budget)
	engine.paused_changed.connect(func(_paused: bool) -> void: _show_priority())
	engine.city_name_changed.connect(func(_name: String) -> void: _show_title())
	if not _args.has("no-city"):
		_load_from_args()
		_start_extras.call_deferred()


## "--name=value" and "--flag" into {name: value or true}.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


## A scenario by number or name ("detroit", "san_francisco", "rio").
static func scenario_from_arg(value: String) -> int:
	if value.is_valid_int():
		return value.to_int()
	var key := value.to_upper().replace("-", "_").replace(" ", "_")
	return CityEngine.Scenario.get(key, CityEngine.Scenario.NONE)


## Plays a scenario, with its notice, as 1989's UIStartScenario did.
func load_scenario(scenario: CityEngine.Scenario) -> bool:
	if not engine.load_scenario(scenario):
		return false
	city_file = ""
	_started()
	var found := Notices.for_scenario(scenario)
	if not found.is_empty():
		show_notice(found.title, found.color, found.text)
	return true


## A new city on terrain generated from seed, at a game level (0 easy to 2
## hard) with that level's funds.
func new_city(seed: int, level := 0, city_name := "") -> void:
	engine.generate_map(seed)
	_play_new_map(city_name, level)


## Loads a .cty file: absolute, res:// or user://, or in the content folder
## (e.g. "cities/haight.cty").
func load_city(path: String) -> bool:
	if not engine.load_city(path):
		_didnt_load(path)
		return false
	city_file = _absolute(path)
	_started()
	return true


## Saves to the city's file, as 1989's Save City did; asks for a file first
## if the city has none of its own, or came from the content folder.
func save_city() -> void:
	if city_file == "" or city_file.begins_with(Content.path("")):
		ask_to_save_city()
	else:
		save_city_as(city_file)


## Saves to path, which becomes the city's file, and names the city after it,
## as the engine names a loaded city.
func save_city_as(path: String) -> bool:
	if not path.ends_with(".cty"):
		path += ".cty"
	if not engine.save_city(path):
		return false
	city_file = _absolute(path)
	engine.set_city_name(city_file.get_file().get_basename())
	# UIDidSaveCity: in the log only.
	message_log.add("Saved the city in \"%s\"." % city_file)
	return true


## Save City as...: the file chooser, starting in user://cities.
func ask_to_save_city() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CITIES_DIR))
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Choose a File to Save the City"
	file_dialog.current_dir = ProjectSettings.globalize_path(CITIES_DIR)
	file_dialog.current_file = engine.get_city_name() + ".cty"
	file_dialog.popup_centered_ratio(0.6)


## Load City: the file chooser, starting in the content's cities.
func ask_to_load_city() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Choose a City to Load"
	file_dialog.current_dir = Content.path("cities")
	file_dialog.popup_centered_ratio(0.6)


## Choose City!: asks, as 1989 did (UISelectCity, titled in red), then opens
## the city chooser.
func ask_to_choose_city() -> void:
	_ask("Choose Another City", "Do you want to abandon this city and choose another one?",
		"Another city!", "Keep playing.", open_city_chooser, QUESTION_COLOR)


## Quit Playing!, and the chooser's Quit: asks first, as 1989 did (UIQuit,
## titled in red).
func ask_to_quit() -> void:
	_ask("Quit Playing Micropolis", "Do you want to quit playing Micropolis?", "I quit!", "Keep playing.",
		func() -> void: get_tree().quit(), QUESTION_COLOR)


## The city chooser, over the whole window, with a new map generated at once
## at Easy, as 1989's UIPickScenarioMode and UIGenerateCityNow did. The game
## waits behind it.
func open_city_chooser() -> void:
	engine.pause()
	_hide_windows()
	notice.dismiss()
	new_city_screen.open()


## The chooser's map from a seed (DoNewCity): named NowHere, at the level
## checked, with the level's funds.
func preview_map(seed: int) -> void:
	engine.generate_map(seed)
	engine.set_city_name("NowHere")
	set_game_level(maxi(new_city_screen.game_level, 0))
	_previewed("map")
	new_city_screen.show_notice("map")


## A scenario in the chooser (DoScenario): loaded, at Easy, as the engine's
## LoadScenario leaves it.
func preview_scenario(scenario: CityEngine.Scenario) -> void:
	engine.load_scenario(scenario)
	_previewed("scenario")
	new_city_screen.show_notice("")


## A city in the chooser, from Load City or About (DoLoadCity): it keeps its
## own level, so none is checked (UIDidLoadCity); or, if it won't load, 1989's
## message and Sorry (UIDidntLoadCity).
func preview_city(path: String) -> void:
	if engine.load_city(path):
		city_file = _absolute(path)
	else:
		_didnt_load(path)
	_previewed("city")
	new_city_screen.show_level(-1)
	new_city_screen.show_notice("city", path)


## A game level and its funds, as the OLPC's `sim GameLevel` set them
## (SetGameLevelFunds): $20,000, $10,000 or $5,000.
func set_game_level(level: int) -> void:
	level = clampi(level, 0, 2)
	engine.set_funds(LEVEL_FUNDS[level])
	engine.set_game_level(level)


## Play This Map (UIUseThisMap): whatever the chooser shows is played, under
## the name in its entry. Unless it's a loaded city, the level checked sets
## the funds again, as `sim GameLevel` did, so a scenario starts with the
## level's funds (Dullsville's $5,000 becomes Easy's $20,000). A scenario
## shows its notice.
func play_this_map(city_name: String, level: int) -> void:
	if level != -1:
		set_game_level(level)
	if city_name != "":
		engine.set_city_name(city_name)
	var shown := new_city_screen.showing()
	if shown.get("kind") == "map":
		engine.set_tax_rate(7)
	_started()
	if shown.get("kind") == "scenario":
		var found := Notices.for_scenario(shown.scenario)
		if not found.is_empty():
			show_notice(found.title, found.color, found.text)


## The About notice: the OLPC's Message 300, marked as a modified version
##. The chooser's About shows the About city instead (DoAbout).
func show_about() -> void:
	show_notice(Notices.ABOUT_TITLE, Notices.ABOUT_COLOR, Notices.about_text())


func open_evaluation() -> void:
	evaluation_window.open(engine)


## A click on the gauge: the evaluation, or away with it if it's showing, as
## ToggleEvaluationOf did, and only while a city is playing.
func toggle_evaluation() -> void:
	if new_city_screen.visible:
		return
	if evaluation_window.visible:
		evaluation_window.hide()
	else:
		open_evaluation()


## The graph window, at the top of the editor as the OLPC packed it.
func open_graph() -> void:
	var editor: Control = map_view.get_parent().get_parent()
	graph_window.position = Vector2i(editor.global_position + Vector2(0, _title_height()))
	graph_window.show()
	graph_window.graph.queue_redraw()


## A click on the head's small graph: the graph window, or away with it if
## it's showing, as the OLPC's ToggleGraphOf did.
func toggle_graph() -> void:
	if graph_window.visible:
		graph_window.hide()
	else:
		open_graph()


## The map window, under the head's log, where the OLPC packed its map.
func open_map() -> void:
	map_window.position = Vector2i(Vector2(_frame_width(), message_log.global_position.y + message_log.size.y
		+ _title_height()))
	map_window.show()
	_keep_map_room()
	map_window.refresh()


## Keeps the map window's room under the head's log while it shows, so the
## notice fills the space below it, as the OLPC's did.
func _keep_map_room() -> void:
	var frame := map_window.get_theme_stylebox("embedded_border", "Window") as StyleBoxFlat
	var bottom := frame.expand_margin_bottom if frame != null else 0.0
	map_room.custom_minimum_size.y = (_title_height() + map_window.size.y + bottom) if map_window.visible else 0.0


## Runs the loop for delta seconds of real time: the loops that are due at
## the Priority, each an engine tick, then the map redraw with the tiles
## animated a frame per loop.
func advance(delta: float) -> void:
	var started := Time.get_ticks_usec()
	last_loops = _advance(delta)
	last_advance_usec = Time.get_ticks_usec() - started


func _advance(delta: float) -> int:
	# Follows the shortest frame, and lets a slower display lengthen it slowly.
	_frame_interval = clampf(minf(delta, _frame_interval * 1.01), 1.0 / 240.0, 1.0 / 30.0)
	if not _running():
		_clock = 0.0
		# Paused, 1989 drew the editor again after each step of a glide
		# (DoAdjustPan), so it went on a step a frame.
		map_view.glide(1)
		return 0
	var loops := 0
	var rate: float = LOOPS_PER_SECOND[priority]
	if is_inf(rate):
		var deadline := Time.get_ticks_usec() + super_fast_budget_usec()
		while _running() and (loops == 0 or Time.get_ticks_usec() < deadline):
			engine.tick()
			loops += 1
	else:
		_clock += delta
		var due := mini(floori(_clock * rate), maxi(1, ceili(rate * MAX_CATCH_UP)))
		_clock = minf(_clock - due / rate, 1.0 / rate)
		# A loop can pause the game (a scenario lost), which ends the run.
		while loops < due and _running():
			engine.tick()
			loops += 1
	if loops > 0:
		map_view.city_map.sync()
		map_view.sprites.sync()
		# 1989 checked the blink each time a loop drew the editor.
		map_view.city_map.set_blinking(CityMap.blink_phase(Time.get_ticks_msec()))
		# Past a few frames a loop, the steps between frames aren't seen; with
		# Animation off the tiles stand still (w_editor.c's DoAnimation).
		if engine.get_animation():
			map_view.city_map.animate(mini(loops, CityMap.MAX_ANIMATION_STEPS))
		# 1989 took a step of a glide each time a loop drew the editor.
		map_view.glide(mini(loops, CityMap.MAX_ANIMATION_STEPS))
	return loops


## How long Super Fast runs loops each frame: half the display's frame.
func super_fast_budget_usec() -> int:
	return roundi(SUPER_FAST_SHARE * _frame_interval * 1000000.0)


## The loops a second at the Priority (INF at Super Fast).
func loops_per_second() -> float:
	return LOOPS_PER_SECOND[priority]


## Sets the loop's pace, as the Priority menu does. Pause is apart from it.
func set_priority(value: Priority) -> void:
	priority = clampi(value, Priority.SUPER_SLOW, Priority.SUPER_FAST) as Priority
	_clock = 0.0
	_show_priority()


func select_tool(tool: int) -> void:
	map_view.tool = tool
	palette.select(tool)


## Opens the budget window, as its button and the Windows menu do: the engine
## is asked, and answers with budget_requested.
func request_budget() -> void:
	engine.request_budget()


func trigger_disaster(item: DisasterItem) -> void:
	match item:
		DisasterItem.MONSTER: engine.make_monster()
		DisasterItem.FIRE: engine.make_fire()
		DisasterItem.FLOOD: engine.make_flood()
		DisasterItem.MELTDOWN: engine.make_meltdown()
		DisasterItem.TORNADO: engine.make_tornado()
		DisasterItem.EARTHQUAKE: engine.make_earthquake()
		DisasterItem.AIR_CRASH: engine.make_air_crash()
	map_view.city_map.sync()
	map_view.sprites.sync()


func set_option(item: OptionItem, enabled: bool) -> void:
	match item:
		OptionItem.AUTO_BUDGET: engine.set_auto_budget(enabled)
		OptionItem.AUTO_BULLDOZE: engine.set_auto_bulldoze(enabled)
		OptionItem.DISASTERS: engine.set_disasters_enabled(enabled)
		OptionItem.AUTO_GOTO:
			engine.set_auto_goto(enabled)
			settings.auto_goto = enabled
			if not enabled:
				map_view.stop_glide()
		OptionItem.SOUND:
			sounds.enabled = enabled
			settings.sound = enabled
			if not enabled:
				sounds.stop_all()
		OptionItem.ANIMATION: engine.set_animation(enabled)
		OptionItem.MESSAGES: engine.set_messages(enabled)
		OptionItem.NOTICES: engine.set_notices(enabled)
		OptionItem.PALLET_PANEL: palette.visible = enabled
		OptionItem.CHALK_OVERLAY: map_view.chalk.shown = enabled
	_show_options()


## The next (step 1) or previous (step -1) tool in the palette, as X and Z do.
func step_tool(step: int) -> void:
	var order := Tools.ordered()
	select_tool(order[posmod(order.find(map_view.tool) + step, order.size())])


## The Priority menu's Pause, the 0 key, and a click on the gauge: as the
## OLPC's TogglePause, with 1989's message ("Time pauses.").
func toggle_pause() -> void:
	set_paused(not engine.is_paused())


## Pauses or resumes, with 1989's message and, unless quiet, its Boing.
func set_paused(paused: bool, quiet := false) -> void:
	if paused:
		engine.pause()
	else:
		engine.resume()
	set_message("Time pauses." if paused else "Time flows fast.")
	if not quiet:
		sounds.running(not paused)


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.echo or key.is_command_or_control_pressed() or key.alt_pressed:
		return
	if not key.pressed:
		_release_tool_key(key.keycode)
		return
	if key.keycode == KEY_F10:
		open_first_menu()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_TAB:
		var pointer := map_view.get_local_mouse_position()
		if Rect2(Vector2.ZERO, map_view.size).has_point(pointer):
			map_view.click_at(pointer)
		get_viewport().set_input_as_handled()
		return
	if key.unicode > 0:
		type_letter(char(key.unicode))
	var tool := Tools.tool_for_key(key.keycode)
	if tool >= 0:
		_hold_tool_key(key.keycode, tool)
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_0:
			toggle_pause()
		KEY_1:
			set_priority(Priority.SLOW)
		KEY_2:
			set_priority(Priority.NORMAL)
		KEY_3:
			set_priority(Priority.FAST)
		Tools.NEXT_KEY:
			step_tool(1)
		Tools.PREVIOUS_KEY:
			step_tool(-1)
		_:
			return
	get_viewport().set_input_as_handled()


## A tool's key went down: select the tool, remembering the one before.
func _hold_tool_key(keycode: Key, tool: int) -> void:
	if _held_key == KEY_NONE:
		_held_key = keycode
		_tool_before_hold = map_view.tool
		_used_while_held = false
	select_tool(tool)


## The held key came up: if the tool was used meanwhile, go back to the one
## before, as the 1989 editor's spring-loaded keys did; a tap keeps the tool.
func _release_tool_key(keycode: Key) -> void:
	if keycode != _held_key:
		return
	if _used_while_held and _tool_before_hold >= 0:
		select_tool(_tool_before_hold)
	_held_key = KEY_NONE


## A message: its text in the message line and the log, and for a picture
## message, its notice. The engine drops a picture message that repeats the
## last one, as 1989's SendMes did (local edit 7).
func _on_message(index: int, x: int, y: int, picture: bool, _important: bool) -> void:
	set_message(Messages.text(index))
	if picture:
		var found := Notices.for_message(index)
		if not found.is_empty():
			# The content's notice pictures (images/icon_*.png) are only
			# placeholders ("Pollution Icon Placeholder"), so none is shown
			#.
			show_notice(found.title, found.color, found.text, Vector2i(x, y),
				FOLLOW.get(index, CityEngine.SpriteType.NONE))
			# The win notice's picture, the key to the city (Message 100's
			# key2city.xpm); a click on it plays Computer (wnotice.tcl).
			if index == SCENARIO_WON and notice.visible:
				notice.show_picture(Content.olpc_texture("key2city"))


## A scenario lost, after the engine's notice: as 1989's UILoseGame, the
## game pauses ("Time pauses.", with no Boing) and asks, titled in red with
## the notice's title and text, with one answer, Ok, which opens the city
## chooser (UIPickScenarioMode). A scenario won only shows its notice, and
## the city plays on, as 1989's doScenarioScore left it.
func _on_game_lost() -> void:
	set_paused(true, true)
	var lost := Notices.for_message(SCENARIO_LOST)
	_ask(lost.get("title", "IMPEACHMENT NOTICE!"), lost.get("text", ""), "Ok", "", open_city_chooser, LOST_COLOR)


func _on_zone_status(category: int, density: int, value: int, crime: int, pollution: int, growth: int,
		x: int, y: int) -> void:
	show_notice(Notices.QUERY_TITLE, Notices.QUERY_COLOR,
		Notices.zone_status(category, density, value, crime, pollution, growth), Vector2i(x, y))


func _open_budget() -> void:
	if not budget_window.visible:
		_paused_before_budget = engine.is_paused()
		engine.pause()
		sounds.running(false)
	budget_window.open(engine)
	set_message("Pausing to set the budget ...")


func _on_budget_finished(changed: bool) -> void:
	set_message("The budget was changed." if changed else "The budget wasn't changed.")
	_resume_after_budget()


func _resume_after_budget() -> void:
	if not _paused_before_budget:
		engine.resume()
		sounds.running(true)


func _show_options() -> void:
	var states := {
		OptionItem.AUTO_BUDGET: engine.get_auto_budget(), OptionItem.AUTO_BULLDOZE: engine.get_auto_bulldoze(),
		OptionItem.DISASTERS: engine.get_disasters_enabled(), OptionItem.SOUND: sounds.enabled,
		OptionItem.ANIMATION: engine.get_animation(), OptionItem.MESSAGES: engine.get_messages(),
		OptionItem.NOTICES: engine.get_notices(),
	}
	for item: int in states:
		options_menu.set_item_checked(options_menu.get_item_index(item), states[item])
	editor_options_menu.set_item_checked(editor_options_menu.get_item_index(OptionItem.AUTO_GOTO),
		engine.get_auto_goto())
	editor_options_menu.set_item_checked(editor_options_menu.get_item_index(OptionItem.PALLET_PANEL), palette.visible)
	editor_options_menu.set_item_checked(editor_options_menu.get_item_index(OptionItem.CHALK_OVERLAY),
		map_view.chalk.shown)
	disasters_menu.set_item_checked(disasters_menu.get_item_index(DisasterItem.ENABLED),
		engine.get_disasters_enabled())


func _running() -> bool:
	return engine.get_speed() > 0 and not engine.is_paused()


## A city just loaded: it runs at once, at speed 3 (upstream's step A1), as
## the OLPC's UIPlayGame started it, and the chooser gives way.
func _started() -> void:
	new_city_screen.visible = false
	engine.set_speed(3)
	set_paused(false, true)
	engine.set_auto_goto(settings.auto_goto)
	notice.dismiss()
	map_view.stop_glide()
	# UINewGame's sim EraseOverlay: a new city starts with no chalk.
	map_view.chalk.clear()
	_clock = 0.0
	map_view.city_map.reset()
	map_view.sprites.sync()
	head.refresh()
	# A new game starts its graphs afresh, as 1989's UINewGame did, and shows
	# the map, once the head column is laid out.
	graph_window.reset()
	if not get_tree().process_frame.is_connected(open_map):
		get_tree().process_frame.connect(open_map, CONNECT_ONE_SHOT)
	_show_title()
	_show_priority()
	_show_options()


## A generated map becomes a new city: its name ("NowHere" unless given, as
## 1989's was), the game level and the level's funds, and a 7% tax, as the
## engine starts its scenarios.
func _play_new_map(city_name: String, level: int) -> void:
	level = clampi(level, 0, 2)
	engine.set_city_name(city_name if city_name != "" else "NowHere")
	engine.set_game_level(level)
	engine.set_funds(LEVEL_FUNDS[level])
	engine.set_tax_rate(7)
	city_file = ""
	_started()


## After a preview loads: the game waits, the chooser's map shows it, and
## only a loaded city has a file.
func _previewed(kind: String) -> void:
	if kind != "city":
		city_file = ""
	engine.pause()
	map_view.city_map.reset()
	map_view.sprites.sync()
	new_city_screen.show_map()


func _on_file_chosen(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		save_city_as(path)
	elif new_city_screen.visible:
		new_city_screen.load_city(path)
	else:
		load_city(path)


## A question, as 1989's AskQuestion: yes runs on_yes; with no answer `no`,
## yes is the only one; a title colour tints the title bar, as 1989 coloured
## its question's title.
func _ask(title: String, text: String, yes: String, no: String, on_yes: Callable,
		title_color := Color.TRANSPARENT) -> void:
	for connection in ask_dialog.confirmed.get_connections():
		ask_dialog.confirmed.disconnect(connection.callable)
	ask_dialog.title = title
	ask_dialog.dialog_text = text
	ask_dialog.ok_button_text = yes
	ask_dialog.cancel_button_text = no
	ask_dialog.get_cancel_button().visible = no != ""
	for style in ["embedded_border", "embedded_unfocused_border"]:
		if title_color.a > 0.0:
			var frame := (theme.get_stylebox(style, "Window") as StyleBoxFlat).duplicate() as StyleBoxFlat
			frame.bg_color = title_color
			ask_dialog.add_theme_stylebox_override(style, frame)
		else:
			ask_dialog.remove_theme_stylebox_override(style)
	ask_dialog.confirmed.connect(on_yes, CONNECT_ONE_SHOT)
	ask_dialog.popup_centered()


## A path as the engine resolves it: res:// and user:// globalized, and a
## relative one in the content folder.
func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path if path.is_absolute_path() else Content.path(path)


func _load_from_args() -> void:
	if _args.has("seed"):
		engine.set_fixed_seed(str(_args.seed).to_int())
	if _args.has("priority"):
		set_priority(_priority_from_arg(str(_args.priority)))
	var loaded := false
	if _args.has("city"):
		loaded = load_city(_args.city)
	elif _args.has("scenario"):
		loaded = load_scenario(scenario_from_arg(_args.scenario))
	elif start_scenario != CityEngine.Scenario.NONE:
		loaded = load_scenario(start_scenario)
	else:
		open_city_chooser()
		return
	if not loaded:
		push_error("couldn't load the city from %s" % [_args])
		return
	if _args.has("paused"):
		set_paused(true)
	if _args.has("zoom"):
		var zoom := str(_args.zoom).to_float()
		map_view.zoom_at(zoom / map_view.get_zoom(), map_view.size / 2.0)
	if _args.has("center"):
		var xy := str(_args.center).split(",")
		map_view.center_on_tile(Vector2i(xy[0].to_int(), xy[1].to_int()))
	if _args.has("tool"):
		select_tool(CityEngine.Tool.get(str(_args.tool).to_upper(), FIRST_TOOL))
	if _args.has("hover"):
		var xy := str(_args.hover).split(",")
		map_view.cursor.tile = Vector2i(xy[0].to_int(), xy[1].to_int())
		map_view.cursor.visible = true


func _start_extras() -> void:
	if _args.has("new-city"):
		open_city_chooser()
	if _args.has("benchmark"):
		var benchmark := PanBenchmark.new()
		add_child(benchmark)
		benchmark.run(self, _args.has("sprites"), _args.has("graph"))
	elif _args.has("screenshot"):
		var after := str(_args.get("after", "5")).to_float()
		await get_tree().create_timer(after).timeout
		await RenderingServer.frame_post_draw
		var path := str(_args.screenshot)
		var error := get_viewport().get_texture().get_image().save_png(path)
		print("screenshot %s: %s" % [path, error_string(error)])
		get_tree().quit()


## Lays the window out in points, not pixels, so it's the same size on a
## Retina screen, and fits it to the screen.
func _size_window() -> void:
	var window := get_window()
	var screen := window.current_screen
	var scale := DisplayServer.screen_get_scale(screen)
	window.content_scale_factor = scale
	var wanted := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")) * scale
	var usable := Vector2(DisplayServer.screen_get_usable_rect(screen).size) * 0.95
	window.size = Vector2i(wanted.min(usable))
	window.move_to_center()


## The windows over the game, which the chooser puts away, as
## the OLPC's WithdrawAll did.
func _hide_windows() -> void:
	for window: Window in [budget_window, evaluation_window, graph_window, map_window]:
		window.hide()
	if get_tree().process_frame.is_connected(open_map):
		get_tree().process_frame.disconnect(open_map)


## The height of a window's title bar, above its position.
func _title_height() -> int:
	return map_window.get_theme_constant("title_height", "Window")


## The width of a window's frame at its sides, outside its position.
func _frame_width() -> float:
	var frame := map_window.get_theme_stylebox("embedded_border", "Window") as StyleBoxFlat
	return frame.expand_margin_left if frame != null else 0.0


func _show_title() -> void:
	var city := engine.get_city_name()
	get_window().title = "Micropolis" if city.is_empty() else "%s - Micropolis" % city


func _show_priority() -> void:
	for item: int in Priority.values():
		priority_menu.set_item_checked(priority_menu.get_item_index(item), item == priority)
	priority_menu.set_item_checked(priority_menu.get_item_index(PAUSE_ITEM), engine.is_paused())
	head.show_priority(PRIORITY_NAMES[priority], engine.is_paused())


## A Priority by number (0 super slow to 4 super fast) or name ("fast",
## "super-slow").
static func _priority_from_arg(value: String) -> Priority:
	if value.is_valid_int():
		return clampi(value.to_int(), Priority.SUPER_SLOW, Priority.SUPER_FAST) as Priority
	return Priority.get(value.to_upper().replace("-", "_").replace(" ", "_"), DEFAULT_PRIORITY)


# Layout ---------------------------------------------------------------------

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 0)
	add_child(columns)

	var head_column := VBoxContainer.new()
	head_column.name = "HeadColumn"
	head_column.custom_minimum_size.x = HEAD_WIDTH
	head_column.add_theme_constant_override("separation", 0)
	columns.add_child(head_column)
	head_column.add_child(_build_menus())
	head = HeadPanel.new()
	head.name = "Head"
	# whead.tcl's click map: the logo pauses, the gauge shows the evaluation,
	# the funds and the tax rate open the budget, the graph the graph window.
	head.gauge.logo_clicked.connect(toggle_pause)
	head.gauge.picture_clicked.connect(toggle_evaluation)
	head.budget_clicked.connect(request_budget)
	head.graph_clicked.connect(toggle_graph)
	head_column.add_child(head)
	var head_buttons := PanelContainer.new()
	head_buttons.name = "HeadButtons"
	head_column.add_child(head_buttons)
	budget_button = Button.new()
	budget_button.name = "Budget"
	budget_button.text = "Budget..."
	budget_button.focus_mode = Control.FOCUS_NONE
	budget_button.pressed.connect(request_budget)
	head_buttons.add_child(budget_button)
	message_log = MessageLog.new()
	message_log.name = "MessageLog"
	head_column.add_child(message_log)
	var rest := PanelContainer.new()
	rest.name = "HeadRest"
	rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# No padding, so the notice's text is the OLPC's 352 pixels wide.
	rest.add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 0))
	head_column.add_child(rest)
	# The OLPC packed its map, then its notice, under the head: the map window
	# floats here, so its room is kept, and the notice fills what's left
	# (wnotice.tcl's expand fill).
	var rest_column := VBoxContainer.new()
	rest_column.add_theme_constant_override("separation", 0)
	rest.add_child(rest_column)
	map_room = Control.new()
	map_room.name = "MapRoom"
	map_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_column.add_child(map_room)
	notice = NoticeBox.new()
	notice.name = "Notice"
	notice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rest_column.add_child(notice)

	var editor := VBoxContainer.new()
	editor.name = "Editor"
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 0)
	columns.add_child(editor)
	# weditor.tcl's top frame: the editor's Options menu in a raised frame,
	# then the message label, Large, on a raised 1-pixel border.
	var top := HBoxContainer.new()
	top.name = "EditorTop"
	top.add_theme_constant_override("separation", 0)
	editor.add_child(top)
	top.add_child(_build_editor_options())
	var message_frame := PanelContainer.new()
	message_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(message_frame)
	message_label = Label.new()
	message_label.name = "Message"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", ClassicTheme.LARGE)
	message_frame.add_child(message_label)
	var body := HBoxContainer.new()
	body.name = "EditorBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	editor.add_child(body)
	palette = Palette.new()
	palette.name = "Palette"
	body.add_child(palette)
	map_view = MapView.new()
	map_view.name = "MapView"
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map_view)

	budget_window = BudgetWindow.new()
	budget_window.name = "BudgetWindow"
	budget_window.theme = theme
	add_child(budget_window)
	evaluation_window = EvaluationWindow.new()
	evaluation_window.name = "EvaluationWindow"
	evaluation_window.theme = theme
	add_child(evaluation_window)
	graph_window = GraphWindow.new()
	graph_window.name = "GraphWindow"
	graph_window.theme = theme
	add_child(graph_window)
	map_window = MapWindow.new()
	map_window.name = "MapWindow"
	map_window.theme = theme
	add_child(map_window)
	map_window.visibility_changed.connect(_keep_map_room)
	new_city_screen = NewCityScreen.new()
	add_child(new_city_screen)
	pie_menus = PieMenus.new()
	pie_menus.name = "PieMenus"
	add_child(pie_menus)
	map_view.pie = pie_menus
	file_dialog = FileDialog.new()
	file_dialog.name = "FileDialog"
	file_dialog.theme = theme
	file_dialog.use_native_dialog = false
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.cty ; Micropolis cities"])
	add_child(file_dialog)
	ask_dialog = ConfirmationDialog.new()
	ask_dialog.name = "AskDialog"
	ask_dialog.theme = theme
	# The notice after a loss is a paragraph.
	ask_dialog.dialog_autowrap = true
	ask_dialog.min_size = Vector2i(440, 0)
	add_child(ask_dialog)


## The editor's Options menu (weditor.tcl): Auto Goto, which the OLPC kept
## here rather than in the head's Options; Pallet Panel, which shows or hides
## the tool palette (SetEditorControls); and Chalk Overlay, which shows or
## hides the chalk in the editor (SetEditorOverlay; the map window always
## shows it). The OLPC's editor showed its chalk from the start, though the
## menu's check began clear; here the check shows it.
func _build_editor_options() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EditorControls"
	var bar := MenuBar.new()
	bar.prefer_global_menu = false
	panel.add_child(bar)
	editor_options_menu = PopupMenu.new()
	editor_options_menu.name = "Options"
	editor_options_menu.add_check_item("Auto Goto", OptionItem.AUTO_GOTO)
	editor_options_menu.add_check_item("Pallet Panel", OptionItem.PALLET_PANEL)
	editor_options_menu.add_check_item("Chalk Overlay", OptionItem.CHALK_OVERLAY)
	editor_options_menu.id_pressed.connect(func(id: int) -> void:
		set_option(id as OptionItem, not editor_options_menu.is_item_checked(editor_options_menu.get_item_index(id))))
	bar.add_child(editor_options_menu)
	return panel


func _build_menus() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Menus"
	var bar := MenuBar.new()
	bar.prefer_global_menu = false
	panel.add_child(bar)

	micropolis_menu = PopupMenu.new()
	micropolis_menu.name = "Micropolis"
	micropolis_menu.add_item("About...", MicropolisItem.ABOUT)
	micropolis_menu.add_item("Save City", MicropolisItem.SAVE)
	micropolis_menu.add_item("Save City as...", MicropolisItem.SAVE_AS)
	micropolis_menu.add_item("Choose City!", MicropolisItem.CHOOSE_CITY)
	micropolis_menu.add_item("Quit Playing!", MicropolisItem.QUIT)
	micropolis_menu.id_pressed.connect(_on_micropolis_item)
	bar.add_child(micropolis_menu)

	# The OLPC's Priority menu (whead.tcl), fastest first, then Pause. Its
	# keys, which the original didn't have, are in the tooltips.
	priority_menu = PopupMenu.new()
	priority_menu.name = "Priority"
	for item: int in [Priority.SUPER_FAST, Priority.FAST, Priority.NORMAL, Priority.SLOW, Priority.SUPER_SLOW]:
		priority_menu.add_radio_check_item(PRIORITY_NAMES[item], item)
	priority_menu.add_check_item("Pause", PAUSE_ITEM)
	for item: int in PRIORITY_KEYS:
		priority_menu.set_item_tooltip(priority_menu.get_item_index(item), "Key: %s" % PRIORITY_KEYS[item])
	priority_menu.id_pressed.connect(func(id: int) -> void:
		if id == PAUSE_ITEM:
			toggle_pause()
		else:
			set_priority(id as Priority))

	options_menu = PopupMenu.new()
	options_menu.name = "Options"
	options_menu.add_check_item("Auto Budget", OptionItem.AUTO_BUDGET)
	options_menu.add_check_item("Auto Bulldoze", OptionItem.AUTO_BULLDOZE)
	options_menu.add_check_item("Disasters", OptionItem.DISASTERS)
	options_menu.add_check_item("Sound", OptionItem.SOUND)
	options_menu.add_check_item("Animation", OptionItem.ANIMATION)
	options_menu.add_check_item("Messages", OptionItem.MESSAGES)
	options_menu.add_check_item("Notices", OptionItem.NOTICES)
	options_menu.id_pressed.connect(func(id: int) -> void:
		set_option(id as OptionItem, not options_menu.is_item_checked(options_menu.get_item_index(id))))
	bar.add_child(options_menu)

	disasters_menu = PopupMenu.new()
	disasters_menu.name = "Disasters"
	disasters_menu.add_item("Monster", DisasterItem.MONSTER)
	disasters_menu.add_item("Fire", DisasterItem.FIRE)
	disasters_menu.add_item("Flood", DisasterItem.FLOOD)
	disasters_menu.add_item("Meltdown", DisasterItem.MELTDOWN)
	disasters_menu.add_item("Air Crash", DisasterItem.AIR_CRASH)
	disasters_menu.add_item("Tornado", DisasterItem.TORNADO)
	disasters_menu.add_item("Earthquake", DisasterItem.EARTHQUAKE)
	disasters_menu.add_separator()
	disasters_menu.add_check_item("Enable Disasters", DisasterItem.ENABLED)
	disasters_menu.id_pressed.connect(func(id: int) -> void:
		if id == DisasterItem.ENABLED:
			set_option(OptionItem.DISASTERS, not engine.get_disasters_enabled())
		else:
			ask_disaster(id as DisasterItem))
	bar.add_child(disasters_menu)

	bar.add_child(priority_menu)

	windows_menu = PopupMenu.new()
	windows_menu.name = "Windows"
	windows_menu.add_item("Budget", WindowItem.BUDGET)
	windows_menu.add_item("Evaluation", WindowItem.EVALUATION)
	windows_menu.add_item("Graph", WindowItem.GRAPH)
	windows_menu.add_item("Map", WindowItem.MAP)
	windows_menu.id_pressed.connect(_on_windows_item)
	bar.add_child(windows_menu)
	return panel


func _on_micropolis_item(id: int) -> void:
	match id:
		MicropolisItem.ABOUT: show_about()
		MicropolisItem.SAVE: save_city()
		MicropolisItem.SAVE_AS: ask_to_save_city()
		MicropolisItem.CHOOSE_CITY: ask_to_choose_city()
		MicropolisItem.QUIT: ask_to_quit()


func _on_windows_item(id: int) -> void:
	match id:
		WindowItem.BUDGET: request_budget()
		WindowItem.EVALUATION: open_evaluation()
		WindowItem.GRAPH: open_graph()
		WindowItem.MAP: open_map()


## A letter typed: the last four are checked for the OLPC's cheat words
## (w_keys.c), which the engine carries out with its own random numbers. A
## word found starts the four afresh, but for "will" and "olpc", as in 1989.
func type_letter(letter: String) -> bool:
	_last_keys = (_last_keys + letter.to_lower()).right(4)
	if _last_keys.length() < 4 or not engine.cheat(_last_keys):
		return false
	if not _last_keys in ["will", "olpc"]:
		_last_keys = ""
	map_view.city_map.sync()
	map_view.sprites.sync()
	return true


## F10: the first menu, Micropolis, opens (tk_firstMenu).
func open_first_menu() -> void:
	var bar: MenuBar = micropolis_menu.get_parent()
	micropolis_menu.popup(Rect2i(Vector2i(bar.global_position + Vector2(0, bar.size.y)), Vector2i.ZERO))


## A message in the editor's message line and the head's log, as 1989's
## UISetMessage showed it; nothing with Messages off.
func set_message(text: String, tag := "status") -> void:
	if text.is_empty() or not engine.get_messages():
		return
	message_label.text = text
	message_log.add(text, tag)


## A notice at the foot of the head column (UIShowPictureOn); nothing with
## Notices off.
func show_notice(title: String, color: Color, text: String, at := NoticeBox.NOWHERE,
		follow := CityEngine.SpriteType.NONE) -> void:
	if engine.get_notices():
		notice.show_notice(title, color, text, at, follow)


## A disaster from the menu: asked first, as UIDisaster did, titled in red.
func ask_disaster(item: DisasterItem) -> void:
	_ask("Cause a Disaster", "Oh no! Do you really want to %s" % DISASTER_ACTIONS[item], "I guess so.", "No way!",
		trigger_disaster.bind(item), QUESTION_COLOR)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ask_to_quit()
	elif what == NOTIFICATION_WM_ABOUT:
		show_app_about()


## About Metrobits, from the macOS menu bar: a native dialog with the version
## and the notices. The game's own About, in the Micropolis menu, shows the
## 1989 credits.
func show_app_about() -> void:
	app_about_count += 1
	DisplayServer.dialog_show("Metrobits", Notices.app_about_text(), PackedStringArray(["OK"]),
		func(_button: int) -> void: pass)


## The engine's yearly evaluation: UISetEvaluation's line, "Jan 1973: Score
## 500, town population 12345."
func _on_evaluation() -> void:
	var evaluation := engine.get_evaluation()
	var city_class: String = EvaluationWindow.CLASSES[clampi(evaluation.city_class, 0, 5)]
	set_message("%s: Score %d, %s population %d." % [HeadPanel.format_date(engine.get_year(), engine.get_month()),
		evaluation.score, city_class.to_lower(), evaluation.population])


## UIDidntLoadCity: the reason in red in the log, and Sorry.
func _didnt_load(path: String) -> void:
	message_log.add("Unable to load a city from the file named \"%s\"." % path, "alert")
	sounds.play("Sorry", 85)
