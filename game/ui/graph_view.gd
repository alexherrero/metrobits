## The original's graph (w_graph.c's DoUpdateGraph): the six histories over
## 10 or 120 years on light gray, each a three-pixel line in its colour with
## its name at the right-hand end, the years (or decades) along the top with a
## line at each, and a line above and below. Residential, commercial and
## industrial share a scale, 128 at the largest of them once that passes 128
## (doAllGraphs); cash flow, crime and pollution are drawn as the engine keeps
## them, 0 to 255.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name GraphView
extends Control

## w_graph.c's HistName and HistColor, in CityEngine.HistoryType's order.
const NAMES := ["Residential", "Commercial", "Industrial", "Cash Flow", "Crime", "Pollution"]
const COLORS := [Color("#00e600"), Color("#0000e6"), Color("#ffff00"), Color("#007f00"), Color("#ff0000"),
	Color("#997f4c")]
const ALL := 0b111111
const BORDER := 5.0
const TOP_LABELS := 30.0
const RIGHT_LABELS := 65.0
const LINE_WIDTH := 3.0

## Which graphs show, one bit each in HistoryType's order (1989's Mask).
var mask := ALL:
	set(value):
		mask = value
		queue_redraw()
## HistoryScale.SHORT for 10 years, LONG for 120 (1989's Range).
var history_scale := CityEngine.HistoryScale.SHORT:
	set(value):
		history_scale = value
		queue_redraw()
## graphview -font [Font $win Small] (wgraph.tcl).
var font_size := ClassicTheme.SMALL

var _engine: CityEngine


## A history as the graph plots it, oldest first, 0 to 255 (drawMonth).
static func plotted(values: PackedInt32Array, factor: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(CityEngine.HISTORY_LENGTH)
	for x in CityEngine.HISTORY_LENGTH:
		out[CityEngine.HISTORY_LENGTH - 1 - x] = clampi(int(values[x] * factor), 0, 255)
	return out


## doAllGraphs' scale for residential, commercial and industrial: 128 at the
## largest value (InitGraphMax looked at all but the oldest), once it's over
## 128.
static func rci_factor(histories: Array) -> float:
	var most := 0
	for values: PackedInt32Array in histories:
		for x in CityEngine.HISTORY_LENGTH - 1:
			most = maxi(most, values[x])
	return 128.0 / most if most > 128 else 1.0


func _init() -> void:
	custom_minimum_size = Vector2(360, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(engine: CityEngine) -> void:
	_engine = engine
	if not engine.history_changed.is_connected(queue_redraw):
		engine.history_changed.connect(queue_redraw)
	queue_redraw()


## Each history as plotted, by HistoryType.
func plots() -> Array[PackedInt32Array]:
	var histories: Array[PackedInt32Array] = []
	for type in NAMES.size():
		histories.append(_engine.get_history(type, history_scale))
	var factor := rci_factor(histories.slice(0, 3))
	var out: Array[PackedInt32Array] = []
	for type in NAMES.size():
		out.append(plotted(histories[type], factor if type < 3 else 1.0))
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SmallMap.LIGHT_GRAY)
	if _engine == null:
		return
	var font := get_theme_font("font", "Label")
	var left := BORDER
	var top := BORDER
	var width := maxf(size.x - 2 * BORDER, 1)
	var height := maxf(size.y - 2 * BORDER, 1)
	var right_labels := width > 4 * RIGHT_LABELS
	if right_labels:
		width -= RIGHT_LABELS
	var top_labels := right_labels and height > 3 * TOP_LABELS
	if top_labels:
		top += TOP_LABELS
		height -= TOP_LABELS
	var sx := width / 120.0
	var sy := height / 256.0
	var plots := plots()
	for type in NAMES.size():
		if not mask & (1 << type):
			continue
		var points := PackedVector2Array()
		var y := 0.0
		for j in 120:
			y = top + int(height - plots[type][j] * sy)
			points.append(Vector2(left + int(j * sx), y))
		var end := Vector2(left + int(120 * sx), y)
		points.append(end)
		draw_polyline(points, COLORS[type], LINE_WIDTH)
		if right_labels:
			# 1989's label: the name in its colour, offset up and left, under
			# the name in black.
			var at := end + Vector2(5, 5)
			draw_string(font, at - Vector2(1, 0), NAMES[type], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS[type])
			draw_string(font, at - Vector2(0, 1), NAMES[type], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS[type])
			draw_string(font, at, NAMES[type], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	draw_line(Vector2(left, top - 1), Vector2(left + width, top - 1), Color.BLACK)
	draw_line(Vector2(left, top + height), Vector2(left + width, top + height), Color.BLACK)
	for mark in year_marks():
		var xx: float = left + mark.x * sx
		draw_line(Vector2(xx, top - 1), Vector2(xx, top + height), Color.BLACK)
		if top_labels:
			draw_string(font, Vector2(xx + 2, top - float(mark.lift)), str(mark.label), HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, Color.BLACK)


## The year lines, as DoUpdateGraph placed them: {x (0 to 120 along the
## graph), label, lift (how far above the graph the label sits, alternating)}.
func year_marks() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	var time := _engine.get_city_time()
	var year := time / 48 + 1900
	var month := (time / 4) % 12
	if history_scale == CityEngine.HistoryScale.SHORT:
		var x := 120 - month
		while x >= 0:
			var label := str(year)
			year -= 1
			marks.append({x = float(x), label = label, lift = 4.0 if year & 1 else 20.0})
			x -= 12
	else:
		var past := 10 * (year % 10)
		var decade := year / 10
		var x := 1200 - past
		while x >= 0:
			var label := "%d0" % decade
			decade -= 1
			marks.append({x = x / 10.0, label = label, lift = 4.0 if decade & 1 else 20.0})
			x -= 120
	return marks
