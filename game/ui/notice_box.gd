## The original's notice window (wnotice.tcl), which showed one notice at a
## time in the head window: a title bar in the notice's colour, the text, a
## small view of the place it's about beside the text when it has one, and a
## Dismiss button. A new notice replaces the one showing. Alerts and the Query
## tool's zone report are both notices, as they were in 1989. A notice can
## have a picture at the foot of its text, a button (the win notice's key to
## the city, wnotice.tcl's middle button).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name NoticeBox
extends PanelContainer

signal closed
## The notice's picture was clicked.
signal picture_clicked

## For a notice with no place.
const NOWHERE := Vector2i(-1, -1)

var title_label: Label
var text_label: Label
var dismiss_button: Button
var view: NoticeView
## The notice's picture, under its text; hidden when it has none.
var picture: TextureButton
## The text's room, which clips a text longer than it (as a Tk text widget did).
var text_scroll: ScrollContainer
## The place the notice is about, or NOWHERE.
var place := NOWHERE

var _title_bar: PanelContainer


func _init() -> void:
	add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 2))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_title_bar = PanelContainer.new()
	column.add_child(_title_bar)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# wnotice.tcl: the title in Big, on a raised 2-pixel border. The text is
	# in Medium: wnotice.tcl made it Large, but every notice came through
	# UIShowPictureOn, which set it to Medium (NoticeMessageOn).
	title_label.add_theme_font_size_override("font_size", ClassicTheme.BIG)
	_title_bar.add_child(title_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	margin.add_child(body)
	# wnotice.tcl packed the notice to fill the space under the map (expand
	# fill): the title on top, Dismiss at the foot, and the text between,
	# clipped when it's longer than the room.
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(margin)
	var view_frame := PanelContainer.new()
	view_frame.add_theme_stylebox_override("panel", ClassicTheme.box(false, Color.BLACK, 1))
	view_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(view_frame)
	view = NoticeView.new()
	view_frame.add_child(view)
	view_frame.visible = false
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size.x = 120
	text_label.add_theme_font_size_override("font_size", ClassicTheme.MEDIUM)
	text_scroll = ScrollContainer.new()
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	text_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(text_scroll)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.add_child(text_column)
	text_column.add_child(text_label)
	picture = TextureButton.new()
	picture.name = "Picture"
	picture.focus_mode = Control.FOCUS_NONE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.visible = false
	picture.pressed.connect(func() -> void: picture_clicked.emit())
	text_column.add_child(picture)
	dismiss_button = Button.new()
	dismiss_button.text = "Dismiss"
	dismiss_button.focus_mode = Control.FOCUS_NONE
	dismiss_button.pressed.connect(dismiss)
	column.add_child(dismiss_button)
	visible = false


## Shows a notice in place of the one showing, with a view of `at` if it's on
## the map, which follows a sprite of type `follow` while one is live.
func show_notice(title: String, color: Color, text: String, at := NOWHERE,
		follow := CityEngine.SpriteType.NONE) -> void:
	title_label.text = title
	_title_bar.add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.RAISED, color, 2, 2))
	text_label.text = text
	text_scroll.scroll_vertical = 0
	picture.visible = false
	place = at if at.x >= 0 and at.y >= 0 else NOWHERE
	view.get_parent().visible = place != NOWHERE
	if place != NOWHERE:
		view.show_tile(place, follow)
	visible = true


## The title bar's colour: the notice's.
func title_bar_color() -> Color:
	var bar := _title_bar.get_theme_stylebox("panel") as TkBorder
	return bar.background if bar != null else Color.TRANSPARENT


## A picture under the notice's text, which can be clicked.
func show_picture(texture: Texture2D) -> void:
	picture.texture_normal = texture
	picture.visible = texture != null


func dismiss() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
