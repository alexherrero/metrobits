# Repeatable runs: with a fixed seed, a city simulates the same way
# every time. Every load reseeds the engine's random numbers and uses them before
# it returns, so the seed has to be fixed before the load.
extends GutTest

const LOOPS := 4000
const CHECK_EVERY := 500


## What two runs are compared on: the numbers, and a hash of the tile map.
func _state(engine: CityEngine) -> Dictionary:
	return {
		time = engine.get_city_time(),
		funds = engine.get_funds(),
		population = engine.get_population(),
		residential = engine.get_residential_population(),
		commercial = engine.get_commercial_population(),
		industrial = engine.get_industrial_population(),
		demand = engine.get_demand(),
		map = hash(engine.get_map()),
	}


func _loaded(scenario: CityEngine.Scenario, seed: int) -> CityEngine:
	var engine: CityEngine = MicropolisCityEngine.new()
	engine.set_fixed_seed(seed)
	assert_true(engine.load_scenario(scenario), "scenario %d loads" % scenario)
	return engine


func test_the_same_seed_gives_identical_runs_in_every_scenario() -> void:
	for scenario: int in CityEngine.Scenario.values():
		if scenario == CityEngine.Scenario.NONE:
			continue
		var a := _loaded(scenario, 1989)
		var b := _loaded(scenario, 1989)
		var start := _state(a)
		var same := true
		for loop in range(1, LOOPS + 1):
			a.tick()
			b.tick()
			if loop % CHECK_EVERY == 0 and _state(a) != _state(b):
				same = false
				fail_test("scenario %d diverged by loop %d" % [scenario, loop])
				break
		if same:
			assert_eq(a.get_map(), b.get_map(), "scenario %d: identical maps" % scenario)
			assert_ne(_state(a), start, "scenario %d: the city changed" % scenario)


func test_different_seeds_diverge() -> void:
	var a := _loaded(CityEngine.Scenario.DETROIT, 1)
	var b := _loaded(CityEngine.Scenario.DETROIT, 2)
	for i in 1000:
		a.tick()
		b.tick()
	assert_ne(_state(a), _state(b))


func test_the_clock_is_back_after_clear_fixed_seed() -> void:
	# Seeded from the clock, two loads a moment apart simulate differently.
	var a: CityEngine = MicropolisCityEngine.new()
	a.set_fixed_seed(7)
	a.clear_fixed_seed()
	a.load_scenario(CityEngine.Scenario.DETROIT)
	OS.delay_usec(2000)
	var b: CityEngine = MicropolisCityEngine.new()
	b.load_scenario(CityEngine.Scenario.DETROIT)
	for i in 1000:
		a.tick()
		b.tick()
	assert_ne(_state(a), _state(b))
