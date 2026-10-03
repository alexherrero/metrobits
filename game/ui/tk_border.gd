## A Tk 3-D border, as the OLPC's Tk drew one (tk3d.c): the background, then
## a bevel `width` pixels wide. Tk_Draw3DRectangle filled the bottom and right
## strips in one shade, then the top and left as one polygon, mitred at the
## two corners where they meet, in the other: light on top when raised, dark
## on top when sunken. Tk worked both shades out from the background: 1.4
## times it for the light one, capped at white, and 0.6 times for the dark.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name TkBorder
extends StyleBox

enum Relief { FLAT, RAISED, SUNKEN }

var background := Color("#b0b0b0")
var relief := Relief.RAISED
var width := 1


## Tk's illuminated shade of a background.
static func light(of: Color) -> Color:
	return Color(minf(of.r * 1.4, 1.0), minf(of.g * 1.4, 1.0), minf(of.b * 1.4, 1.0), of.a)


## Tk's shaded shade of a background.
static func dark(of: Color) -> Color:
	return Color(of.r * 0.6, of.g * 0.6, of.b * 0.6, of.a)


static func make(border_relief: Relief, border_background: Color, border_width := 1, padding := 4) -> TkBorder:
	var border := TkBorder.new()
	border.relief = border_relief
	border.background = border_background
	border.width = border_width
	border.set_content_margin_all(padding + (border_width if border_relief != Relief.FLAT else 0))
	return border


## The shade of the top and left edges, and of the bottom and right.
func shades() -> Array[Color]:
	if relief == Relief.SUNKEN:
		return [dark(background), light(background)]
	return [light(background), dark(background)]


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, background)
	if relief == Relief.FLAT or width <= 0:
		return
	var w := float(mini(width, floori(minf(rect.size.x, rect.size.y) / 2.0)))
	var top_left: Color = shades()[0]
	var bottom_right: Color = shades()[1]
	var p := rect.position
	var e := rect.end
	RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(p.x, e.y - w, rect.size.x, w), bottom_right)
	RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(e.x - w, p.y, w, rect.size.y), bottom_right)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([
		Vector2(p.x, e.y), p, Vector2(e.x, p.y), Vector2(e.x - w, p.y + w), Vector2(p.x + w, p.y + w),
		Vector2(p.x + w, e.y - w)]), PackedColorArray([top_left]))
