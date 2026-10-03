## The OLPC's city chooser, "Micropolis Scenarios" (wscen.tcl), on its own
## painted 1200 x 900 screen (background-micropolis.xpm). The buttons are
## places on the painting, micropolis.tcl's ScenarioButtons: under the pointer
## each shows its "hilite" picture, a checked level its "checked" one, and a
## disabled arrow its "disabled" one; a click acts on release over the button
## it went down on (HandleScenarioDown, HandleScenarioUp and
## HandleScenarioMove).
##
## Everything it shows is a preview in the engine, as the OLPC's was: a
## scenario picked (DoPickScenario), a map generated (Generate New Terrain),
## a city loaded (Load City), and the About city (cities/about.cty) each load
## into the engine and show in the map at the top, the city's own map view,
## drawn as the map window draws it. Play This Map plays whatever it shows
## (UIUseThisMap). The maps shown so far are a history, which the arrows step
## through (MakeHistory, GotoHistory): the right arrow is disabled at its end.
##
## While the pointer is on a scenario, the panel on the left shows its title
## and description, as UpdateScenarioButton did. Otherwise it shows notice 48,
## "Start a New City", for a generated map and notice 49, "Restore a Saved
## City", for a loaded one: the OLPC sent both to its hidden head window, so
## showing them here is a quality-of-life addition.
##
## It only shows and asks; the game window loads into the engine.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name NewCityScreen
extends Control

## A scenario picked: load it into the engine to show (DoScenario).
signal scenario_wanted(scenario: int)
## A map to generate from this seed and show (DoNewCity).
signal map_wanted(seed: int)
## A city to load and show (DoLoadCity), by path.
signal city_wanted(path: String)
## A game level clicked (DoLevel): set it, and its funds.
signal level_wanted(level: int)
## Play This Map, under this name, at this level (-1 for a loaded city,
## whose level stays).
signal play_requested(city_name: String, level: int)
## Load City: the file chooser.
signal load_requested
## Quit: the question.
signal quit_requested

