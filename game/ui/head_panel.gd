## The head window's panel below its menus (whead.tcl), on #BFBFBF in a
## raised frame:
## - on the left, the demand canvas (DemandGauge: the logo, the gauge's
##   picture and its bars), and beside it, in a sunken frame, the small graph
##   of residential, commercial and industrial over 10 years (graphview, Range
##   10, Mask 7);
## - on the right, the date, the funds, "Tax Rate: 7%" and the tax slider
##   (0 to 20, SetTaxRate), then our additions: the population and
##   the Priority.
##
## Its click map is the OLPC's: the logo pauses or resumes, the gauge's
## picture and bars show or hide the evaluation, the funds and the tax rate
## open the budget (UIShowBudgetAndWait), and the small graph shows or hides
## the graph window (ToggleGraphOf). The game window connects them.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name HeadPanel
extends PanelContainer

## A click on the small graph.
signal graph_clicked
## A click on the funds or the tax rate.
signal budget_clicked

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## The head's own background (whead.tcl's -background #BFBFBF).
const BACKGROUND := Color("#bfbfbf")
## Residential, commercial and industrial (1989's Mask 7).
const GRAPH_MASK := 0b000111
## The info column's labels are 20 characters wide (-width 20).
const INFO_CHARACTERS := 20
## Tk's scale: a 15-pixel trough, a 15-pixel slider (-sliderlength 15).
const SLIDER_SIZE := Vector2i(15, 15)

var gauge: DemandGauge
## The small graph.
var graph: GraphView
var date_label: Label
var funds_label: Label
var tax_label: Label
var tax_slider: HSlider
var population_label: Label
var priority_label: Label

var _engine: CityEngine


func _init() -> void:
	add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.RAISED, BACKGROUND, 1, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	# The frame: the demand canvas (packed left sw padx 4) and the graph.
	var frame := HBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_right", 4)
	pad.size_flags_vertical = Control.SIZE_SHRINK_END
	frame.add_child(pad)
	gauge = DemandGauge.new()
	gauge.name = "Demand"
	pad.add_child(gauge)
	var sunken := PanelContainer.new()
	sunken.add_theme_stylebox_override("panel", ClassicTheme.border(TkBorder.Relief.SUNKEN, BACKGROUND, 1, 0))
	sunken.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(sunken)
	graph = GraphView.new()
	graph.name = "Graph"
	graph.mask = GRAPH_MASK
	graph.history_scale = CityEngine.HistoryScale.SHORT
	graph.custom_minimum_size = Vector2(40, 40)
	graph.mouse_filter = Control.MOUSE_FILTER_STOP
	graph.tooltip_text = "Residential, commercial and industrial over 10 years: click for the graph window"
	graph.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			graph_clicked.emit())
	sunken.add_child(graph)

	# The info column.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	var font := Content.olpc_font()
	info.custom_minimum_size.x = INFO_CHARACTERS * font.get_char_size(ord("0"), ClassicTheme.MEDIUM).x
	row.add_child(info)
	date_label = _label(info, "Date")
	funds_label = _label(info, "Funds: click for the budget")
	funds_label.mouse_filter = Control.MOUSE_FILTER_STOP
	funds_label.gui_input.connect(_on_budget_label)
	tax_label = _label(info, "Tax rate: click for the budget")
	tax_label.mouse_filter = Control.MOUSE_FILTER_STOP
	tax_label.gui_input.connect(_on_budget_label)
	tax_slider = HSlider.new()
	tax_slider.name = "TaxRate"
	tax_slider.min_value = 0
	tax_slider.max_value = 20
	tax_slider.step = 1
	tax_slider.focus_mode = Control.FOCUS_NONE
	tax_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tax_slider.tooltip_text = "Tax rate"
	_style_slider(tax_slider)
	tax_slider.value_changed.connect(_on_slider)
	info.add_child(tax_slider)
	population_label = _label(info, "Population")
	priority_label = _label(info, "Priority")


static func format_date(year: int, month: int) -> String:
	return "%s %d" % [MONTHS[posmod(month, 12)], year]


