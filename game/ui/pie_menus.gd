## The OLPC editor's pie menus: Don Hopkins' circular menus, as
## micropolis-activity defines them (weditor.tcl's toolpie, zonepie and
## buildpie; micropolis.tcl's pie handlers; w_piem.c, the widget). The right
## button, or Shift with the left, over the editor opens the Tool pie
## centred on the pointer (InitPie):
## - Tool: Road, Bulldozer, Zone (a pie of its own), Wire, Rail, Chalk, Build
##   (a pie of its own) and Eraser, counter-clockwise from the right;
## - Zone: Query, Police, Ind, Com, Res and Fire, from the bottom;
## - Build: Airport, Nuclear, Seaport, Park, Stadium and Coal, from the bottom.
##
## Each item has a slice of the circle, and the pointer's direction from the
## centre picks it, past an 8-pixel dead zone in the middle (CalcPieMenuItem).
## A drag and release in a slice picks it at once (a flick); a release in the
## middle leaves the pie showing for a click (ClickedUp, then SecondDown). A
## pie item opens its pie where the pointer is, which a second press picks
## from (SelectedUp). A release in the middle the second time cancels, with
## Oop.
##
## Mouse-ahead: a pie isn't drawn until the pointer has rested 250 ms
## (-popupdelay; each move while it waits starts the wait again, "defer"). A
## command picked before the pie showed earns $5 and Aaah, as the OLPC's
## reward for knowing the way. Opening the Tool pie says Woosh at volume 40,
## and each pick says its label.
##
## The OLPC's pies were shaped windows: only the title and the items' raised
## boxes show, sunken while pointed at, with no disc behind them.
##
## While a pie is open, PieMenus takes every mouse event over the window (the
## OLPC's grab), and the editor hands it the press that opened it.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name PieMenus
extends Control

## A command item was picked: its tool.
signal tool_chosen(tool: int)
## A sound to play, by name, at a volume in percent.
signal sound_wanted(sound: String, volume: int)
## The mouse-ahead reward: $5.
signal rewarded(dollars: int)
## A press outside the pie's own buttons cancelled it (the editor's <1>
## binding ran CancelPie, then its tool).
signal passed_on(event: InputEventMouseButton)

enum State { INITIAL, FIRST_DOWN, CLICKED_UP, SELECTED_UP, SECOND_DOWN }

const T := CityEngine.Tool
## The three pies, from weditor.tcl: title, -fixedradius, -initialangle,
## -preview's sound, and each item's -label, its picture (or "pie" for a pie
## of its own) and its -xoffset and -yoffset, in w_piem.c's right-side-up
## coordinates.
const PIES := {
	tool = {title = "Tool", radius = 26, initial = 0, preview = "Woosh", items = [
		{label = "Road", icon = "icroadhi", offset = Vector2(-4, 0), tool = T.ROAD},
		{label = "Bulldozer", icon = "icdozrhi", offset = Vector2(5, 17), tool = T.BULLDOZER},
		{label = "Zone", pie = "zone"},
		{label = "Wire", icon = "icwirehi", offset = Vector2(-4, 17), tool = T.WIRE},
		{label = "Rail", icon = "icrailhi", offset = Vector2(4, 0), tool = T.RAILROAD},
		{label = "Chalk", icon = "icchlkhi", offset = Vector2(-4, -17), tool = Tools.CHALK},
		{label = "Build", pie = "build"},
		{label = "Eraser", icon = "icersrhi", offset = Vector2(4, -17), tool = Tools.ERASER},
	]},
	zone = {title = "Zone", radius = 20, initial = 270, preview = "", items = [
		{label = "Query", icon = "icqryhi", offset = Vector2(0, 5), tool = T.QUERY},
		{label = "Police", icon = "icpolhi", offset = Vector2(4, -10), tool = T.POLICE_STATION},
		{label = "Ind", icon = "icindhi", offset = Vector2(4, 25), tool = T.INDUSTRIAL},
		{label = "Com", icon = "iccomhi", offset = Vector2(0, -5), tool = T.COMMERCIAL},
		{label = "Res", icon = "icreshi", offset = Vector2(-4, 25), tool = T.RESIDENTIAL},
		{label = "Fire", icon = "icfirehi", offset = Vector2(-4, -10), tool = T.FIRE_STATION},
	]},
	build = {title = "Build", radius = 25, initial = 270, preview = "", items = [
		{label = "Airport", icon = "icairphi", offset = Vector2(0, 7), tool = T.AIRPORT},
		{label = "Nuclear", icon = "icnuchi", offset = Vector2(11, -10), tool = T.NUCLEAR_POWER},
		{label = "Seaport", icon = "icseaphi", offset = Vector2(0, 14), tool = T.SEAPORT},
		{label = "Park", icon = "icparkhi", offset = Vector2(0, -5), tool = T.PARK},
		{label = "Stadium", icon = "icstadhi", offset = Vector2(0, 14), tool = T.STADIUM},
		{label = "Coal", icon = "iccoalhi", offset = Vector2(-11, -10), tool = T.COAL_POWER},
	]},
}
## w_piem.c's defaults: border and active border 2, a dead zone of 8.
const BORDER := 2
const ACTIVE_BORDER := 2
const INACTIVE_RADIUS := 8
const POPUP_DELAY := 0.25
## *PieMenu.activeBackground, and the text.
const ITEM_BACKGROUND := Color("#b0b0b0")
const TEXT := Color.BLACK