## The painting, and its size.
const BACKGROUND := "background-micropolis"
const SIZE := Vector2(1200, 900)
## The canvas behind it (wscen.tcl's -background).
const CANVAS_COLOR := Color("#bfbfbf")
## micropolis.tcl's ScenarioButtons: id, what it does, its parameter, its
## place, and its pictures: under the pointer, disabled, checked, and checked
## under the pointer ("" for none, where the painting shows).
const BUTTONS := [
	{id = "load", action = "load", rect = Rect2(70, 238, 157, 90), over = "button1hilite"},
	{id = "generate", action = "generate", rect = Rect2(62, 392, 157, 90), over = "button2hilite"},
	{id = "quit", action = "quit", rect = Rect2(68, 544, 157, 90), over = "button3hilite"},
	{id = "about", action = "about", rect = Rect2(101, 705, 157, 90), over = "button4hilite"},
	{id = "easy", action = "level", param = 0, rect = Rect2(982, 106, 190, 70), over = "checkbox1hilite",
		checked = "checkbox1checked", checked_over = "checkbox1hilitechecked"},
	{id = "medium", action = "level", param = 1, rect = Rect2(982, 176, 190, 70), over = "checkbox2hilite",
		checked = "checkbox2checked", checked_over = "checkbox2hilitechecked"},
	{id = "hard", action = "level", param = 2, rect = Rect2(982, 246, 190, 70), over = "checkbox3hilite",
		checked = "checkbox3checked", checked_over = "checkbox3hilitechecked"},
	{id = "left", action = "left", rect = Rect2(540, 375, 50, 50), over = "lefthilite", disabled = "leftdisabled"},
	{id = "right", action = "right", rect = Rect2(841, 375, 50, 50), over = "righthilite",
		disabled = "rightdisabled"},
	{id = "play", action = "play", rect = Rect2(625, 376, 180, 50), over = "playhilite"},
	{id = "scenario1", action = "scenario", param = 1, rect = Rect2(310, 451, 209, 188), over = "scenario1hilite"},
	{id = "scenario2", action = "scenario", param = 2, rect = Rect2(519, 451, 209, 188), over = "scenario2hilite"},
	{id = "scenario3", action = "scenario", param = 3, rect = Rect2(727, 450, 209, 188), over = "scenario3hilite"},
	{id = "scenario4", action = "scenario", param = 4, rect = Rect2(936, 450, 209, 188), over = "scenario4hilite"},
	{id = "scenario5", action = "scenario", param = 5, rect = Rect2(310, 639, 209, 188), over = "scenario5hilite"},
	{id = "scenario6", action = "scenario", param = 8, rect = Rect2(519, 639, 209, 188), over = "scenario6hilite"},
	{id = "scenario7", action = "scenario", param = 7, rect = Rect2(728, 638, 209, 188), over = "scenario7hilite"},
	{id = "scenario8", action = "scenario", param = 6, rect = Rect2(937, 638, 209, 188), over = "scenario8hilite"},
]
## wscen.tcl's places: the map view, the City Name frame, and UpdateScenarioButton's description.
const MAP_AT := Vector2(534, 48)
const NAME_AT := Vector2(530, 0)
const DESCRIPTION_RECT := Rect2(232, 170, 280, 285)
## The city About shows (DoAbout).
const ABOUT_CITY := "cities/about.cty"
## 1989's scenario numbers, in the painting's order.
const SCENARIO_ORDER := [1, 2, 3, 4, 5, 8, 7, 6]
## The content's notice for "Start a New City", which has the OLPC's words
## for its Message 48; and the OLPC's Message 49, which the content words
## differently ("The city was restored.").
const NEW_CITY_NOTICE := 45
const SAVED_CITY_TITLE := "Restore a Saved City"
const SAVED_CITY_TEXT := "This city was saved in the file named: %s"

## The painted screen, scaled to fit the window.
var canvas: Canvas
## The engine's map, as the map window draws it.
var preview: SmallMap
var name_edit: LineEdit
var description: Label
## The game level checked: 0 easy to 2 hard, or -1 for a loaded city (GameLevel).
var game_level := 0
## The maps shown, in order: {kind: "map", seed}, {kind: "scenario",
## scenario} or {kind: "city", path}; and the one showing (MapHistoryNum).
var history: Array[Dictionary] = []
var history_index := -1
## The button under the pointer, and the one a press went down on (-1 for none).
var hovered := -1
var pressed_on := -1
var rng := RandomNumberGenerator.new()

## The chooser's own notice for the map showing: {title, text}, or {}.
var _notice := {}


## A scenario's name and its disaster, from the content's strings (whose "San
## Francsico" is spelled as the engine names the city).
static func scenario_title(scenario: int) -> String:
	return Notices.string("scenario_%d_title" % scenario).replace("Francsico", "Francisco")


static func scenario_tagline(scenario: int) -> String:
	return Notices.string("scenario_%d_tagline" % scenario)


## The id of a scenario's button, e.g. "scenario6" for Rio (8).
static func scenario_button(scenario: int) -> String:
	for button: Dictionary in BUTTONS:
		if button.action == "scenario" and button.param == scenario:
			return button.id
	return ""


## The index in BUTTONS of a button by id, or -1.
static func button_index(id: String) -> int:
	for i in BUTTONS.size():
		if BUTTONS[i].id == id:
			return i
	return -1


