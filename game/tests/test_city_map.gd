# The tile map mirrors the engine's map with the original's tiles (the OLPC
# art), redraws only what changed, and steps animated
# tiles along the engine's animation table.
extends GutTest

var engine: CityEngine
var city_map: CityMap


func before_each() -> void:
	engine = MicropolisCityEngine.new()
	engine.set_fixed_seed(1989)
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	city_map = CityMap.new()
	add_child_autofree(city_map)
	city_map.setup(engine)


func _drawn_tile(x: int, y: int) -> int:
	var coords := city_map.get_cell_atlas_coords(Vector2i(x, y))
	return coords.y * (city_map.tiles.get_width() / CityMap.TILE_SIZE) + coords.x


func _assert_map_matches_engine() -> void:
	var mismatches := 0
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			var tile := engine.get_tile(x, y) & CityEngine.TILE_INDEX_MASK
			if city_map.get_cell_source_id(Vector2i(x, y)) != CityMap.SOURCE_ID or _drawn_tile(x, y) != tile:
				mismatches += 1
	assert_eq(mismatches, 0, "every cell shows the engine's tile")


func test_the_default_tile_set_is_the_olpc_art_cut_into_16_pixel_tiles() -> void:
	var atlas := city_map.tile_set.get_source(CityMap.SOURCE_ID) as TileSetAtlasSource
	assert_eq(city_map.tile_set.tile_size, Vector2i(16, 16))
	assert_eq(atlas.get_atlas_grid_size(), Vector2i(16, 60))
	assert_eq(atlas.get_tiles_count(), 960)


## The drawn cell's pixels, from the atlas, and the tile's pixels in `image`.
func _pixels_drawn(map: CityMap, cell: Vector2i) -> Image:
	var atlas := map.tile_set.get_source(CityMap.SOURCE_ID) as TileSetAtlasSource
	var region := atlas.get_tile_texture_region(map.get_cell_atlas_coords(cell))
	return atlas.texture.get_image().get_region(region)


func _tile_pixels(image: Image, tile: int) -> Image:
	var columns := image.get_width() / CityMap.TILE_SIZE
	return image.get_region(Rect2i(Vector2i(tile % columns, tile / columns) * CityMap.TILE_SIZE,
		Vector2i(CityMap.TILE_SIZE, CityMap.TILE_SIZE)))


func test_the_tile_art_draws_each_cell_with_its_own_tile() -> void:
	var image := CityMap.load_tiles()
	city_map.set_tiles(image)
	assert_eq(image.get_width() / 16 * image.get_height() / 16, 960, "all 960 tiles")
	_assert_map_matches_engine()
	var wrong := 0
	for cell: Vector2i in [Vector2i(60, 50), Vector2i(0, 0), Vector2i(64, 40), Vector2i(90, 70), Vector2i(119, 99)]:
		var tile := engine.get_tile(cell.x, cell.y) & CityEngine.TILE_INDEX_MASK
		var drawn := _pixels_drawn(city_map, cell)
		drawn.convert(Image.FORMAT_RGBA8)
		var wanted := _tile_pixels(image, tile)
		wanted.convert(Image.FORMAT_RGBA8)
		if drawn.get_data() != wanted.get_data():
			wrong += 1
	assert_eq(wrong, 0, "the right pixels")
	var dirt := _tile_pixels(image, 0).get_pixel(8, 8)
	assert_gt(dirt.r, dirt.g, "OLPC dirt is brown: %s" % dirt)


func test_every_cell_shows_the_engines_tile() -> void:
	_assert_map_matches_engine()


func test_sync_redraws_only_what_changed() -> void:
	assert_eq(city_map.sync(), 0, "nothing changed yet")
	engine.set_funds(100000)
	var dirt := Vector2i(-1, -1)
	for i in CityEngine.MAP_WIDTH * CityEngine.MAP_HEIGHT:
		if engine.get_map()[i] == 0:
			dirt = Vector2i(i % CityEngine.MAP_WIDTH, i / CityEngine.MAP_WIDTH)
			break
	assert_eq(engine.do_tool(CityEngine.Tool.ROAD, dirt.x, dirt.y), CityEngine.ToolResult.OK)
	assert_between(city_map.sync(), 1, 5, "the road and the neighbours it joins")
	assert_eq(city_map.sync(), 0)
	_assert_map_matches_engine()


func test_the_map_follows_the_sim() -> void:
	for i in 300:
		engine.tick()
	assert_gt(city_map.sync(), 0, "the city grew or animated in the engine")
	_assert_map_matches_engine()


func test_animated_tiles_step_along_the_engines_table() -> void:
	engine.make_fire()
	for i in 50:
		engine.tick()
	city_map.sync()
	var table := engine.get_animation_table()
	var animated := []
	var still := Vector2i(-1, -1)
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			var value := engine.get_tile(x, y)
			var tile := value & CityEngine.TILE_INDEX_MASK
			if value & CityEngine.TILE_ANIM_BIT and table[tile] != tile:
				animated.append(Vector2i(x, y))
			elif still == Vector2i(-1, -1) and table[tile] == tile:
				still = Vector2i(x, y)
	assert_gt(animated.size(), 0, "Detroit has animated tiles (traffic, fire)")
	var before := {}
	for cell: Vector2i in animated:
		before[cell] = city_map.shown_tile(cell.x, cell.y)
	var still_tile := city_map.shown_tile(still.x, still.y)
	assert_gt(city_map.animate(), 0)
	for cell: Vector2i in animated:
		assert_eq(city_map.shown_tile(cell.x, cell.y), table[before[cell]], "cell %s" % cell)
		assert_eq(_drawn_tile(cell.x, cell.y), table[before[cell]])
	assert_eq(city_map.shown_tile(still.x, still.y), still_tile, "a still tile stays")
	assert_eq(city_map.sync(), 0, "animating doesn't touch the engine's map")


func test_a_changed_engine_tile_replaces_the_animation_frame() -> void:
	for i in 300:
		engine.tick()
	city_map.sync()
	# An animated tile the bulldozer can clear: a road with traffic on it.
	var table := engine.get_animation_table()
	var cell := Vector2i(-1, -1)
	for y in CityEngine.MAP_HEIGHT:
		for x in CityEngine.MAP_WIDTH:
			var value := engine.get_tile(x, y)
			var tile := value & CityEngine.TILE_INDEX_MASK
			if value & CityEngine.TILE_ANIM_BIT and value & CityEngine.TILE_BULLDOZABLE_BIT \
					and not value & CityEngine.TILE_ZONE_BIT and table[tile] != tile:
				cell = Vector2i(x, y)
	assert_ne(cell, Vector2i(-1, -1), "Detroit has traffic")
	city_map.animate()
	assert_ne(city_map.shown_tile(cell.x, cell.y), engine.get_tile(cell.x, cell.y) & CityEngine.TILE_INDEX_MASK,
		"showing a later frame than the engine's")
	engine.set_funds(100000)
	engine.do_tool(CityEngine.Tool.BULLDOZER, cell.x, cell.y)
	city_map.sync()
	assert_eq(city_map.shown_tile(cell.x, cell.y), engine.get_tile(cell.x, cell.y) & CityEngine.TILE_INDEX_MASK)


func test_tiles_past_the_art_show_as_dirt() -> void:
	assert_eq(city_map.atlas_coords(0), Vector2i(0, 0))
	assert_eq(city_map.atlas_coords(33), Vector2i(1, 2))
	assert_eq(city_map.atlas_coords(959), Vector2i(15, 59))
	assert_eq(city_map.atlas_coords(1000), Vector2i(0, 0))


