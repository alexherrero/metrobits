## The whole city at three pixels a tile, as 1989's map view drew it (g_map.c,
## g_smmaps.c): the tiles in small (the OLPC's own hand-drawn 3x3 tiles,
## tilessm.xpm, with its art; each tile averaged to 3x3 with any other art),
## filtered to a kind of zone or to transport, or the power grid; or one of the
## overlays, stippled over the map in 1989's colours. The editor's view is a
## rectangle on it, which a drag moves (w_map.c's PanStart and PanTo).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name SmallMap
extends Control

## 1989's map states (sim.h's ALMAP to POMAP), in its numbering.
enum Mode {
	ALL, RESIDENTIAL, COMMERCIAL, INDUSTRIAL, POWER_GRID, TRANSPORTATION,
	POPULATION_DENSITY, RATE_OF_GROWTH, TRAFFIC_DENSITY, POLLUTION, CRIME, LAND_VALUE,
	FIRE_COVERAGE, POLICE_COVERAGE,
}
## 1989's map titles (micropolis.tcl's MapTitles), by Mode; 1989 spelled
## "Pollution Desity Map".
const TITLES := ["Micropolis Overall Map", "Residential Zone Map", "Commercial Zone Map",
	"Industrial Zone Map", "Power Grid Map", "Transportation Map", "Population Density Map",
	"Rate of Growth Map", "Traffic Density Map", "Pollution Desity Map", "Crime Rate Map",
	"Land Value Map", "Fire Coverage Map", "Police Coverage Map"]
## The engine's overlay for each overlay Mode.
const OVERLAYS := {
	Mode.POPULATION_DENSITY: CityEngine.Overlay.POPULATION_DENSITY,
	Mode.RATE_OF_GROWTH: CityEngine.Overlay.RATE_OF_GROWTH,
	Mode.TRAFFIC_DENSITY: CityEngine.Overlay.TRAFFIC_DENSITY,
	Mode.POLLUTION: CityEngine.Overlay.POLLUTION,
	Mode.CRIME: CityEngine.Overlay.CRIME,
	Mode.LAND_VALUE: CityEngine.Overlay.LAND_VALUE,
	Mode.FIRE_COVERAGE: CityEngine.Overlay.FIRE_COVERAGE,
	Mode.POLICE_COVERAGE: CityEngine.Overlay.POLICE_COVERAGE,
}
const SCALE := 3
## 1989's colours (w_x.c) for its values (g_map.c's valMap): none, low,
## medium, high, very high, plus, very plus, minus, very minus.
enum Value { NONE, LOW, MEDIUM, HIGH, VERY_HIGH, PLUS, VERY_PLUS, MINUS, VERY_MINUS }
const LIGHT_GRAY := Color("#bfbfbf")
const YELLOW := Color("#ffff00")
const ORANGE := Color("#ff7f00")
const RED := Color("#ff0000")
const DARK_GREEN := Color("#007f00")
const LIGHT_GREEN := Color("#00e600")
const LIGHT_BLUE := Color("#6666e6")
const VALUE_COLORS := [Color.TRANSPARENT, LIGHT_GRAY, YELLOW, ORANGE, RED, DARK_GREEN, LIGHT_GREEN, ORANGE, YELLOW]
## The power grid's colours (g_smmaps.c): a zone powered, unpowered, and
## anything that conducts; drawn as extra tiles after the art's.
const POWERED := RED
const UNPOWERED := LIGHT_BLUE
const CONDUCTIVE := LIGHT_GRAY
## How far outside the view's rectangle a press still grabs it (w_map.c).
const GRAB_MARGIN := 4.0

## The editor whose view it shows and moves.
var editor: MapView
var mode := Mode.ALL
## The tile layer of small tiles, and the overlay's stipple over it.
var tiles: TileMapLayer
var overlay: OverlayLayer
## The editor's chalk, drawn small (DrawMapInk).
var ink: InkLayer
var frame: ViewFrame

