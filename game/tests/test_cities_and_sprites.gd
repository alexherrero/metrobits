# In the engine: a saved .cty file holds the city as it was, reloads
# as it, and carries on the same way whichever engine loads it (local edit 10);
# the sprites the engine moves (trains, planes, helicopters, ships, the
# tornado, the monster, explosions) can be read; and 1989's Air Crash is back
# (local edit 9).
extends GutTest

const SAVE := "user://test_city.cty"

var engine: CityEngine


func before_each() -> void:
	engine = _engine()
	watch_signals(engine)


func after_each() -> void:
	for path in [SAVE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _engine() -> CityEngine:
	var city: CityEngine = MicropolisCityEngine.new()
	city.set_fixed_seed(1989)
	return city


func _run(city: CityEngine, ticks: int) -> void:
	for i in ticks:
		city.tick()


## What a .cty file holds besides the map: the date, the funds, the tax rate,
## the options and the graphs' history.
func _saved_state(city: CityEngine) -> Dictionary:
	var history := []
	for type: int in CityEngine.HistoryType.values():
		history.append(city.get_history(type, CityEngine.HistoryScale.SHORT))
		history.append(city.get_history(type, CityEngine.HistoryScale.LONG))
	return {
		city_time = city.get_city_time(), date = [city.get_year(), city.get_month()],
		funds = city.get_funds(), tax = city.get_tax_rate(), auto_budget = city.get_auto_budget(),
		auto_bulldoze = city.get_auto_bulldoze(), history = history,
	}


## The map in a .cty file, row-major like get_map(). The file has the six
## graphs (480 bytes each), 240 bytes of other figures, then the map as
## big-endian 16-bit tiles, column by column (fileio.cpp).
func _map_in_file(path: String) -> PackedInt32Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	var start := 6 * 480 + 240
	var map := PackedInt32Array()
	map.resize(CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT)
	for x in CityEngine.MAP_WIDTH:
		for y in CityEngine.MAP_HEIGHT:
			var at := start + 2 * (x * CityEngine.MAP_HEIGHT + y)
			map[y * CityEngine.MAP_WIDTH + x] = bytes[at] << 8 | bytes[at + 1]
	return map


## The city as it runs: the numbers the head, the graphs and the evaluation show.
func _running_state(city: CityEngine) -> Dictionary:
	return {
		map = hash(city.get_map()), date = [city.get_year(), city.get_month()], funds = city.get_funds(),
		population = [city.get_residential_population(), city.get_commercial_population(),
			city.get_industrial_population(), city.get_population()],
		demand = city.get_demand(), score = city.get_evaluation().score,
		sprites = city.get_sprites().size(),
	}


# Save and load ------------------------------------------------------------------

func test_a_saved_city_reloads_as_it_was() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	_run(engine, 3000)
	engine.set_tax_rate(9)
	assert_true(engine.save_city(SAVE))
	assert_signal_emitted(engine, "city_saved")
	assert_eq(FileAccess.get_file_as_bytes(SAVE).size(), 51120, "the classic .cty size")
	var map := engine.get_map()
	assert_true(_map_in_file(SAVE) == map, "the file holds every tile as it was")
	var saved := _saved_state(engine)
	var other := _engine()
	assert_true(other.load_city(SAVE))
	assert_eq(other.get_city_name(), "test_city", "a loaded city is named after its file, as in 1989")
	var loaded := _saved_state(other)
	for key: String in saved:
		assert_eq(loaded[key], saved[key], key)
	# A load runs the engine's first scan over the whole map, as 1989's did,
	# which clears traffic from the roads and moves some zones on a step.
	var same := 0
	var reloaded := other.get_map()
	for i in map.size():
		same += int(reloaded[i] & CityEngine.TILE_INDEX_MASK == map[i] & CityEngine.TILE_INDEX_MASK)
	assert_gt(same, int(map.size() * 0.97), "%d of %d tiles as they were" % [same, map.size()])


func test_a_reloaded_city_carries_on_identically_whichever_engine_loads_it() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	_run(engine, 2500)
	engine.make_tornado()
	_run(engine, 200)
	assert_true(engine.save_city(SAVE))
	# The engine that saved it reloads it, with its own history of messages,
	# sprites and random numbers behind it; a fresh engine loads it too.
	var fresh := _engine()
	assert_true(engine.load_city(SAVE))
	assert_true(fresh.load_city(SAVE))
	for check in 8:
		_run(engine, 500)
		_run(fresh, 500)
		assert_eq(_running_state(engine), _running_state(fresh), "after %d ticks" % ((check + 1) * 500))
	assert_true(engine.get_map() == fresh.get_map(), "the whole map, after 4,000 ticks")


# Local edit 10, for every scenario after another has run, at speed 2 as well.
func test_a_scenario_loaded_in_a_used_engine_runs_as_in_a_new_one() -> void:
	for scenario: int in range(CityEngine.Scenario.DULLSVILLE, CityEngine.Scenario.RIO + 1):
		var before := CityEngine.Scenario.RIO if scenario != CityEngine.Scenario.RIO else CityEngine.Scenario.TOKYO
		engine.load_scenario(before)
		engine.make_tornado()
		_run(engine, 777)
		engine.load_scenario(scenario)
		var fresh := _engine()
		fresh.load_scenario(scenario)
		for city: CityEngine in [engine, fresh]:
			city.set_speed(2)
			_run(city, 1000)
			city.set_speed(3)
			_run(city, 1000)
		assert_eq(_running_state(engine), _running_state(fresh), "scenario %d" % scenario)


# Local edit 11: the file's 32-bit fields are 32 bits natively too.
func test_a_negative_balance_reloads_as_a_debt() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.set_funds(-500)
	engine.save_city(SAVE)
	var other := _engine()
	other.load_city(SAVE)
	assert_eq(other.get_funds(), -500)
	var dirt := Array(other.get_map()).find(0)
	assert_eq(other.do_tool(CityEngine.Tool.ROAD, dirt % CityEngine.MAP_WIDTH, dirt / CityEngine.MAP_WIDTH),
		CityEngine.ToolResult.NO_MONEY, "no money to build with")


func test_saving_keeps_the_crime_and_pollution_ramps() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	_run(engine, 2000)
	engine.save_city(SAVE)
	# miscHist[10] and [11], after the six graphs; 64-bit writes of the city's
	# time (miscHist[8] and [9]) used to zero them.
	var bytes := FileAccess.get_file_as_bytes(SAVE)
	var at := 6 * 480 + 2 * 10
	var crime_ramp := bytes[at] << 8 | bytes[at + 1]
	var pollution_ramp := bytes[at + 2] << 8 | bytes[at + 3]
	assert_gt(crime_ramp, 0, "Detroit's crime")
	assert_gt(pollution_ramp, 0, "and pollution")


# The funding levels aren't kept: 1989's loadFile read them and then reset
# them to 100% (InitFundingLevel), and the engine does the same.
func test_a_loaded_city_funds_everything_in_full_as_in_1989() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	while engine.get_budget().tax_income == 0:
		engine.tick()
	engine.set_road_percent(0.5)
	engine.save_city(SAVE)
	var other := _engine()
	other.load_city(SAVE)
	assert_almost_eq(other.get_budget().road_percent, 1.0, 0.0001)


func test_every_bundled_city_loads() -> void:
	var dir := DirAccess.open(Content.path("cities"))
	var loaded := 0
	for file in dir.get_files():
		if file.ends_with(".cty"):
			assert_true(engine.load_city("cities/" + file), file)
			loaded += 1
	assert_eq(loaded, 32)


func test_each_scenario_loads() -> void:
	for scenario: int in range(CityEngine.Scenario.DULLSVILLE, CityEngine.Scenario.RIO + 1):
		assert_true(engine.load_scenario(scenario), "scenario %d" % scenario)
		assert_eq(engine.get_scenario(), scenario)
		assert_eq(engine.get_city_name(), NewCityScreen.scenario_title(scenario))
		_run(engine, 100)
		assert_gt(engine.get_population(), 0, "scenario %d has people" % scenario)


# Sprites ------------------------------------------------------------------------

func _sprites_of(city: CityEngine, type: int) -> Array:
	return city.get_sprites().filter(func(sprite: Dictionary) -> bool: return sprite.type == type)


func test_a_tornado_is_a_sprite_that_moves() -> void:
	# With seed 1989 this tornado's first step is its 1-in-501 last, so another.
	engine.set_fixed_seed(7)
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	assert_eq(_sprites_of(engine, CityEngine.SpriteType.TORNADO), [])
	engine.make_tornado()
	var tornado: Dictionary = _sprites_of(engine, CityEngine.SpriteType.TORNADO)[0]
	for key in ["frame", "x", "y", "x_offset", "y_offset", "width", "height"]:
		assert_has(tornado, key)
	assert_between(tornado.frame, 1, 3, "the tornado has 3 frames")
	assert_eq([tornado.width, tornado.height], [48, 48])
	_run(engine, 20)
	var later: Array = _sprites_of(engine, CityEngine.SpriteType.TORNADO)
	assert_eq(later.size(), 1)
	assert_ne(Vector2i(later[0].x, later[0].y), Vector2i(tornado.x, tornado.y), "it moved")


func test_the_monster_is_a_sprite() -> void:
	engine.load_scenario(CityEngine.Scenario.TOKYO)
	engine.make_monster()
	var monster: Array = _sprites_of(engine, CityEngine.SpriteType.MONSTER)
	assert_eq(monster.size(), 1)
	assert_between(monster[0].frame, 1, 16)


# Local edit 12: as 1989's MakeMonster, a monster starts at the map's centre
# (60, 50), with its message 5 tiles east of it, once the engine's search for
# river water finds some.
func test_the_monster_appears_at_the_maps_centre() -> void:
	engine.load_scenario(CityEngine.Scenario.TOKYO)
	watch_signals(engine)
	engine.make_monster()
	var monster: Dictionary = _sprites_of(engine, CityEngine.SpriteType.MONSTER)[0]
	assert_eq(Vector2i(monster.x, monster.y), Vector2i(60 * 16 + 48, 50 * 16))
	assert_signal_emit_count(engine, "message_sent", 1, "one message, not one per place")
	assert_eq(get_signal_parameters(engine, "message_sent").slice(0, 3), [21, 65, 50])


# MicropolisCore made the monster on river water, where its first steps drowned
# it: 111 of these 160 monsters were gone within 10 ticks before edit 12.
func test_the_monster_survives_and_moves_in_most_runs() -> void:
	var runs := 0
	var alive := 0
	for scenario in range(CityEngine.Scenario.DULLSVILLE, CityEngine.Scenario.RIO + 1):
		for seed in 20:
			var city := _engine()
			city.set_fixed_seed(seed)
			city.load_scenario(scenario)
			city.make_monster()
			var start: Array = _sprites_of(city, CityEngine.SpriteType.MONSTER)
			if start.is_empty():
				continue
			runs += 1
			_run(city, 50)
			var later: Array = _sprites_of(city, CityEngine.SpriteType.MONSTER)
			if not later.is_empty() and Vector2i(later[0].x, later[0].y) != Vector2i(start[0].x, start[0].y):
				alive += 1
	gut.p("%d of %d monsters alive and moving after 50 ticks" % [alive, runs])
	assert_eq(runs, 160, "every scenario has river water for the search to find")
	assert_gt(alive, runs * 3 / 4, "most survive and move")


# Tokyo's scenario sets the monster off by itself, and it tramples the city.
func test_tokyos_monster_attack_rampages() -> void:
	engine.load_scenario(CityEngine.Scenario.TOKYO)
	var before := engine.get_map()
	var ticks := 0
	while _sprites_of(engine, CityEngine.SpriteType.MONSTER).is_empty() and ticks < 2000:
		engine.tick()
		ticks += 1
	assert_false(_sprites_of(engine, CityEngine.SpriteType.MONSTER).is_empty(), "the scenario made its monster")
	var trail := {}
	for i in 300:
		engine.tick()
		for monster: Dictionary in _sprites_of(engine, CityEngine.SpriteType.MONSTER):
			trail[Vector2i(monster.x, monster.y) / 16] = true
	var after := engine.get_map()
	var rubble := 0
	for i in after.size():
		var tile := after[i] & CityEngine.TILE_INDEX_MASK
		if after[i] != before[i] and tile >= 44 and tile <= 47:
			rubble += 1
	gut.p("Tokyo's monster came after %d ticks, crossed %d tiles and left %d rubble" % [ticks, trail.size(), rubble])
	assert_gt(trail.size(), 20, "it moves across the map")
	assert_gt(rubble, 10, "and leaves rubble behind")


# The engine never makes a bus: generateBus is commented out (simulate.cpp), as
# 1989 had no buses either. The layer would draw one from its images.
func test_every_sprite_type_has_its_images() -> void:
	var counts := {}
	for type: int in range(CityEngine.SpriteType.TRAIN, CityEngine.SpriteType.BUS + 1):
		counts[CityEngine.SpriteType.keys()[type]] = SpriteLayer.frame_count(type)
	assert_eq(counts, {TRAIN = 5, HELICOPTER = 8, AIRPLANE = 11, SHIP = 8, MONSTER = 16, TORNADO = 3,
		EXPLOSION = 6, BUS = 4})


func test_a_city_runs_trains_ships_planes_and_helicopters() -> void:
	# Tokyo has rail, a seaport and an airport.
	var seen := {}
	engine.load_scenario(CityEngine.Scenario.TOKYO)
	engine.set_disasters_enabled(false)
	for i in 3000:
		engine.tick()
		for sprite: Dictionary in engine.get_sprites():
			seen[sprite.type] = true
			var images: int = SpriteLayer.frame_count(sprite.type)
			assert_between(sprite.frame, 1, images, "a frame the content has an image for")
	for type: int in [CityEngine.SpriteType.TRAIN, CityEngine.SpriteType.HELICOPTER,
			CityEngine.SpriteType.AIRPLANE, CityEngine.SpriteType.SHIP]:
		assert_has(seen, type, CityEngine.SpriteType.keys()[type])


func test_a_load_clears_the_disasters_sprites() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_tornado()
	engine.make_monster()
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	assert_eq(_sprites_of(engine, CityEngine.SpriteType.TORNADO), [])
	assert_eq(_sprites_of(engine, CityEngine.SpriteType.MONSTER), [])


# Air Crash (local edit 9) ----------------------------------------------------------

func test_an_air_crash_explodes_a_plane_and_starts_fires() -> void:
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	engine.make_air_crash()
	assert_signal_emitted(engine, "message_sent")
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_eq(message[0], 24, "A plane has crashed !")
	assert_true(message[3], "with a picture")
	assert_eq(_sprites_of(engine, CityEngine.SpriteType.AIRPLANE), [], "the plane is gone")
	var explosion: Array = _sprites_of(engine, CityEngine.SpriteType.EXPLOSION)
	assert_eq(explosion.size(), 1, "an explosion where it was")
	var fires_before := _fires(engine)
	_run(engine, 40)
	assert_eq(_sprites_of(engine, CityEngine.SpriteType.EXPLOSION), [], "the explosion burns out")
	assert_gt(_fires(engine), fires_before, "and leaves fire")


func test_an_air_crash_takes_the_plane_in_the_air() -> void:
	engine.load_scenario(CityEngine.Scenario.TOKYO)
	engine.set_disasters_enabled(false)
	var plane := {}
	for i in 4000:
		engine.tick()
		var planes := _sprites_of(engine, CityEngine.SpriteType.AIRPLANE)
		if not planes.is_empty():
			plane = planes[0]
			break
	assert_false(plane.is_empty(), "a plane took off from Tokyo's airport")
	engine.make_air_crash()
	var message: Array = get_signal_parameters(engine, "message_sent")
	assert_eq(message[0], 24)
	var at := Vector2i((plane.x + 48) >> 4, (plane.y + 16) >> 4)
	assert_lt(Vector2(message[1], message[2]).distance_to(Vector2(at)), 4.0, "where the plane was")


## Burning tiles (FIRE to LASTFIRE, 56 to 63).
func _fires(city: CityEngine) -> int:
	var count := 0
	for value in city.get_map():
		var tile := value & CityEngine.TILE_INDEX_MASK
		count += int(tile >= 56 and tile <= 63)
	return count
