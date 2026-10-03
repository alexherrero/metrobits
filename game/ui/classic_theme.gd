## The look of the OLPC's Tk front end, from micropolis.tcl's option
## database and Tk's own defaults (micropolis-activity's src/tk): everything
## on #b0b0b0 (*background), #d0d0d0 under the pointer (*activeBackground),
## black text, and Tk's 3-D borders (TkBorder): 2 pixels on buttons and menus,
## sunken entries and lists. The font is the OLPC's DejaVu LGC Sans at
## FontInfo's sizes, which its fonts.alias doubled for the XO's screen: Big 9
## points (18 pixels), Large 8 (16), Medium 7 (14), and Small, Narrow and Tiny
## 6 (12). Text, Message and Alert were Medium's size.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name ClassicTheme
extends RefCounted

const BACKGROUND := Color("#b0b0b0")
const ACTIVE := Color("#d0d0d0")
## Tk's shades of the background: 1.4 and 0.6 times it (tk3d.c).
const LIGHT := Color("#f6f6f6")
const SHADOW := Color("#6a6a6a")
const TEXT := Color.BLACK
const BIG := 18
const LARGE := 16
const MEDIUM := 14
const SMALL := 12
const FONT_SIZE := MEDIUM
## Tk's default border width for buttons, menus, menubuttons and entries.
const TK_BORDER := 2


## A Tk frame's border, one pixel wide: raised or sunken.
static func box(raised: bool, background := BACKGROUND, padding := 4) -> TkBorder:
	return TkBorder.make(TkBorder.Relief.RAISED if raised else TkBorder.Relief.SUNKEN, background, 1, padding)


## A border of any width and relief.
static func border(relief: TkBorder.Relief, background := BACKGROUND, width := TK_BORDER, padding := 2) -> TkBorder:
	return TkBorder.make(relief, background, width, padding)


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font = Content.olpc_font()
	theme.default_font_size = FONT_SIZE
	theme.set_stylebox("panel", "PanelContainer", box(true))
	theme.set_stylebox("panel", "Panel", box(true))
	for type in ["Label", "Button", "MenuBar", "CheckBox", "PopupMenu", "LinkButton"]:
		theme.set_color("font_color", type, TEXT)
	# Buttons: raised, lighter under the pointer, sunken while pressed.
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_hover_pressed_color", "Button", TEXT)
	theme.set_stylebox("normal", "Button", border(TkBorder.Relief.RAISED))
	theme.set_stylebox("hover", "Button", border(TkBorder.Relief.RAISED, ACTIVE))
	theme.set_stylebox("pressed", "Button", border(TkBorder.Relief.SUNKEN, ACTIVE))
	theme.set_stylebox("hover_pressed", "Button", border(TkBorder.Relief.SUNKEN, ACTIVE))
	theme.set_stylebox("disabled", "Button", border(TkBorder.Relief.RAISED))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Menus: a raised 2-pixel frame, and the entry under the pointer raised by
	# one pixel in the active colour (Tk's DEF_MENU_ACTIVE_BORDER_WIDTH).
	theme.set_stylebox("panel", "PopupMenu", border(TkBorder.Relief.RAISED, BACKGROUND, TK_BORDER, 2))
	theme.set_stylebox("hover", "PopupMenu", border(TkBorder.Relief.RAISED, ACTIVE, 1, 0))
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", SHADOW)
	theme.set_color("font_hover_color", "MenuBar", TEXT)
	theme.set_color("font_pressed_color", "MenuBar", TEXT)
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(style, "MenuBar", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "TooltipPanel", box(true, Color("#ffffe0"), 3))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	# A separate window's frame and title bar: the window manager's, not Tk's.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#a8a8a8")
	frame.set_border_width_all(1)
	frame.border_color = SHADOW
	frame.expand_margin_top = 26
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_expand_margin(side, 3)
	theme.set_stylebox("embedded_border", "Window", frame)
	theme.set_stylebox("embedded_unfocused_border", "Window", frame)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_constant("title_height", "Window", 26)
	# Entries: sunken (*Entry.relief), on the background, black text.
	theme.set_stylebox("normal", "LineEdit", border(TkBorder.Relief.SUNKEN, BACKGROUND, TK_BORDER, 3))
	theme.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", ACTIVE)
	# The file chooser's lists: sunken listboxes (*Listbox.relief), with the
	# selection in *selectBackground.
	for type in ["Tree", "ItemList"]:
		theme.set_stylebox("panel", type, border(TkBorder.Relief.SUNKEN, BACKGROUND, TK_BORDER, 2))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hovered_color", type, TEXT)
		theme.set_color("font_selected_color", type, TEXT)
		theme.set_stylebox("selected", type, border(TkBorder.Relief.RAISED, ACTIVE, 1, 0))
		theme.set_stylebox("selected_focus", type, border(TkBorder.Relief.RAISED, ACTIVE, 1, 0))
	# Dialogs (the file chooser, the questions, About).
	theme.set_stylebox("panel", "AcceptDialog", box(true, BACKGROUND, 8))
	theme.set_stylebox("normal", "OptionButton", border(TkBorder.Relief.RAISED))
	theme.set_stylebox("hover", "OptionButton", border(TkBorder.Relief.RAISED, ACTIVE))
	theme.set_stylebox("pressed", "OptionButton", border(TkBorder.Relief.SUNKEN, ACTIVE))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	return theme