## The pie open (a key of PIES, or "" for none), its layout, and its centre in
## this control.
var pie := ""
var layout := {}
var center := Vector2.ZERO
var state := State.INITIAL
## The item pointed at, or -1.
var active := -1
## Whether it has been drawn (after the popup delay, or a click).
var shown := false

var _wait := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Whether a pie is open.
func is_open() -> bool:
	return pie != ""


## The press that opens the Tool pie, at a point in this control
## (PieMenuDown, Initial).
func open(at: Vector2) -> void:
	if is_open():
		cancel()
		return
	_post("tool", at)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	state = State.FIRST_DOWN


## Cancels the open pie (CancelPie): unposted, with Oop.
func cancel() -> void:
	if not is_open():
		return
	sound_wanted.emit("Oop", 100)
	_close()


## A mouse event while a pie is open, in this control's coordinates. The
## editor passes on the events of the press that opened it.
func handle(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseMotion:
		_motion(event.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var pie_button := button.button_index == MOUSE_BUTTON_RIGHT or (button.button_index == MOUSE_BUTTON_LEFT
			and (button.shift_pressed or state in [State.FIRST_DOWN, State.SECOND_DOWN]))
		if not pie_button:
			if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				cancel()
				passed_on.emit(button)
			return
		if button.pressed:
			_down(button.position)
		else:
			_up(button.position)


## Moves time on: the pie shows once the pointer has rested POPUP_DELAY.
func step(delta: float) -> void:
	if is_open() and not shown:
		_wait -= delta
		if _wait <= 0.0:
			show_pie()


## Draws the pie now (show).
func show_pie() -> void:
	shown = true
	queue_redraw()


## Whether a pick now would earn the reward (pending).
func is_pending() -> bool:
	return is_open() and not shown


## Which item a point picks, or -1 (CalcPieMenuItem): its direction from the
## centre, past the dead zone, as w_piem.c measured it (one pixel in, y up).
static func item_at(pie_name: String, from_center: Vector2) -> int:
	var items: Array = PIES[pie_name].items
	var dx := from_center.x + 1.0
	var dy := -from_center.y - 1.0
	if items.is_empty() or dx * dx + dy * dy < INACTIVE_RADIUS * INACTIVE_RADIUS:
		return -1
	var subtend := TAU / items.size()
	var start := deg_to_rad(PIES[pie_name].initial) - subtend / 2.0
	return int(fposmod(atan2(dy, dx) - start, TAU) / subtend) % items.size()


## A pie's layout, as LayoutPieMenu worked it out: each item's box and where
## its picture or label goes, the title's box and text, and the centre, all in
## the pie's own pixels from its top-left.
static func lay_out(pie_name: String, font: Font, font_size: int) -> Dictionary:
	var spec: Dictionary = PIES[pie_name]
	var items: Array = spec.items
	var ascent := int(font.get_ascent(font_size))
	var descent := int(font.get_descent(font_size))
	var subtend := TAU / items.size()
	var boxes: Array[Dictionary] = []
	var min_x := 0
	var min_y := 0
	var max_x := 0
	var max_y := 0
	for i in items.size():
		var item: Dictionary = items[i]
		var size: Vector2i
		if item.has("icon"):
			size = Vector2i(Palette.icon_texture(item.icon).get_size())
		else:
			size = Vector2i(int(font.get_string_size(item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x),
				ascent + descent)
		size += Vector2i(2 * ACTIVE_BORDER + 2, 2 * ACTIVE_BORDER + 2)
		var angle := deg_to_rad(spec.initial) + i * subtend
		var offset: Vector2 = item.get("offset", Vector2.ZERO)
		var x := int(spec.radius * cos(angle) + offset.x)
		var y := int(spec.radius * sin(angle) + offset.y)
		if absi(x) <= 2:
			x -= size.x / 2
			if y < 0:
				y -= size.y
		else:
			if x < 0:
				x -= size.x
			y -= size.y / 2
		var label := Vector2i(x + ACTIVE_BORDER + 1, y - ACTIVE_BORDER - 1)
		if not item.has("icon"):
			label.y -= ascent
		boxes.append({x = x, y = y, size = size, label = label})
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x + size.x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y + size.y)
	var title_height := ascent + descent + 2
	var title_width := int(font.get_string_size(spec.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 2
	min_x = mini(min_x, -(title_width / 2))
	max_x = maxi(max_x, title_width / 2)
	max_y += 2 * BORDER + title_height
	min_x -= 2 * BORDER
	min_y -= 2 * BORDER
	max_x += 2 * BORDER
	max_y += 2 * BORDER
	var center := Vector2i(-min_x, max_y)
	var out_boxes: Array[Dictionary] = []
	for box: Dictionary in boxes:
		# Into window coordinates, y down.
		out_boxes.append({
			rect = Rect2i(center.x + box.x, center.y - box.y - box.size.y, box.size.x, box.size.y),
			label = Vector2i(center.x + box.label.x, center.y - box.label.y - box.size.y),
		})
	return {
		size = Vector2i(max_x - min_x, max_y - min_y), center = center, items = out_boxes,
		title_rect = Rect2i(BORDER, BORDER, max_x - min_x - 2 * BORDER, title_height + 2 * BORDER),
		title_at = Vector2i(center.x - title_width / 2 + 1, 2 * BORDER + ascent + 1),
	}


func _process(delta: float) -> void:
	step(delta)


func _gui_input(event: InputEvent) -> void:
	handle(event)
	accept_event()


func _post(pie_name: String, at: Vector2) -> void:
	pie = pie_name
	center = at
	active = -1
	shown = false
	_wait = POPUP_DELAY
	layout = lay_out(pie, _font(), ClassicTheme.MEDIUM)
	if PIES[pie].preview != "":
		sound_wanted.emit(PIES[pie].preview, 40)
	queue_redraw()


func _close() -> void:
	pie = ""
	active = -1
	shown = false
	state = State.INITIAL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	queue_redraw()


func _track(at: Vector2) -> void:
	var item := item_at(pie, at - center)
	if item != active:
		active = item
		queue_redraw()


## Waits again for the pointer to rest, while the pie isn't drawn yet.
func _defer() -> void:
	if not shown:
		_wait = POPUP_DELAY


func _motion(at: Vector2) -> void:
	match state:
		State.FIRST_DOWN, State.SECOND_DOWN:
			_track(at)
			_defer()
		State.CLICKED_UP, State.SELECTED_UP:
			if active != -1:
				active = -1
				queue_redraw()


func _down(at: Vector2) -> void:
	match state:
		State.CLICKED_UP:
			_track(at)
			state = State.SECOND_DOWN
		State.SELECTED_UP:
			active = -1
			_defer()
			if PIES[pie].preview != "":
				sound_wanted.emit(PIES[pie].preview, 40)
			state = State.SECOND_DOWN
		_:
			cancel()


func _up(at: Vector2) -> void:
	if not state in [State.FIRST_DOWN, State.SECOND_DOWN]:
		cancel()
		return
	_track(at)
	if active == -1:
		if state == State.FIRST_DOWN:
			# A click: the pie shows at once and waits for another.
			show_pie()
			state = State.CLICKED_UP
		else:
			cancel()
		return
	var item: Dictionary = PIES[pie].items[active]
	sound_wanted.emit(item.label, 100)
	if item.has("pie"):
		_post(item.pie, at)
		state = State.SELECTED_UP
		return
	var reward := is_pending()
	_close()
	if reward:
		rewarded.emit(5)
		sound_wanted.emit("Aaah", 100)
	tool_chosen.emit(item.tool)


func _font() -> Font:
	return Content.olpc_font()


func _draw() -> void:
	if not is_open() or not shown:
		return
	var origin := (center - Vector2(layout.center)).floor()
	var font := _font()
	# The title: raised, with the title centred in it.
	var title_rect: Rect2i = layout.title_rect
	draw_style_box(ClassicTheme.border(TkBorder.Relief.RAISED, ITEM_BACKGROUND, BORDER, 0),
		Rect2(origin + Vector2(title_rect.position), Vector2(title_rect.size)))
	draw_string(font, origin + Vector2(layout.title_at), PIES[pie].title, HORIZONTAL_ALIGNMENT_LEFT, -1,
		ClassicTheme.MEDIUM, TEXT)
	# Each item: raised, sunken while pointed at, with its picture or label.
	var items: Array = PIES[pie].items
	for i in items.size():
		var box: Dictionary = layout.items[i]
		var rect := Rect2(origin + Vector2(box.rect.position), Vector2(box.rect.size))
		var relief := TkBorder.Relief.SUNKEN if i == active else TkBorder.Relief.RAISED
		draw_style_box(ClassicTheme.border(relief, ITEM_BACKGROUND, ACTIVE_BORDER, 0), rect)
		var at := origin + Vector2(box.label)
		if items[i].has("icon"):
			draw_texture(Palette.icon_texture(items[i].icon), at)
		else:
			# The layout gives a label's baseline, as TkDisplayChars took it.
			draw_string(font, at, items[i].label, HORIZONTAL_ALIGNMENT_LEFT, -1, ClassicTheme.MEDIUM, TEXT)
