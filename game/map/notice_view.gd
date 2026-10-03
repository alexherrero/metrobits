## The small view of the city in a notice, as the original's notice window had
## one (wnotice.tcl): centred on the place a message is about, or following the
## monster, the tornado or the traffic helicopter as 1989's FollowView did, at
## full size. It draws what the editor's map shows, tile for tile, frame for
## frame and sprite for sprite, so it follows the tile art and the animation
## without a map of its own. A click on it moves the editor there, as 1989's
## ComeToMe did.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name NoticeView
extends Control

## A click on the view: the tile at its centre.
signal clicked(tile: Vector2i)

const SIZE := Vector2(96, 96)

## The world point at the centre of the view, in map pixels.
var center := Vector2.ZERO
## The CityEngine.SpriteType it follows while one is live, or NONE.
var following := CityEngine.SpriteType.NONE

var _city_map: CityMap
var _sprites: SpriteLayer


func _init() -> void:
	clip_contents = true
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Go there"


## Draws from city_map and sprites, the editor's.
func setup(city_map: CityMap, sprites: SpriteLayer = null) -> void:
	_city_map = city_map
	_sprites = sprites


## Centres the view on a tile, and then follows a sprite of type `follow`
## while one is live.
func show_tile(tile: Vector2i, follow := CityEngine.SpriteType.NONE) -> void:
	center = (Vector2(tile) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE
	following = follow
	_follow()
	queue_redraw()


## The tile at the centre of the view.
func center_tile() -> Vector2i:
	return Vector2i((center / CityMap.TILE_SIZE).floor())


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_follow()
		queue_redraw()


func _follow() -> void:
	if following != CityEngine.SpriteType.NONE and _sprites != null:
		var sprite := _sprites.find(following)
		if not sprite.is_empty():
			center = SpriteLayer.center_of(sprite)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _city_map == null or _city_map.tile_set == null:
		return
	var atlas := _city_map.tile_set.get_source(CityMap.SOURCE_ID) as TileSetAtlasSource
	var origin := (size / 2.0 - center).round()
	var first := Vector2i((-origin / CityMap.TILE_SIZE).floor())
	var last := Vector2i(((size - origin) / CityMap.TILE_SIZE).ceil())
	for y in range(maxi(first.y, 0), mini(last.y, CityEngine.MAP_HEIGHT)):
		for x in range(maxi(first.x, 0), mini(last.x, CityEngine.MAP_WIDTH)):
			var tile := _city_map.shown_tile(x, y)
			if tile < 0:
				continue
			var source := atlas.get_tile_texture_region(_city_map.atlas_coords(tile))
			draw_texture_rect_region(atlas.texture, Rect2(origin + Vector2(x, y) * CityMap.TILE_SIZE,
				source.size), source)
	if _sprites != null:
		SpriteLayer.draw_sprites(self, _sprites.sprites, origin)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(center_tile())
		accept_event()
