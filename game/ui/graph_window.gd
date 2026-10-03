## The original's graph window (wgraph.tcl), with its own pictures
## (micropolis-core/olpc/images/gr*.xpm): on the left, in a raised frame, the
## 10 YRS. and 120 YRS. pictures above two columns of switches, Residential,
## Commercial and Industrial, then Cash Flow, Crime and Pollution; the graph
## beside them; and Dismiss Graph below. A switch shows its "hi" picture while
## its graph is on, and the year picture chosen shows its "hi" one, as
## NonExclusivePallet and ExclusivePallet set them. It opens with every graph
## on, over 10 years (InitGraph).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name GraphWindow
extends Window

## The switches' pictures, in HistoryType's order (GraphPalletImages), and the
## years' (GraphYearPalletImages): each "gr<name>.xpm", and "gr<name>hi.xpm"
## when on.
const PICTURES := ["res", "com", "ind", "mony", "crim", "poll"]
const YEAR_PICTURES := ["10", "120"]

var graph: GraphView
## The six switches, in HistoryType's order, and the two year buttons.
var switches: Array[TextureButton] = []
var year_buttons: Array[TextureButton] = []


func _init() -> void:
	title = "Micropolis Graph"
	visible = false
	transient = true
	exclusive = false
	unresizable = true
	wrap_controls = true
	close_requested.connect(hide)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 0))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)

	# The leftframe: -borderwidth 1 -relief raised; each picture packed with
	# padx 2 and pady 2, the years stacked on top.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 0))
	row.add_child(left)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 0)
	left.add_child(controls)
	var years := VBoxContainer.new()
	years.add_theme_constant_override("separation", 0)
	controls.add_child(_padded(years))
	for scale: int in [CityEngine.HistoryScale.SHORT, CityEngine.HistoryScale.LONG]:
		var button := _picture_button("%s Years" % YEAR_PICTURES[scale])
		button.pressed.connect(set_years.bind(scale))
		years.add_child(button)
		year_buttons.append(button)
	var pairs := HBoxContainer.new()
	pairs.add_theme_constant_override("separation", 0)
	pairs.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_child(pairs)
	for side in 2:
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 0)
		pairs.add_child(stack)
		for type in range(side * 3, side * 3 + 3):
			var button := _picture_button(GraphView.NAMES[type])
			button.pressed.connect(toggle.bind(type))
			stack.add_child(_padded(button))
			switches.append(button)

	# The centerframe: -borderwidth 1 -relief raised, around the graph.
	var center := PanelContainer.new()
	center.add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 0))
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	graph = GraphView.new()
	graph.name = "Graph"
	graph.custom_minimum_size = Vector2(440, 190)
	center.add_child(graph)

	var dismiss := Button.new()
	dismiss.text = "Dismiss Graph"
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.add_theme_font_size_override("font_size", ClassicTheme.LARGE)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var relief := TkBorder.Relief.SUNKEN if "pressed" in state else TkBorder.Relief.RAISED
		var background := ClassicTheme.BACKGROUND if state == "normal" else ClassicTheme.ACTIVE
		dismiss.add_theme_stylebox_override(state, ClassicTheme.border(relief, background, 1))
	dismiss.pressed.connect(hide)
	column.add_child(dismiss)
	_show_state()


func setup(engine: CityEngine) -> void:
	graph.setup(engine)


## Every graph on, over 10 years, as 1989's InitGraph started it.
func reset() -> void:
	graph.mask = GraphView.ALL
	graph.history_scale = CityEngine.HistoryScale.SHORT
	_show_state()


## Shows the last 10 or 120 years (GraphYearPallet).
func set_years(scale: CityEngine.HistoryScale) -> void:
	graph.history_scale = scale
	_show_state()


## Turns one graph on or off (GraphPallet).
func toggle(type: int) -> void:
	graph.mask ^= 1 << type
	_show_state()


func _show_state() -> void:
	for type in switches.size():
		var on := bool(graph.mask & (1 << type))
		switches[type].texture_normal = Content.olpc_texture("gr%s%s" % [PICTURES[type], "hi" if on else ""])
		switches[type].tooltip_text = "%s: %s" % [GraphView.NAMES[type], "on" if on else "off"]
	for scale in year_buttons.size():
		var chosen := graph.history_scale == scale
		year_buttons[scale].texture_normal = Content.olpc_texture("gr%s%s" % [YEAR_PICTURES[scale], "hi" if chosen else ""])


## A picture button: Tk's -borderwidth 0 -relief flat -padx 0 -pady 0.
func _picture_button(tooltip: String) -> TextureButton:
	var button := TextureButton.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	return button


## Pack's padx 2 and pady 2 around a widget.
func _padded(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 2)
	margin.add_child(child)
	return margin