var _engine: CityEngine
var _small: Image
## Per cell: the engine's value last seen, and the small tile drawn.
var _seen := PackedInt32Array()
var _drawn := PackedInt32Array()
var _power_tile := 960
var _grabbed := false
## An earthquake's shake, which moves the map the other way (w_map.c).
var shake := Shake.new()

static var _small_cache := {}
static var _olpc_small: Image


## 1989's GetCI: a density, rate or value (0 to 255) as none to very high.
static func level(value: int) -> Value:
	if value < 50:
		return Value.NONE
	if value < 100:
		return Value.LOW
	if value < 150:
		return Value.MEDIUM
	if value < 200:
		return Value.HIGH
	return Value.VERY_HIGH


## An overlay's value in 1989's classes, as g_map.c drew each.
static func classify(overlay_mode: Mode, value: int) -> Value:
	match overlay_mode:
		Mode.RATE_OF_GROWTH:
			if value > 100:
				return Value.VERY_PLUS
			if value > 20:
				return Value.PLUS
			if value < -100:
				return Value.VERY_MINUS
			if value < -20:
				return Value.MINUS
			return Value.NONE
		Mode.POLLUTION:
			return level(10 + value)
	return level(value)


## The tile a zone or transport map shows for a tile (0, bare land, hides it),
## as g_smmaps.c's drawRes, drawCom, drawInd and drawLilTransMap filtered.
static func filtered_tile(filter: Mode, tile: int) -> int:
	match filter:
		Mode.RESIDENTIAL:
			return 0 if tile > 422 else tile
		Mode.COMMERCIAL:
			return 0 if tile > 609 or (tile >= 232 and tile < 423) else tile
		Mode.INDUSTRIAL:
			var hidden := (tile >= 240 and tile <= 611) or (tile >= 693 and tile <= 851) \
				or (tile >= 860 and tile <= 883) or tile >= 932
			return 0 if hidden else tile
		Mode.TRANSPORTATION, Mode.TRAFFIC_DENSITY:
			return 0 if tile >= 240 or (tile >= 207 and tile <= 220) or tile == 223 else tile
	return tile


## The small tiles for tile art: the OLPC's own (tilessm.xpm) for the OLPC
## art, which the OLPC's map drew with; averaged from any other art, which
## only tests give it now.
static func small_tiles_for(art: Image) -> Image:
	if art == CityMap.load_tiles():
		return olpc_small_tiles()
	return small_tiles(art)


## The OLPC's small tiles, from tilessm.xpm (g_setup.c): 4 pixels wide, a
## tile every 3 rows, of which the first 3 columns show; laid out 16 to a row,
## then the power grid's three colours, as small_tiles lays them out.
static func olpc_small_tiles() -> Image:
	if _olpc_small != null:
		return _olpc_small
	var source := Content.olpc_image("tilessm")
	var count := source.get_height() / SCALE
	var rows := ceili((count + 3) / 16.0)
	_olpc_small = Image.create_empty(16 * SCALE, rows * SCALE, false, Image.FORMAT_RGBA8)
	for tile in count:
		_olpc_small.blit_rect(source, Rect2i(0, tile * SCALE, SCALE, SCALE), _small_at(tile))
	for i in 3:
		_olpc_small.fill_rect(Rect2i(_small_at(count + i), Vector2i(SCALE, SCALE)), [POWERED, UNPOWERED, CONDUCTIVE][i])
	return _olpc_small


