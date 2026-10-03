## The head window's demand canvas (whead.tcl), 80 x 55 on #BFBFBF: the
## OLPC's logo at (0, 4), micropolisg.xpm while the city runs and
## micropoliss.xpm while it's stopped (UIUpdateRunning); the gauge's picture,
## demandg.xpm, at (41, 4); and a green, a blue and a yellow bar over it for
## residential, commercial and industrial demand.
##
## The bars are UISetDemand's: each engine valve, cut to -1500 to 1500 and
## divided by 100 (drawValve), is a bar that many pixels tall, rising from
## y = 24 for a demand or falling from y = 32 for a surplus, at x 49, 58 and
## 67, 6 pixels wide, outlined in black as Tk's canvas rectangles were.
##
## A click on the logo pauses or resumes (TogglePause); a click on the
## picture or a bar shows or hides the evaluation (ToggleEvaluationOf).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name DemandGauge
extends Control

signal logo_clicked
signal picture_clicked

const SIZE := Vector2(80, 55)
const BACKGROUND := Color("#bfbfbf")
const COLORS := [Color("#00ff00"), Color("#0000ff"), Color("#ffff00")]
const LOGO_AT := Vector2(0, 4)
const PICTURE_AT := Vector2(41, 4)
## Each bar's left and right edges (UISetDemand's canvas coordinates).
const BAR_X := [Vector2(49, 55), Vector2(58, 64), Vector2(67, 73)]
const DEMAND_TOP := 24
const SURPLUS_TOP := 32
const MAX_VALVE := 1500

var demand := Vector3i.ZERO:
	set(value):
		demand = value
		queue_redraw()
## The city running (the green logo) or stopped (the red one).
var running := false:
	set(value):
		running = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


## A valve as drawValve and SetDemand passed it: cut to +-1500, then
## hundreds, truncated.
static func bar_length(valve: int) -> int:
	return int(clampi(valve, -MAX_VALVE, MAX_VALVE) / 100.0)


## A bar's top and bottom y for a valve, as UISetDemand placed it: from 24 up
## for a demand, from 32 down for a surplus or none.
static func bar_span(valve: int) -> Vector2i:
	var length := bar_length(valve)
	var from := DEMAND_TOP if length > 0 else SURPLUS_TOP
	var to := from - length
	return Vector2i(mini(from, to), maxi(from, to))


## The logo's picture now: running or stopped.
func logo() -> String:
	return "micropolisg" if running else "micropoliss"


## What's at a point on the canvas: "logo", "picture" (or a bar), or "".
func part_at(point: Vector2) -> String:
	for i in 3:
		var span := bar_span(demand[i])
		if Rect2(BAR_X[i].x, span.x, BAR_X[i].y - BAR_X[i].x + 1, span.y - span.x + 1).has_point(point):
			return "picture"
	var logo_texture := Content.olpc_texture(logo())
	if logo_texture and Rect2(LOGO_AT, logo_texture.get_size()).has_point(point):
		return "logo"
	var picture := Content.olpc_texture("demandg")
	if picture and Rect2(PICTURE_AT, picture.get_size()).has_point(point):
		return "picture"
	return ""


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or not click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_RIGHT]:
		return
	match part_at(click.position):
		"logo":
			logo_clicked.emit()
			accept_event()
		"picture":
			picture_clicked.emit()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var picture := Content.olpc_texture("demandg")
	if picture:
		draw_texture(picture, PICTURE_AT)
	for i in 3:
		var span := bar_span(demand[i])
		var left: float = BAR_X[i].x
		var width: float = BAR_X[i].y - BAR_X[i].x
		if span.y > span.x:
			draw_rect(Rect2(left, span.x, width, span.y - span.x), COLORS[i])
		# Tk's outline, one pixel wide, around the rectangle's corners
		# inclusive: a line when the bar is empty.
		draw_rect(Rect2(left + 0.5, span.x + 0.5, width, span.y - span.x), Color.BLACK, false, 1.0)
	var logo_texture := Content.olpc_texture(logo())
	if logo_texture:
		draw_texture(logo_texture, LOGO_AT)
