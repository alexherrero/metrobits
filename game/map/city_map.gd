## The city's 120x100 tile map, drawn with the original's tiles.
##
## It mirrors the engine's map. sync() redraws only the cells whose tile value
## changed, and animate() steps the animated tiles (fire, traffic, smoke, radar,
## the nuclear swirl...) one frame along the engine's own animation table. The
## 1989 front end animated by rewriting the engine's map as it drew; this does
## it in the view only, so the simulation never depends on the frame rate.
##
## A zone's centre with no power blinks a lightning bolt, as 1989's editor drew
## it (g_bigmap.c): the bolt shows through the second half of each second of
## the clock (sim_update's flagBlink), checked each time the city is redrawn.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name CityMap
extends TileMapLayer

const TILE_SIZE := 16
## The tile art: the Unix and OLPC art, brown ground, 16 tiles to a row. The
## Windows edition's Classic art isn't included: it's retail art the GPL
## doesn't cover.
const TILES := "images/tiles.png"
## animate() steps at most this many frames at once; past a few frames per
## redraw, the ones between aren't seen.
const MAX_ANIMATION_STEPS := 8
const SOURCE_ID := 0
## The tile a zone's centre with no power blinks to (LIGHTNINGBOLT).
const LIGHTNING_BOLT := 827

## The tile art in use.
var tiles: Image
## How many animation frames animate() has stepped, in all.
var frames_stepped := 0

var _engine: CityEngine
var _columns := 1
var _tile_count := 0
var _next_frame := PackedInt32Array()
## Per cell, row-major: the engine's last value (with flags), and the tile drawn.
var _seen := PackedInt32Array()
var _shown := PackedInt32Array()
## The cells whose tile animates, rebuilt when that set changes.
var _animated := PackedInt32Array()
var _animated_dirty := true
## Whether the bolts show now, and the zone centres without power.
var blinking := false
var _unpowered := PackedInt32Array()
var _unpowered_dirty := true

static var _tiles: Image


## A TileSet with one atlas of tiles `size` pixels square cut from image, row
## by row.
static func make_tile_set(image: Image, size := TILE_SIZE) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(size, size)
	var grid := atlas.get_atlas_grid_size()
	for y in grid.y:
		for x in grid.x:
			atlas.create_tile(Vector2i(x, y))
	tile_set.add_source(atlas, SOURCE_ID)
	return tile_set


## The tile art, loaded once. Nothing changes the image.
static func load_tiles() -> Image:
	if _tiles == null:
		_tiles = Content.load_image(TILES)
	return _tiles


## Draws engine's city from the tiles in image (default: the tile art).
func setup(engine: CityEngine, image: Image = null) -> void:
	_engine = engine
	_next_frame = engine.get_animation_table()
	set_tiles(image if image != null else load_tiles())


## Draws with other tile art from now on, redrawing every cell.
func set_tiles(image: Image) -> void:
	tiles = image
	tile_set = make_tile_set(image)
	_columns = image.get_width() / TILE_SIZE
	_tile_count = _columns * (image.get_height() / TILE_SIZE)
	if _engine != null:
		reset()


## Forgets what's drawn and redraws every cell (after a load).
func reset() -> void:
	var cells := CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT
	_seen.resize(cells)
	_seen.fill(-1)
	_shown.resize(cells)
	_shown.fill(-1)
	_animated_dirty = true
	_unpowered.clear()
	_unpowered_dirty = true
	sync()


## Redraws the cells whose tile changed in the engine. Returns how many.
func sync() -> int:
	var map := _engine.get_map()
	if map == _seen:
		return 0
	var changed := 0
	for i in map.size():
		var value := map[i]
		var old := _seen[i]
		if value == old:
			continue
		_seen[i] = value
		if old < 0 or (value ^ old) & CityEngine.TILE_ANIM_BIT:
			_animated_dirty = true
		if old < 0 or (value ^ old) & (CityEngine.TILE_ZONE_BIT | CityEngine.TILE_POWERED_BIT):
			_unpowered_dirty = true
		_draw_cell(i, value & CityEngine.TILE_INDEX_MASK)
		changed += 1
	if changed > 0 and blinking:
		set_blinking(true)
		_show_bolts()
	return changed


## Shows or hides the bolts on zone centres without power (1989's blink).
func set_blinking(on: bool) -> void:
	if on == blinking and not _unpowered_dirty:
		return
	blinking = on
	# Put back the tiles under the last bolts, then find the zones afresh.
	for i in _unpowered:
		_set_atlas_cell(i, _shown[i])
	if _unpowered_dirty:
		_unpowered.clear()
		for i in _seen.size():
			var value := _seen[i]
			if value >= 0 and value & CityEngine.TILE_ZONE_BIT and not value & CityEngine.TILE_POWERED_BIT:
				_unpowered.append(i)
		_unpowered_dirty = false
	if blinking:
		_show_bolts()


## 1989's blink phase at a time in milliseconds: on through the second half
## of each second.
static func blink_phase(msec: int) -> bool:
	return msec % 1000 >= 500


## The zone centres without power, row-major cell indices.
func unpowered_zones() -> PackedInt32Array:
	if _unpowered_dirty:
		set_blinking(blinking)
	return _unpowered


## The tile a cell shows on screen now: a bolt, or its own.
func drawn_tile(x: int, y: int) -> int:
	return get_cell_atlas_coords(Vector2i(x, y)).y * _columns + get_cell_atlas_coords(Vector2i(x, y)).x


func _show_bolts() -> void:
	for i in _unpowered:
		_set_atlas_cell(i, LIGHTNING_BOLT)


func _set_atlas_cell(i: int, tile: int) -> void:
	set_cell(Vector2i(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH), SOURCE_ID, atlas_coords(tile))


## Moves every animated tile on by `steps` frames (1989 stepped them once per
## loop). Returns how many changed.
func animate(steps := 1) -> int:
	if _animated_dirty:
		_animated.clear()
		for i in _seen.size():
			if _seen[i] >= 0 and _seen[i] & CityEngine.TILE_ANIM_BIT:
				_animated.append(i)
		_animated_dirty = false
	frames_stepped += steps
	var changed := 0
	for i in _animated:
		var next := _shown[i]
		for step in steps:
			next = _next_frame[next]
		if next != _shown[i]:
			_draw_cell(i, next)
			changed += 1
	if changed > 0 and blinking:
		_show_bolts()
	return changed


## The tile index drawn at a cell.
func shown_tile(x: int, y: int) -> int:
	return _shown[y * CityEngine.MAP_WIDTH + x]


## The atlas cell that shows a tile index. Tiles past the art's end (the
## engine's extended church zones, 956 to 1018) show as bare dirt.
func atlas_coords(tile: int) -> Vector2i:
	if tile < 0 or tile >= _tile_count:
		tile = 0
	return Vector2i(tile % _columns, tile / _columns)


func _draw_cell(i: int, tile: int) -> void:
	_shown[i] = tile
	set_cell(Vector2i(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH), SOURCE_ID, atlas_coords(tile))
