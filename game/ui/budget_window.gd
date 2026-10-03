## The original's budget window (wbudget.tcl): taxes collected, cash flow and
## funds on the left; road, fire and police funding and the tax rate on the
## right, each a slider that applies at once; and the original's buttons,
## one above another: Continue With These Figures, Reset to Original Figures,
## Cancel Changes and Continue, the auto-cancel timer, and Auto Budget. The
## game pauses while it's open.
##
## The timer is the OLPC's (StartBudgetTimer and TickBudgetTimer): each time
## the window opens it counts down from 30 seconds, once a second, and past 0
## it cancels the changes and closes (FireBudgetTimer, BudgetCancel). Any
## change starts it again from 30 (ChangeBudget, RestartBudgetTimer), and a
## click on it turns it off or back on (ToggleBudgetTimer).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name BudgetWindow
extends Window

## Continue With These Figures: changed says whether the figures differ from
## those it opened with (BudgetContinue).
signal finished(changed: bool)
## Cancel Changes and Continue, the close box or the timer: the figures were
## put back and it closed (BudgetCancel).
signal cancelled
## Reset to Original Figures, which Cancel does first (BudgetReset).
signal was_reset

## BudgetTimeout, in seconds.
const TIMEOUT := 30

const FUNDS := ["road", "fire", "police"]
const FUND_TITLES := {road = "Road Fund", fire = "Fire Fund", police = "Police Fund"}

var sliders := {}
var request_labels := {}
var tax_slider: HSlider
var tax_label: Label
var collected_label: Label
var cash_flow_label: Label
var previous_label: Label
var current_label: Label
var auto_budget_button: Button
var timer_button: Button
## The auto-cancel timer: running or not, and the seconds it shows.
var timer_active := false
var timer_seconds := 0

var _timer_clock := 0.0

var _engine: CityEngine
var _original := {}
var _updating := false


func _init() -> void:
	title = "Micropolis Budget"
	visible = false
	transient = true
	exclusive = false
	unresizable = true
	wrap_controls = true
	close_requested.connect(func() -> void: close(true))
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Micropolis has paused to set the budget..."
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 16)
	column.add_child(sides)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 150
	sides.add_child(left)
	collected_label = _figure(left, "Taxes Collected")
	cash_flow_label = _figure(left, "Cash Flow")
	previous_label = _figure(left, "Previous Funds")
	current_label = _figure(left, "Current Funds")
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 260
	sides.add_child(right)
	for fund: String in FUNDS:
		var title_label := _centered(right, FUND_TITLES[fund])
		title_label.add_theme_font_size_override("font_size", 14)
		request_labels[fund] = _centered(right, "")
		sliders[fund] = _slider(right, 100, func(value: float) -> void: _set_fund(fund, value))
	_centered(right, "Tax Rate").add_theme_font_size_override("font_size", 14)
	tax_label = _centered(right, "")
	tax_slider = _slider(right, 20, _set_tax)

	# wbudget.tcl's bottom frame: each button packed top, fill x, in Large.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 0)
	column.add_child(buttons)
	_button(buttons, "Continue With These Figures", func() -> void: close(false))
	_button(buttons, "Reset to Original Figures", reset)
	_button(buttons, "Cancel Changes and Continue", func() -> void: close(true))
	timer_button = _button(buttons, "", toggle_timer)
	auto_budget_button = _button(buttons, "", _toggle_auto_budget)


## Opens it over the game, remembering the figures to reset to.
func open(engine: CityEngine) -> void:
	_engine = engine
	var budget := engine.get_budget()
	_original = {tax = engine.get_tax_rate(), road = budget.road_percent,
		fire = budget.fire_percent, police = budget.police_percent}
	refresh()
	start_timer()
	if not visible:
		popup_centered()


## The timer from 30 again (StartBudgetTimer).
func start_timer() -> void:
	timer_active = true
	timer_seconds = TIMEOUT
	_timer_clock = 0.0
	_show_timer()


func stop_timer() -> void:
	timer_active = false
	_show_timer()


## A click on the timer: off, or on again from 30 (ToggleBudgetTimer).
func toggle_timer() -> void:
	if timer_active:
		stop_timer()
	else:
		start_timer()


