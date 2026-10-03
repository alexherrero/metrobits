# The head window's numbers: date, funds, population, speed and the demand
# gauge, kept up to date by the engine's signals.
extends GutTest

var engine: CityEngine
var head: HeadPanel


func before_each() -> void:
	engine = MicropolisCityEngine.new()
	engine.set_fixed_seed(1989)
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	head = HeadPanel.new()
	add_child_autofree(head)
	head.setup(engine)


func test_formats() -> void:
	assert_eq(HeadPanel.format_date(1972, 0), "Jan 1972")
	assert_eq(HeadPanel.format_date(2049, 11), "Dec 2049")
	assert_eq(HeadPanel.format_money(20000), "$20,000")
	assert_eq(HeadPanel.format_money(-1500), "-$1,500")
	assert_eq(HeadPanel.format_money(7), "$7")
	assert_eq(HeadPanel.format_count(1234567), "1,234,567")
	assert_eq(HeadPanel.format_count(999), "999")


func test_it_shows_the_loaded_city() -> void:
	assert_eq(head.date_label.text, "Jan 1972")
	assert_eq(head.funds_label.text, "Funds: $20,000")
	assert_string_starts_with(head.population_label.text, "Population: ")
	assert_eq(head.gauge.demand, engine.get_demand())


func test_it_follows_the_engine() -> void:
	for i in 400:
		engine.tick()
	assert_eq(head.date_label.text, HeadPanel.format_date(engine.get_year(), engine.get_month()))
	assert_ne(head.date_label.text, "Jan 1972", "the date moved on")
	assert_eq(head.funds_label.text, "Funds: " + HeadPanel.format_money(engine.get_funds()))
	assert_eq(head.population_label.text, "Population: " + HeadPanel.format_count(engine.get_population()))
	assert_eq(head.gauge.demand, engine.get_demand())



func test_it_shows_the_priority() -> void:
	head.show_priority("Normal", false)
	assert_eq(head.priority_label.text, "Priority: Normal")
	head.show_priority("Normal", true)
	assert_eq(head.priority_label.text, "Paused")


func test_the_gauge_bars_are_uisetdemands() -> void:
	# drawValve cut the valves to +-1500, SetDemand sent hundreds.
	assert_eq(DemandGauge.bar_length(0), 0)
	assert_eq(DemandGauge.bar_length(1000), 10)
	assert_eq(DemandGauge.bar_length(-750), -7, "truncated, as C's (int) did")
	assert_eq(DemandGauge.bar_length(99999), 15)
	assert_eq(DemandGauge.bar_length(-99999), -15)
	assert_eq(DemandGauge.bar_span(1000), Vector2i(14, 24), "a demand rises from 24")
	assert_eq(DemandGauge.bar_span(-700), Vector2i(32, 39), "a surplus falls from 32")
	assert_eq(DemandGauge.bar_span(0), Vector2i(32, 32), "none: a line at 32")
	assert_eq(DemandGauge.BAR_X, [Vector2(49, 55), Vector2(58, 64), Vector2(67, 73)])
	assert_eq(head.gauge.custom_minimum_size, Vector2(80, 55), "the 80 x 55 canvas")
