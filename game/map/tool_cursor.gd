## The editor's tool cursor over the hovered tile: a ghost of what the tool
## would build, and the 1989 cursor frame around its footprint (w_editor.c: a
## black-and-white bevel with a two-pixel band in the tool's colours, dashed
## when it has two).
##
## The chalk and the eraser have cursors of their own at the pointer (w_editor.c):
## a stick of chalk with its shadow, and an eraser with its shadow, both
## nearer their shadow while pressed; and while the view pans, 1989's pan cross
## shows instead. Those keep their size on screen at any zoom, as the OLPC's
## did at its one.
##
## It lives in the map's world, so one unit is one pixel of a tile at zoom 1.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name ToolCursor
extends Node2D

const GHOST_ALPHA := 0.5
const DASH := 4.0
## w_x.c's colours for the chalk and eraser cursors.
const MEDIUM_GRAY := Color("#7f7f7f")
const LIGHT_GRAY := Color("#bfbfbf")

var tool := CityEngine.Tool.BULLDOZER:
	set(value):
		tool = value
		queue_redraw()
## The hovered tile; the footprint is placed around it (Tools.footprint).
var tile := Vector2i.ZERO:
	set(value):
		if value != tile:
			tile = value
			queue_redraw()
## The size of the view's zoom, so the frame's lines stay at least a pixel.
var zoom := 1.0:
	set(value):
		zoom = value
		queue_redraw()

## The pointer, in map pixels; whether the tool is down; whether the view pans.
var pointer := Vector2.ZERO:
	set(value):
		if value != pointer:
			pointer = value
			if Tools.is_chalk(tool) or panning:
				queue_redraw()
var pressed := false:
	set(value):
		pressed = value
		queue_redraw()
var panning := false:
	set(value):
		panning = value
		queue_redraw()

var _engine: CityEngine
var _city_map: CityMap


func setup(engine: CityEngine, city_map: CityMap) -> void:
	_engine = engine
	_city_map = city_map


## The tiles the tool covers at the hovered tile.
func footprint() -> Rect2i:
	return Tools.footprint(tile, Tools.size(_engine, tool) if _engine else 1)


func _draw() -> void:
	if _engine == null:
		return
	if panning:
		_draw_pan_cross()
		return
	if tool == Tools.CHALK:
		_draw_chalk()
		return
	if tool == Tools.ERASER:
		_draw_eraser()
		return
	var area := footprint()
	var rect := Rect2(Vector2(area.position * CityMap.TILE_SIZE), Vector2(area.size * CityMap.TILE_SIZE))
	_draw_ghost(area)
	# One pixel of the original, but never thinner than a pixel on screen.
	var px := maxf(1.0, 1.0 / zoom)
	var r := rect.grow(px * 2.0)
	draw_rect(r.grow(px), Color.WHITE, false, px)
	draw_rect(Rect2(r.position + Vector2(px, px), r.size), Color.BLACK, false, px)
	var colors: Array = Tools.CURSOR_COLORS[tool]
	var band := rect.grow(px)
	if colors[0] == colors[1]:
		draw_rect(band, colors[0], false, 2.0 * px)
	else:
		_draw_dashed_rect(band, colors[0], colors[1], 2.0 * px, DASH * px)


func _draw_ghost(area: Rect2i) -> void:
	if not Tools.GHOST_TILES.has(tool) or _city_map.tile_set == null:
		return
	var atlas := _city_map.tile_set.get_source(CityMap.SOURCE_ID) as TileSetAtlasSource
	var base: int = Tools.GHOST_TILES[tool]
	for dy in area.size.y:
		for dx in area.size.x:
			var coords := _city_map.atlas_coords(base + dy * area.size.x + dx)
			var source := Rect2(Vector2(coords * CityMap.TILE_SIZE), Vector2(CityMap.TILE_SIZE, CityMap.TILE_SIZE))
			var at := Vector2((area.position + Vector2i(dx, dy)) * CityMap.TILE_SIZE)
			draw_texture_rect_region(atlas.texture, Rect2(at, source.size), source,
				Color(1, 1, 1, GHOST_ALPHA))


func _draw_dashed_rect(rect: Rect2, a: Color, b: Color, width: float, dash: float) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y), rect.position]
	for side in 4:
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[side + 1]
		var length := from.distance_to(to)
		var direction := (to - from) / length
		var along := 0.0
		var even := true
		while along < length:
			var end := minf(along + dash, length)
			draw_line(from + direction * along, from + direction * end, a if even else b, width)
			along = end
			even = not even


## A point offset from the pointer by screen pixels.
func _at(dx: float, dy: float) -> Vector2:
	return pointer + Vector2(dx, dy) / zoom


## A filled circle in the box XFillArc(x, y, w, h) fills, in screen pixels
## from the pointer.
func _arc(x: float, y: float, side: float, color: Color) -> void:
	draw_circle(_at(x + side / 2.0, y + side / 2.0), side / 2.0 / zoom, color)


## 1989's pan cross: an X and a +, black 3 pixels wide under white 1 wide.
func _draw_pan_cross() -> void:
	for pass_color: Array in [[Color.BLACK, 3.0], [Color.WHITE, 1.0]]:
		var width: float = pass_color[1] / zoom
		draw_line(_at(-6, -6), _at(6, 6), pass_color[0], width)
		draw_line(_at(-6, 6), _at(6, -6), pass_color[0], width)
		draw_line(_at(-8, 0), _at(8, 0), pass_color[0], width)
		draw_line(_at(0, 8), _at(0, -8), pass_color[0], width)


## The chalk: its shadow while up, then the stick, light gray and white,
## moved 2 pixels down-left onto the shadow while pressed.
func _draw_chalk() -> void:
	var offset := 2.0 if pressed else 0.0
	if not pressed:
		_arc(-8, 7, 7, MEDIUM_GRAY)
	_arc(-6 - offset, 5 + offset, 7, LIGHT_GRAY)
	draw_line(_at(13 - offset, -5 + offset), _at(-1 - offset, 9 + offset), LIGHT_GRAY, 3.0 / zoom)
	draw_line(_at(11 - offset, -7 + offset), _at(-3 - offset, 7 + offset), Color.WHITE, 3.0 / zoom)
	_arc(8 - offset, -9 + offset, 7, Color.WHITE)


## The eraser: its shadow while up, then a 16-pixel block bevelled light on
## the top and left and black on the bottom and right, moved onto the shadow
## while pressed.
func _draw_eraser() -> void:
	var offset := 0.0 if pressed else 2.0
	if not pressed:
		draw_rect(Rect2(_at(-8, -8), Vector2(16, 16) / zoom), MEDIUM_GRAY)
	var o := Vector2(offset, -offset)
	for i in 3:
		var d := float(i)
		draw_line(_at(-8 + d + o.x, -8 + d + o.y), _at(8 - d + o.x, -8 + d + o.y), LIGHT_GRAY, 1.0 / zoom)
		draw_line(_at(-8 + d + o.x, -8 + d + o.y), _at(-8 + d + o.x, 8 - d + o.y), LIGHT_GRAY, 1.0 / zoom)
		draw_line(_at(-7 + d + o.x, 7 - d + o.y), _at(8 - d + o.x, 7 - d + o.y), Color.BLACK, 1.0 / zoom)
		draw_line(_at(7 - d + o.x, 8 - d + o.y), _at(7 - d + o.x, -7 + d + o.y), Color.BLACK, 1.0 / zoom)