## Counts the timer down by whole seconds; past 0 it cancels (TickBudgetTimer).
func tick_timer(seconds := 1) -> void:
	for i in seconds:
		if not timer_active or not visible:
			return
		timer_seconds -= 1
		if timer_seconds < 0:
			stop_timer()
			close(true)
			return
		_show_timer()


func _process(delta: float) -> void:
	if not timer_active or not visible:
		return
	_timer_clock += delta
	while _timer_clock >= 1.0 and timer_active:
		_timer_clock -= 1.0
		tick_timer()


## UpdateBudgetTimer's words.
func _show_timer() -> void:
	if timer_button == null:
		return
	timer_button.text = ("Auto Cancel In %d Seconds (click to disable)" % timer_seconds if timer_active
		else "Enable Auto Cancel (currently disabled)")


## A change: the timer starts again, if it's on (RestartBudgetTimer).
func _changed() -> void:
	if timer_active:
		start_timer()


## Shows the engine's figures.
func refresh() -> void:
	var budget := _engine.get_budget()
	_updating = true
	var spending := 0
	for fund: String in FUNDS:
		var percent: float = budget[fund + "_percent"]
		var requested: int = budget[fund + "_requested"]
		var allocated := int(requested * percent)
		spending += allocated
		sliders[fund].value = roundi(percent * 100.0)
		request_labels[fund].text = "%d%% of %s = %s" % [roundi(percent * 100.0),
			HeadPanel.format_money(requested), HeadPanel.format_money(allocated)]
	tax_slider.value = _engine.get_tax_rate()
	tax_label.text = "%d%%" % _engine.get_tax_rate()
	_updating = false
	# As the 1989 window worked it out (ReallyDrawBudgetWindow in w_budget.c).
	var collected: int = budget.tax_income
	var cash_flow := collected - spending
	collected_label.text = HeadPanel.format_money(collected)
	cash_flow_label.text = ("+" if cash_flow >= 0 else "") + HeadPanel.format_money(cash_flow)
	previous_label.text = HeadPanel.format_money(_engine.get_funds())
	current_label.text = HeadPanel.format_money(_engine.get_funds() + cash_flow)
	auto_budget_button.text = ("Disable Auto Budget (currently enabled)" if _engine.get_auto_budget()
		else "Enable Auto Budget (currently disabled)")


## Puts back the figures it opened with (BudgetReset).
func reset() -> void:
	_engine.set_tax_rate(_original.tax)
	_engine.set_road_percent(_original.road)
	_engine.set_fire_percent(_original.fire)
	_engine.set_police_percent(_original.police)
	refresh()
	was_reset.emit()
	_changed()


## Whether any figure differs from those it opened with.
func changed() -> bool:
	var budget := _engine.get_budget()
	return (_engine.get_tax_rate() != _original.tax or not is_equal_approx(budget.road_percent, _original.road)
		or not is_equal_approx(budget.fire_percent, _original.fire)
		or not is_equal_approx(budget.police_percent, _original.police))


## Closes it, first putting the figures back if cancel.
func close(cancel: bool) -> void:
	if cancel:
		reset()
	var was_changed := changed()
	timer_active = false
	hide()
	if cancel:
		cancelled.emit()
	else:
		finished.emit(was_changed)


func _set_fund(fund: String, value: float) -> void:
	if _updating:
		return
	match fund:
		"road": _engine.set_road_percent(value / 100.0)
		"fire": _engine.set_fire_percent(value / 100.0)
		"police": _engine.set_police_percent(value / 100.0)
	refresh()
	_changed()


func _set_tax(value: float) -> void:
	if _updating:
		return
	_engine.set_tax_rate(int(value))
	refresh()
	_changed()


func _toggle_auto_budget() -> void:
	_engine.set_auto_budget(not _engine.get_auto_budget())
	refresh()


func _figure(parent: Control, caption: String) -> Label:
	_centered(parent, caption).add_theme_font_size_override("font_size", 14)
	var value := _centered(parent, "")
	value.add_theme_constant_override("line_spacing", 0)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	parent.add_child(spacer)
	return value


func _centered(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _slider(parent: Control, maximum: int, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.max_value = maximum
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
	return slider


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", ClassicTheme.LARGE)
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button
