## The head window's log (whead.tcl): a sunken text five lines tall, in Text's
## size, wrapping at words, with its scrollbar on the left, that keeps every
## message and scrolls to the newest (appendWithTag). Past 500 lines it drops
## the oldest 250 (MaxLines, ShrinkLines).
##
## Each line has a tag, as the OLPC's text did: "status" for the city's
## messages and the game's own (UISetMessage), plain; "alert", red (#ff3f3f),
## for a city that won't save or load; and "message", white on #3f3f3f, for
## what the OLPC's players typed to each other.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name MessageLog
extends PanelContainer

const VISIBLE_LINES := 5
const MAX_LINES := 500
const SHRINK_LINES := 250
const ALERT_COLOR := Color("#ff3f3f")
const MESSAGE_COLOR := Color.WHITE
const MESSAGE_BACKGROUND := Color("#3f3f3f")

## The lines kept, oldest first, and each one's tag.
var lines: Array[String] = []
var tags: Array[String] = []
var scroll: ScrollContainer
var text: RichTextLabel


func _init() -> void:
	add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.FLAT, ClassicTheme.BACKGROUND, 1, 0))
	var sunken := PanelContainer.new()
	sunken.add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.SUNKEN, ClassicTheme.BACKGROUND, 1, 1))
	add_child(sunken)
	# Right-to-left puts the scrollbar on the left, as the OLPC packed it; the
	# text inside stays left-to-right.
	scroll = ScrollContainer.new()
	scroll.layout_direction = Control.LAYOUT_DIRECTION_RTL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	sunken.add_child(scroll)
	text = RichTextLabel.new()
	text.layout_direction = Control.LAYOUT_DIRECTION_LTR
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", ClassicTheme.TEXT)
	text.add_theme_font_size_override("normal_font_size", ClassicTheme.MEDIUM)
	text.add_theme_constant_override("line_separation", 0)
	scroll.add_child(text)
	_style_scrollbar(scroll.get_v_scroll_bar())
	# Once the new line is laid out, the bar's range grows: follow it to the end.
	scroll.get_v_scroll_bar().changed.connect(_scroll_to_end)


func _ready() -> void:
	var font := get_theme_default_font()
	var line := font.get_height(ClassicTheme.MEDIUM) if font else 17.0
	scroll.custom_minimum_size.y = ceilf(VISIBLE_LINES * line)


## Adds a line with a tag, unless it's the newest line again, and scrolls to it.
func add(line: String, tag := "status") -> void:
	if line.is_empty() or (not lines.is_empty() and lines[-1] == line):
		return
	if lines.size() >= MAX_LINES:
		lines = lines.slice(SHRINK_LINES)
		tags = tags.slice(SHRINK_LINES)
	lines.append(line)
	tags.append(tag)
	_show()


func _show() -> void:
	var out := PackedStringArray()
	for i in lines.size():
		var line := lines[i].replace("[", "[lb]")
		match tags[i]:
			"alert":
				line = "[color=#%s]%s[/color]" % [ALERT_COLOR.to_html(false), line]
			"message":
				line = "[bgcolor=#%s][color=#%s]%s[/color][/bgcolor]" % [MESSAGE_BACKGROUND.to_html(false),
					MESSAGE_COLOR.to_html(false), line]
		out.append(line)
	text.text = "\n".join(out)
	_scroll_to_end()


func _scroll_to_end() -> void:
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## Tk's scrollbar, 15 pixels wide (DEF_SCROLLBAR_WIDTH): a sunken trough and
## a raised slider in #d0d0d0 (*Scrollbar.Background and .Foreground).
func _style_scrollbar(bar: VScrollBar) -> void:
	for state in ["scroll", "scroll_focus"]:
		var trough := ClassicTheme.border(TkBorder.Relief.SUNKEN, ClassicTheme.BACKGROUND, 1, 0)
		trough.content_margin_left = 7
		trough.content_margin_right = 8
		bar.add_theme_stylebox_override(state, trough)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, ClassicTheme.border(TkBorder.Relief.RAISED, ClassicTheme.ACTIVE, 1, 0))
	bar.custom_minimum_size.x = 15
