## The engine's sprites over the city map: trains, helicopters, planes, ships,
## the monster, the tornado, explosions and buses, from the content's
## images/sprite_<type>_<frame - 1>.png (the OLPC art). Each is drawn as 1989's
## DrawSprite drew it: the frame's image at (x + x_offset, y + y_offset) in
## map pixels, in the engine's list order.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name SpriteLayer
extends Node2D

## The sprites last read from the engine (CityEngine.get_sprites).
var sprites: Array = []

var _engine: CityEngine

static var _frame_counts := {}


## How many frames the content has images for, for a CityEngine.SpriteType.
static func frame_count(type: int) -> int:
	if not _frame_counts.has(type):
		var count := 0
		while Content.has(_image_path(type, count + 1)):
			count += 1
		_frame_counts[type] = count
	return _frame_counts[type]


## A sprite's image for frame (from 1), or null.
static func texture(type: int, frame: int) -> Texture2D:
	return Content.texture(_image_path(type, frame))


## Draws sprites onto canvas, with the map's origin at `origin`.
static func draw_sprites(canvas: CanvasItem, list: Array, origin := Vector2.ZERO) -> void:
	for sprite: Dictionary in list:
		var image := texture(sprite.type, sprite.frame)
		if image != null:
			canvas.draw_texture(image, origin + Vector2(sprite.x + sprite.x_offset, sprite.y + sprite.y_offset))


## The middle of a sprite's image, in map pixels.
static func center_of(sprite: Dictionary) -> Vector2:
	return Vector2(sprite.x + sprite.x_offset + sprite.width / 2.0, sprite.y + sprite.y_offset + sprite.height / 2.0)


static func _image_path(type: int, frame: int) -> String:
	return "images/sprite_%d_%d.png" % [type, frame - 1]


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(engine: CityEngine) -> void:
	_engine = engine
	sync()


## Reads the sprites from the engine and redraws them.
func sync() -> void:
	sprites = _engine.get_sprites() if _engine != null else []
	queue_redraw()


## The first live sprite of a type, or {}.
func find(type: int) -> Dictionary:
	for sprite: Dictionary in sprites:
		if sprite.type == type:
			return sprite
	return {}


func _draw() -> void:
	draw_sprites(self, sprites)
