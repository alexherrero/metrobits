# The head window as whead.tcl built it: the demand canvas with the
# gauge's picture and the running or stopped logo, the tax rate and its
# slider, the click map, the scrolling, coloured log, and the yearly "Score"
# line; with our Population and Priority lines and the Budget button kept
#.
extends GutTest

var main: Control
var engine: CityEngine
var head: HeadPanel


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	engine = main.engine
	engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	head = main.head


func _click(control: Control, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	if control is DemandGauge:
		control._gui_input(event)
	else:
		control.gui_input.emit(event)


func _texts(parent: Control) -> Array:
	return parent.get_children().filter(func(c: Node) -> bool: return c is Label or c is HSlider).map(
		func(c: Node) -> String: return c.text if c is Label else "slider")


func test_the_info_column_in_whead_tcls_order_then_ours() -> void:
	var rate := engine.get_tax_rate()
	assert_eq(_texts(head.date_label.get_parent()), [head.date_label.text, "Funds: $20,000", "Tax Rate: %d%%" % rate,
		"slider", head.population_label.text, head.priority_label.text])
	assert_eq(head.tax_slider.value, float(rate))
	assert_eq([head.tax_slider.min_value, head.tax_slider.max_value], [0.0, 20.0], "the scale's -to 20")
	assert_not_null(main.budget_button, "our Budget button stays")


func test_the_demand_canvas_is_the_olpcs() -> void:
	var gauge := head.gauge
	assert_eq(gauge.custom_minimum_size, Vector2(80, 55))
	assert_eq(gauge.part_at(Vector2(45, 10)), "picture", "demandg.xpm at (41, 4)")
	assert_eq(gauge.part_at(Vector2(10, 20)), "logo", "the logo at (0, 4)")
	assert_eq(gauge.part_at(Vector2(39, 2)), "", "the canvas between them")
	assert_eq(gauge.logo(), "micropolisg", "running: the green logo")
	main.set_paused(true)
	assert_eq(gauge.logo(), "micropoliss", "stopped: the red one")
	main.set_paused(false)
	assert_eq(gauge.logo(), "micropolisg")
	assert_eq(head.gauge.demand, engine.get_demand())


func test_the_logo_pauses_and_resumes() -> void:
	var gauge := head.gauge
	_click(gauge, Vector2(10, 20))
	assert_true(engine.is_paused(), "TogglePause")
	assert_eq(main.message_label.text, "Time pauses.")
	_click(gauge, Vector2(10, 20))
	assert_false(engine.is_paused())


func test_the_gauge_shows_and_hides_the_evaluation() -> void:
	var gauge := head.gauge
	_click(gauge, Vector2(45, 10))
	assert_true(main.evaluation_window.visible, "ToggleEvaluationOf")
	assert_false(engine.is_paused(), "the gauge doesn't pause any more")
	_click(gauge, Vector2(45, 10))
	assert_false(main.evaluation_window.visible, "and away again")
	gauge.demand = Vector3i(1000, 0, 0)
	_click(gauge, Vector2(52, 16))
	assert_true(main.evaluation_window.visible, "a bar does it too")
	main.evaluation_window.hide()
	main.open_city_chooser()
	_click(gauge, Vector2(45, 10))
	assert_false(main.evaluation_window.visible, "only while a city plays")


func test_the_funds_and_the_tax_rate_open_the_budget() -> void:
	_click(head.tax_label, Vector2(5, 5))
	await wait_process_frames(2)
	assert_true(main.budget_window.visible, "a click on the tax rate")
	main.budget_window.hide()
	main._on_budget_finished(false)
	_click(head.funds_label, Vector2(5, 5))
	await wait_process_frames(2)
	assert_true(main.budget_window.visible, "and on the funds")


func test_the_slider_sets_the_tax_rate() -> void:
	head.tax_slider.value = 12
	assert_eq(engine.get_tax_rate(), 12, "SetTaxRate: sim TaxRate")
	assert_eq(head.tax_label.text, "Tax Rate: 12%")
	engine.set_tax_rate(3)
	head.refresh()
	assert_eq([head.tax_slider.value, head.tax_label.text], [3.0, "Tax Rate: 3%"], "and follows the engine")


func test_the_budget_windows_tax_moves_the_heads() -> void:
	main.request_budget()
	await wait_process_frames(2)
	main.budget_window.tax_slider.value = 15
	assert_eq(head.tax_label.text, "Tax Rate: 15%")
	assert_eq(head.tax_slider.value, 15.0)


func test_the_log_scrolls_and_keeps_500_lines() -> void:
	var log: MessageLog = main.message_log
	main.set_paused(true)
	for i in 20:
		log.add("Line %d" % i)
	await wait_process_frames(4)
	assert_eq(log.lines[-1], "Line 19")
	var bar := log.scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page, "more than five lines")
	assert_eq(log.scroll.scroll_vertical, int(bar.max_value - bar.page), "scrolled to the newest")
	assert_lt(bar.global_position.x, log.text.global_position.x, "the scrollbar on the left, as packed")
	for i in 600:
		log.add("More %d" % i)
	assert_lte(log.lines.size(), MessageLog.MAX_LINES)
	assert_eq(log.lines[-1], "More 599")


func test_the_logs_colours() -> void:
	var log: MessageLog = main.message_log
	log.add("An ordinary [line]")
	log.add("Unable to save the city.", "alert")
	log.add("Hi from a player", "message")
	var shown := log.text.text
	assert_string_contains(shown, "An ordinary [lb]line]", "brackets shown as text")
	assert_string_contains(shown, "[color=#ff3f3f]Unable to save the city.[/color]", "alerts in red")
	assert_string_contains(shown, "[bgcolor=#3f3f3f][color=#ffffff]Hi from a player", "messages white on dark gray")


func test_a_city_that_wont_save_says_so_in_red() -> void:
	engine.city_save_failed.emit("/nowhere/x.cty")
	assert_eq(main.message_log.lines[-1], "Unable to save the city to the file named \"/nowhere/x.cty\".")
	assert_eq(main.message_log.tags[-1], "alert")


func test_each_evaluation_says_the_score() -> void:
	watch_signals(engine)
	var ticks := 0
	while get_signal_emit_count(engine, "evaluation_changed") == 0 and ticks < 5000:
		engine.tick()
		ticks += 1
	assert_signal_emitted(engine, "evaluation_changed")
	var evaluation := engine.get_evaluation()
	var city_class: String = EvaluationWindow.CLASSES[evaluation.city_class]
	var line := "%s: Score %d, %s population %d." % [HeadPanel.format_date(engine.get_year(), engine.get_month()),
		evaluation.score, city_class.to_lower(), evaluation.population]
	assert_eq(main.message_label.text, line, "UISetEvaluation's UISetMessage")
	assert_true(main.message_log.lines.has(line))
	assert_string_contains(line, ": Score ")