func _init() -> void:
	name = "NewCityScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	rng.randomize()
	canvas = Canvas.new()
	canvas.screen = self
	add_child(canvas)

	preview = SmallMap.new()
	preview.name = "Map"
	preview.position = MAP_AT
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(preview)

	# The City Name frame (-borderwidth 2 -relief flat): its label and a
	# 33-character entry, both in Text's size.
	var frame := PanelContainer.new()
	frame.name = "CityName"
	frame.position = NAME_AT
	frame.add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.FLAT, ClassicTheme.BACKGROUND, 2, 2))
	canvas.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	frame.add_child(row)
	var caption := Label.new()
	caption.text = "City Name:"
	row.add_child(caption)
	name_edit = LineEdit.new()
	name_edit.max_length = 32
	var font := Content.olpc_font()
	name_edit.custom_minimum_size.x = 33 * font.get_char_size(ord("0"), ClassicTheme.MEDIUM).x + 8
	row.add_child(name_edit)

	# UpdateScenarioButton's text: -borderwidth 2 -relief flat -wrap word, in Large.
	var panel := PanelContainer.new()
	panel.name = "Description"
	panel.position = DESCRIPTION_RECT.position
	panel.size = DESCRIPTION_RECT.size
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.FLAT, ClassicTheme.BACKGROUND, 2, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.custom_minimum_size = DESCRIPTION_RECT.size - Vector2(8, 8)
	description.add_theme_font_size_override("font_size", ClassicTheme.LARGE)
	panel.add_child(description)
	panel.visible = false


## The engine whose map it shows, drawn with this tile art.
func setup(engine: CityEngine, art: Image) -> void:
	preview.setup(engine, art, null)


## Opens on a new map, as UIPickScenarioMode did: the history starts afresh,
## the level is Easy, and a map is generated at once.
func open() -> void:
	history.clear()
	history_index = -1
	hovered = -1
	pressed_on = -1
	game_level = 0
	visible = true
	generate()
	_show_state()


## Redraws the map from the engine, after a preview loads.
func show_map() -> void:
	preview.set_mode(SmallMap.Mode.ALL)


## The level shown as checked (UISetGameLevel), -1 for none.
func show_level(level: int) -> void:
	game_level = level
	_show_state()


## The notice for the map showing: 48 for a generated map, 49 (with its file)
## for a loaded city, or none.
func show_notice(kind: String, path := "") -> void:
	match kind:
		"map":
			var found := Notices.for_message(NEW_CITY_NOTICE)
			_notice = {title = found.get("title", "Start a New City"), text = found.get("text", "")}
		"city":
			_notice = {title = SAVED_CITY_TITLE, text = SAVED_CITY_TEXT % path}
		_:
			_notice = {}
	_show_state()


## The description panel's text now: the scenario under the pointer, or the
## chooser's notice, or "" when it's hidden.
func description_text() -> String:
	if hovered >= 0 and BUTTONS[hovered].action == "scenario":
		var found := Notices.for_scenario(BUTTONS[hovered].param)
		return "%s\n\n%s" % [found.get("title", ""), found.get("text", "")]
	if not _notice.is_empty():
		return "%s\n\n%s" % [_notice.title, _notice.text]
	return ""


## Whether a button can be pointed at and clicked: the arrows only when there's
## a map that way.
func is_enabled(index: int) -> bool:
	match BUTTONS[index].id:
		"left":
			return history_index >= 1
		"right":
			return history_index < history.size() - 1
	return true


## Whether a level button shows checked.
func is_checked(index: int) -> bool:
	return BUTTONS[index].action == "level" and BUTTONS[index].param == game_level


## The picture a button shows now (UpdateScenarioButton), or "" for the painting.
func picture(index: int) -> String:
	var button: Dictionary = BUTTONS[index]
	var over := index == hovered
	if not is_enabled(index):
		return button.get("disabled", "")
	if is_checked(index):
		return button.get("checked_over" if over else "checked", "")
	return button.over if over else ""


## The enabled button at a point on the painting, or -1 (HandleScenarioMove).
func button_at(point: Vector2) -> int:
	for i in BUTTONS.size():
		if is_enabled(i) and BUTTONS[i].rect.has_point(point):
			return i
	return -1