## Small tiles for tile art: each 16-pixel tile averaged to 3x3, 16 to a row,
## then the power grid's three colours; cached per art.
static func small_tiles(art: Image) -> Image:
	var key := art.get_instance_id()
	if _small_cache.has(key):
		return _small_cache[key]
	var columns := art.get_width() / CityMap.TILE_SIZE
	var count := columns * (art.get_height() / CityMap.TILE_SIZE)
	var rows := ceili((count + 3) / 16.0)
	var small := Image.create_empty(16 * SCALE, rows * SCALE, false, Image.FORMAT_RGBA8)
	var source := art.duplicate() as Image
	source.convert(Image.FORMAT_RGBA8)
	for tile in count:
		var region := source.get_region(Rect2i((tile % columns) * CityMap.TILE_SIZE,
			(tile / columns) * CityMap.TILE_SIZE, CityMap.TILE_SIZE, CityMap.TILE_SIZE))
		# 16 to 4 by two exact 2x2 averages, then 4 to 3.
		region.shrink_x2()
		region.shrink_x2()
		region.resize(SCALE, SCALE, Image.INTERPOLATE_BILINEAR)
		small.blit_rect(region, Rect2i(0, 0, SCALE, SCALE), _small_at(tile))
	for i in 3:
		small.fill_rect(Rect2i(_small_at(count + i), Vector2i(SCALE, SCALE)), [POWERED, UNPOWERED, CONDUCTIVE][i])
	_small_cache[key] = small
	return small


static func _small_at(tile: int) -> Vector2i:
	return Vector2i(tile % 16, tile / 16) * SCALE


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(CityEngine.MAP_WIDTH, CityEngine.MAP_HEIGHT) * SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	add_child(tiles)
	overlay = OverlayLayer.new()
	overlay.name = "Overlay"
	add_child(overlay)
	ink = InkLayer.new()
	ink.name = "Ink"
	add_child(ink)
	frame = ViewFrame.new()
	frame.name = "ViewFrame"
	add_child(frame)


func setup(engine: CityEngine, art: Image, view: MapView) -> void:
	_engine = engine
	editor = view
	frame.small_map = self
	if view != null:
		ink.source = view.chalk
	set_art(art)


## Draws with other tile art from now on.
func set_art(art: Image) -> void:
	_small = small_tiles_for(art)
	_power_tile = (art.get_width() / CityMap.TILE_SIZE) * (art.get_height() / CityMap.TILE_SIZE)
	tiles.tile_set = CityMap.make_tile_set(_small, SCALE)
	_seen = PackedInt32Array()
	refresh()


## Shows another of 1989's maps.
func set_mode(value: Mode) -> void:
	mode = value
	_seen = PackedInt32Array()
	refresh()


## Redraws what changed in the engine's map and the overlay's data.
func refresh() -> void:
	if _engine == null:
		return
	var map := _engine.get_map()
	if _seen.size() != map.size():
		_seen.resize(map.size())
		_seen.fill(-1)
		_drawn.resize(map.size())
		_drawn.fill(-1)
	if map != _seen:
		var base := Mode.TRANSPORTATION if mode == Mode.TRAFFIC_DENSITY else mode
		for i in map.size():
			var value := map[i]
			if value == _seen[i]:
				continue
			_seen[i] = value
			var tile := _small_tile(base, value)
			if tile != _drawn[i]:
				_drawn[i] = tile
				tiles.set_cell(Vector2i(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH), 0,
					Vector2i(tile % 16, tile / 16))
	overlay.show_values(self)
	frame.queue_redraw()


## The small tile drawn for a map value in a mode.
func _small_tile(base: Mode, value: int) -> int:
	var tile := value & CityEngine.TILE_INDEX_MASK
	if base == Mode.POWER_GRID:
		if tile <= 63:
			return tile
		if value & CityEngine.TILE_ZONE_BIT:
			return _power_tile + (0 if value & CityEngine.TILE_POWERED_BIT else 1)
		return _power_tile + 2 if value & CityEngine.TILE_CONDUCTIVE_BIT else 0
	if base in [Mode.RESIDENTIAL, Mode.COMMERCIAL, Mode.INDUSTRIAL, Mode.TRANSPORTATION]:
		return filtered_tile(base, tile)
	return tile if tile < _power_tile else 0


## The small tile a map cell shows now.
func drawn_tile(x: int, y: int) -> int:
	return _drawn[y * CityEngine.MAP_WIDTH + x]


