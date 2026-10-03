## The original's tool palette: the selected tool's name and cost on top, and
## the icons where the 1989 editor placed them, each showing its highlighted
## version (ic*hi.png) when selected.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Palette
extends PanelContainer

signal tool_selected(tool: int)

const WIDTH := 130
const ICON_SIZE := 34

var name_label: Label
var cost_label: Label
var buttons := {}
var selected := -1

var _engine: CityEngine
var _icons := {}


func _init() -> void:
	custom_minimum_size.x = WIDTH
	var area := Control.new()
	area.name = "Area"
	add_child(area)
	name_label = _label(area, 2)
	cost_label = _label(area, 22)


func setup(engine: CityEngine, tiles: Image) -> void:
	_engine = engine
	var area := get_node("Area")
	for entry: Array in Tools.PALETTE:
		var tool: int = entry[0]
		_icons[tool] = _load_icons(tool, tiles)
		var button := TextureButton.new()
		button.name = Tools.NAMES[tool].replace(" ", "")
		button.texture_normal = _icons[tool][0]
		button.position = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		var key := Tools.key_for(tool)
		button.tooltip_text = ("%s (%s): %s" % [Tools.NAMES[tool], OS.get_keycode_string(key),
			Tools.cost_label(Tools.cost(engine, tool))] if key != KEY_NONE
			else "%s: %s" % [Tools.NAMES[tool], Tools.cost_label(Tools.cost(engine, tool))])
		button.pressed.connect(func() -> void:
			select(tool)
			tool_selected.emit(tool))
		area.add_child(button)
		buttons[tool] = button
	area.custom_minimum_size.y = Tools.PALETTE[-1][1].y + ICON_SIZE + 4


## Redraws the icons made from tiles (the tools the original had no icon for)
## from other tile art.
func set_tiles(tiles: Image) -> void:
	for tool: int in buttons:
		if not Tools.ICONS.has(tool):
			_icons[tool] = _load_icons(tool, tiles)
			buttons[tool].texture_normal = _icons[tool][1 if tool == selected else 0]


## Shows tool as selected: its highlighted icon, name and cost.
func select(tool: int) -> void:
	if selected in buttons:
		buttons[selected].texture_normal = _icons[selected][0]
	selected = tool
	buttons[tool].texture_normal = _icons[tool][1]
	name_label.text = Tools.NAMES[tool]
	cost_label.text = Tools.cost_label(Tools.cost(_engine, tool))


## The normal and highlighted icons: the original's, or for a tool without
## one, its tile in the originals' style (a dithered well, white when selected).
static func _load_icons(tool: int, tiles: Image) -> Array[Texture2D]:
	if Tools.ICONS.has(tool):
		var icon: String = Tools.ICONS[tool]
		return [icon_texture(icon), icon_texture(icon + "hi")]
	return [ImageTexture.create_from_image(tile_icon(tiles, Tools.ICON_TILES[tool], false)),
		ImageTexture.create_from_image(tile_icon(tiles, Tools.ICON_TILES[tool], true))]


## A tool's picture: the OLPC's own XPM where micropolis-core/olpc has it (the
## Road icons: MicropolisCore's PNGs give them a white ground where the OLPC's
## is grey), else MicropolisCore's PNG, the same pixels.
static func icon_texture(icon_name: String) -> Texture2D:
	if FileAccess.file_exists(Content.olpc_path("images/%s.xpm" % icon_name)):
		return Content.olpc_texture(icon_name)
	return Content.texture("images/%s.png" % icon_name)


## A 34-pixel icon: a gray frame, a black edge, a dithered (or, selected,
## white) well, and the tile in the middle.
static func tile_icon(tiles: Image, tile: int, highlighted: bool) -> Image:
	var icon := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	icon.fill(Color("#7f7f7f"))
	icon.fill_rect(Rect2i(2, 2, 30, 30), Color.BLACK)
	for y in range(3, 31):
		for x in range(3, 31):
			var white := highlighted or (x + y) % 2 == 0
			icon.set_pixel(x, y, Color.WHITE if white else Color.BLACK)
	var columns := tiles.get_width() / CityMap.TILE_SIZE
	var source := Rect2i(Vector2i(tile % columns, tile / columns) * CityMap.TILE_SIZE,
		Vector2i(CityMap.TILE_SIZE, CityMap.TILE_SIZE))
	var converted := tiles.duplicate() as Image
	converted.convert(Image.FORMAT_RGBA8)
	icon.fill_rect(Rect2i(8, 8, 18, 18), Color.BLACK)
	icon.blit_rect(converted, source, Vector2i(9, 9))
	return icon


func _label(parent: Control, y: float) -> Label:
	var label := Label.new()
	label.position = Vector2(0, y)
	label.size = Vector2(WIDTH - 8, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	return label