## The pointer moved to a point on the painting.
func point_at(point: Vector2) -> void:
	var found := button_at(point)
	if found != hovered:
		hovered = found
		_show_state()


## A press at a point: remembers the button (HandleScenarioDown).
func press_at(point: Vector2) -> void:
	point_at(point)
	pressed_on = hovered


## A release at a point: acts if it's over the button the press went down on
## (HandleScenarioUp).
func release_at(point: Vector2) -> void:
	point_at(point)
	if hovered >= 0 and hovered == pressed_on:
		activate(BUTTONS[hovered].id)
	pressed_on = -1


## Does what a button does, by id.
func activate(id: String) -> void:
	var index := button_index(id)
	if index < 0 or not is_enabled(index):
		return
	var button: Dictionary = BUTTONS[index]
	match button.action:
		"load":
			load_requested.emit()
		"generate":
			generate()
		"quit":
			quit_requested.emit()
		"about":
			load_city(ABOUT_CITY)
		"level":
			level_wanted.emit(button.param)
		"left":
			go_to(history_index - 1)
		"right":
			go_to(history_index + 1)
		"play":
			play_requested.emit(name_edit.text.strip_edges(), game_level)
		"scenario":
			make_history({kind = "scenario", scenario = button.param})


## Generate New Terrain: a new map from a fresh seed (UIGenerateNewCity), at
## Easy if a loaded city had left no level.
func generate() -> void:
	if game_level == -1:
		game_level = 0
	make_history({kind = "map", seed = rng.randi_range(0, 0x7fffffff)})


## A city to show, from Load City's file chooser or About (UIDoLoadCity).
func load_city(path: String) -> void:
	make_history({kind = "city", path = path})


## Adds a map to the history unless it's the last one again, and shows it
## (MakeHistory).
func make_history(entry: Dictionary) -> void:
	if history.is_empty() or history[-1] != entry:
		history.append(entry)
	go_to(history.size() - 1)


## Shows the map at a place in the history, loading it unless it's showing
## (GotoHistory).
func go_to(index: int) -> void:
	if index < 0 or index >= history.size():
		return
	if index != history_index:
		history_index = index
		var entry := history[index]
		match entry.kind:
			"map": map_wanted.emit(entry.seed)
			"scenario": scenario_wanted.emit(entry.scenario)
			"city": city_wanted.emit(entry.path)
	# The pointer may be on an arrow that has just been disabled.
	if hovered >= 0 and not is_enabled(hovered):
		hovered = -1
	_show_state()


## The history's entry showing, or {}.
func showing() -> Dictionary:
	return history[history_index] if history_index >= 0 and history_index < history.size() else {}


func _show_state() -> void:
	var text := description_text()
	description.text = text
	description.get_parent().visible = text != ""
	canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and canvas != null:
		canvas.fit(size)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CANVAS_COLOR)


## The painted screen: the painting, then each button's picture, at 1200 x
## 900, scaled to fit the window and centred.
class Canvas:
	extends Control

	var screen: NewCityScreen

	func _init() -> void:
		size = NewCityScreen.SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func fit(area: Vector2) -> void:
		var factor := minf(area.x / NewCityScreen.SIZE.x, area.y / NewCityScreen.SIZE.y)
		scale = Vector2(factor, factor)
		position = ((area - NewCityScreen.SIZE * factor) / 2.0).floor()

	func _draw() -> void:
		draw_texture(Content.olpc_texture(NewCityScreen.BACKGROUND), Vector2.ZERO)
		for i in NewCityScreen.BUTTONS.size():
			var picture := screen.picture(i)
			if picture != "":
				draw_texture(Content.olpc_texture(picture), NewCityScreen.BUTTONS[i].rect.position)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			screen.point_at(event.position)
		elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE,
				MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				screen.press_at(event.position)
			else:
				screen.release_at(event.position)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			screen.point_at(Vector2(-1, -1))