## 20000 -> "$20,000"; -1500 -> "-$1,500".
static func format_money(amount: int) -> String:
	return ("-$" if amount < 0 else "$") + format_count(absi(amount))


## 1234567 -> "1,234,567".
static func format_count(count: int) -> String:
	var digits := str(absi(count))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if count < 0 else "") + digits + out


func setup(engine: CityEngine) -> void:
	_engine = engine
	engine.funds_changed.connect(func(_funds: int) -> void: _show_funds())
	engine.date_changed.connect(func(_year: int, _month: int) -> void: _show_date())
	engine.demand_changed.connect(func(_r: float, _c: float, _i: float) -> void: _show_demand())
	engine.evaluation_changed.connect(_show_population)
	engine.tax_rate_changed.connect(func(_rate: int) -> void: _show_tax())
	engine.budget_changed.connect(_show_tax)
	graph.setup(engine)
	refresh()


## Shows everything afresh (after a load).
func refresh() -> void:
	_show_date()
	_show_funds()
	_show_tax()
	_show_demand()
	_show_population()
	graph.queue_redraw()


## The game window's Priority (its name, e.g. "Normal"), or Paused; and the
## logo, green while the city runs (UIUpdateRunning).
func show_priority(priority_name: String, paused: bool) -> void:
	priority_label.text = "Paused" if paused else "Priority: " + priority_name
	gauge.running = not paused


func _show_date() -> void:
	date_label.text = format_date(_engine.get_year(), _engine.get_month())


func _show_funds() -> void:
	funds_label.text = "Funds: " + format_money(_engine.get_funds())


## "Tax Rate: 7%" and the slider, as UISetBudget kept them.
func _show_tax() -> void:
	var rate := _engine.get_tax_rate()
	tax_label.text = "Tax Rate: %d%%" % rate
	if int(tax_slider.value) != rate:
		tax_slider.set_value_no_signal(rate)


func _show_demand() -> void:
	gauge.demand = _engine.get_demand()


func _show_population() -> void:
	# The engine counts the population at its yearly evaluation: -1 until then.
	var population := _engine.get_population()
	population_label.text = "Population: " + (format_count(population) if population >= 0 else "counting...")


## The slider moved: the engine's tax rate (SetTaxRate, sim TaxRate).
func _on_slider(value: float) -> void:
	if _engine != null and int(value) != _engine.get_tax_rate():
		_engine.set_tax_rate(int(value))
	_show_tax()


func _on_budget_label(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		budget_clicked.emit()


func _label(parent: Control, tooltip: String) -> Label:
	var label := Label.new()
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(label)
	return label


## Tk's scale: a sunken trough of the background, and a raised slider in
## *Scale.sliderForeground (#b0b0b0), #d0d0d0 under the pointer.
func _style_slider(slider: HSlider) -> void:
	var trough := ClassicTheme.border(TkBorder.Relief.SUNKEN, BACKGROUND, 2, 0)
	trough.content_margin_top = SLIDER_SIZE.y / 2.0
	trough.content_margin_bottom = SLIDER_SIZE.y / 2.0
	slider.add_theme_stylebox_override("slider", trough)
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.add_theme_icon_override("grabber", _slider_picture(ClassicTheme.BACKGROUND))
	slider.add_theme_icon_override("grabber_highlight", _slider_picture(ClassicTheme.ACTIVE))
	slider.add_theme_icon_override("grabber_disabled", _slider_picture(ClassicTheme.BACKGROUND))


static func _slider_picture(face: Color) -> Texture2D:
	var image := Image.create_empty(SLIDER_SIZE.x, SLIDER_SIZE.y - 4, false, Image.FORMAT_RGBA8)
	image.fill(face)
	var light := TkBorder.light(face)
	var dark := TkBorder.dark(face)
	var w := image.get_width()
	var h := image.get_height()
	for i in 2:
		image.fill_rect(Rect2i(0, h - 1 - i, w, 1), dark)
		image.fill_rect(Rect2i(w - 1 - i, 0, 1, h), dark)
		image.fill_rect(Rect2i(0, i, w - i, 1), light)
		image.fill_rect(Rect2i(i, 0, 1, h - i), light)
	return ImageTexture.create_from_image(image)