## The editor's view, in this map's pixels, as w_map.c scaled it (3/16).
func view_rect() -> Rect2:
	if editor == null:
		return Rect2()
	var world := editor.visible_world_rect()
	var ratio := float(SCALE) / CityMap.TILE_SIZE
	return Rect2((world.position * ratio).floor(), (world.size * ratio).floor())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if event.pressed:
			# 1989 dragged the editor only from on or near its rectangle.
			_grabbed = view_rect().grow(GRAB_MARGIN).has_point(event.position)
		else:
			_grabbed = false
		accept_event()
	elif event is InputEventMouseMotion and _grabbed:
		drag_view(event.relative)
		accept_event()


## Moves the editor as a drag of its rectangle by `delta` map pixels does:
## 16/3 world pixels for each.
func drag_view(delta: Vector2) -> void:
	if editor == null:
		return
	editor.camera_position += delta * CityMap.TILE_SIZE / SCALE
	frame.queue_redraw()


func _process(delta: float) -> void:
	if shake.is_shaking() or shake.offset != Vector2.ZERO:
		var offset := -shake.step(delta)
		tiles.position = offset
		overlay.position = offset
		ink.position = offset
	if is_visible_in_tree():
		frame.queue_redraw()


## The overlay: each block of the engine's overlay whose value shows, in its
## colour on every other pixel (g_map.c's maybeDrawRect: a checkerboard over
## the map, on the pixels where x + y is odd).
class OverlayLayer:
	extends Node2D

	## Blocks drawn at the last refresh: {rect, value}.
	var blocks: Array[Dictionary] = []

	var _stipple: Texture2D

	func _init() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
		image.set_pixel(1, 0, Color.WHITE)
		image.set_pixel(0, 1, Color.WHITE)
		_stipple = ImageTexture.create_from_image(image)

	func show_values(map: SmallMap) -> void:
		blocks.clear()
		if SmallMap.OVERLAYS.has(map.mode):
			var which: int = SmallMap.OVERLAYS[map.mode]
			var data := map._engine.get_overlay(which)
			var size := map._engine.get_overlay_size(which)
			# Square blocks: 6 pixels for the half-size maps, 24 for the
			# eighth-size ones, whose last row runs off the map's foot.
			var side := float(CityEngine.MAP_WIDTH * SmallMap.SCALE / size.x)
			var block := Vector2(side, side)
			for i in data.size():
				var value := SmallMap.classify(map.mode, data[i])
				if value != SmallMap.Value.NONE:
					blocks.append({rect = Rect2(Vector2(i % size.x, i / size.x) * block, block), value = value})
		queue_redraw()

	func _draw() -> void:
		for block in blocks:
			draw_texture_rect(_stipple, block.rect, true, SmallMap.VALUE_COLORS[block.value])


## The editor's chalk on the map, always (w_map.c's DrawMapInk): each stroke
## at 3/16 of its size, one pixel wide, in white.
class InkLayer:
	extends Node2D

	var source: ChalkLayer:
		set(value):
			source = value
			if source != null and not source.changed.is_connected(queue_redraw):
				source.changed.connect(queue_redraw)
			queue_redraw()

	func _draw() -> void:
		if source == null:
			return
		var ratio := float(SmallMap.SCALE) / CityMap.TILE_SIZE
		for stroke in source.strokes:
			if stroke.size() == 1:
				draw_rect(Rect2((stroke[0] * ratio).floor(), Vector2.ONE), ChalkLayer.COLOR)
			else:
				var small := PackedVector2Array()
				for point in stroke:
					small.append((point * ratio).floor() + Vector2(0.5, 0.5))
				draw_polyline(small, ChalkLayer.COLOR, 1.0)


## The editor's view on the map: 1989's three one-pixel rectangles, white,
## yellow and black, each three pixels bigger than the view (w_map.c's
## DrawMapEditorViews).
class ViewFrame:
	extends Node2D

	var small_map: SmallMap

	func _draw() -> void:
		if small_map == null or small_map.editor == null:
			return
		var view := small_map.view_rect()
		for ring: Array in [[3, Color.WHITE], [2, SmallMap.YELLOW], [1, Color.BLACK]]:
			var at: float = ring[0]
			draw_rect(Rect2(view.position - Vector2(at, at) + Vector2(0.5, 0.5), view.size + Vector2(3, 3)),
				ring[1], false, 1.0)
