## The chalk overlay: the OLPC's Chalk draws white lines over the map, and its
## Eraser rubs them out (w_tool.c's ChalkTool and EraserTool, w_x.c's ink).
## Only the front end has it; the engine never sees it.
##
## - Chalk: a press starts a stroke at the chalk's tip, 5 pixels left of and
##   11 below the pointer (ChalkTool's x - 5, y + 11), and every move of the
##   pointer while it's down adds a point (ChalkTo).
## - Eraser: a press, and every move while it's down, removes each whole
##   stroke that comes within the 16-pixel square around the pointer
##   (EraserTo and InkInBox: a stroke goes if any of its segments' bounding
##   boxes meets the square).
## - The editor draws the strokes 3 pixels wide in white, a single point as a
##   dot 6 pixels across (DrawTheOverlay), when its Chalk Overlay option is
##   on; the map window always draws them (DrawMapInk).
## - A new city starts with none (UINewGame's sim EraseOverlay).
##
## It lives in the map's world, so its units are the map's pixels.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name ChalkLayer
extends Node2D

## The strokes changed.
signal changed

const COLOR := Color.WHITE
const LINE_WIDTH := 3.0
const DOT_RADIUS := 3.0
## Where the chalk's tip is from the pointer.
const TIP := Vector2(-5, 11)
## Half the eraser's square.
const ERASER_REACH := 8.0

## Every stroke, oldest first, each the points it passed through.
var strokes: Array[PackedVector2Array] = []
## The editor's Chalk Overlay option (view->show_overlay, on from the start).
var shown := true:
	set(value):
		shown = value
		queue_redraw()


## A new stroke at a point on the map (ChalkStart).
func start(point: Vector2) -> void:
	strokes.append(PackedVector2Array([point]))
	_changed()


## The stroke goes on to a point (ChalkTo, AddInk: a point where the last one
## is adds nothing).
func add(point: Vector2) -> void:
	if strokes.is_empty():
		start(point)
		return
	var stroke := strokes[-1]
	if stroke[-1] == point:
		return
	stroke.append(point)
	strokes[-1] = stroke
	_changed()


## Removes every stroke within the eraser's square around a point. Returns
## how many went.
func erase_at(point: Vector2) -> int:
	var box := Rect2(point - Vector2(ERASER_REACH, ERASER_REACH), Vector2(ERASER_REACH, ERASER_REACH) * 2.0)
	var kept: Array[PackedVector2Array] = []
	for stroke in strokes:
		if not touches(stroke, box):
			kept.append(stroke)
	var erased := strokes.size() - kept.size()
	if erased > 0:
		strokes = kept
		_changed()
	return erased


## Whether a stroke comes within a box, as InkInBox tested it: its bounds
## first, then each segment's.
static func touches(stroke: PackedVector2Array, box: Rect2) -> bool:
	var bounds := Rect2(stroke[0], Vector2.ZERO)
	for point in stroke:
		bounds = bounds.expand(point)
	if not _meets(bounds, box):
		return false
	if stroke.size() == 1:
		return true
	for i in range(1, stroke.size()):
		if _meets(Rect2(stroke[i - 1], Vector2.ZERO).expand(stroke[i]), box):
			return true
	return false


## Inclusive overlap, as the OLPC's integer comparisons were.
static func _meets(a: Rect2, b: Rect2) -> bool:
	return b.position.x <= a.end.x and b.end.x >= a.position.x and b.position.y <= a.end.y \
		and b.end.y >= a.position.y


## Rubs out everything (sim EraseOverlay).
func clear() -> void:
	if strokes.is_empty():
		return
	strokes.clear()
	_changed()


func _changed() -> void:
	queue_redraw()
	changed.emit()


func _draw() -> void:
	if not shown:
		return
	for stroke in strokes:
		if stroke.size() == 1:
			draw_circle(stroke[0], DOT_RADIUS, COLOR)
		else:
			draw_polyline(stroke, COLOR, LINE_WIDTH)
