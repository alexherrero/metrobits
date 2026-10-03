# Pan and zoom by mouse, trackpad and keyboard, and the camera stays on the map.
extends GutTest

var engine: CityEngine
var view: MapView


func before_each() -> void:
	engine = MicropolisCityEngine.new()
	engine.set_fixed_seed(1989)
	engine.load_scenario(CityEngine.Scenario.DETROIT)
	view = MapView.new()
	view.size = Vector2(800, 600)
	add_child_autofree(view)
	view.setup(engine)


func _button(button: MouseButton, pressed: bool, at := Vector2(400, 300), factor := 1.0) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.factor = factor
	return event


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func test_it_starts_on_the_middle_of_the_map_at_zoom_1() -> void:
	assert_eq(view.get_zoom(), 1.0)
	assert_eq(view.tile_at(view.size / 2.0), Vector2i(60, 50))


func test_screen_and_world_points_round_trip() -> void:
	view.zoom_at(1.7, Vector2(100, 100))
	var world := view.screen_to_world(Vector2(123, 456))
	assert_almost_eq(view.world_to_screen(world), Vector2(123, 456), Vector2(0.001, 0.001))


func test_the_map_is_drawn_where_the_camera_says() -> void:
	# The tile at the centre of the view is drawn at the centre of the view.
	var tile := view.tile_at(view.size / 2.0)
	var drawn_at := view.world.transform * (Vector2(tile) * CityMap.TILE_SIZE)
	assert_almost_eq(drawn_at, view.world_to_screen(Vector2(tile) * CityMap.TILE_SIZE), Vector2(0.001, 0.001))


func test_panning_moves_the_map_with_the_pointer() -> void:
	var before := view.camera_position
	view.pan_by_screen(Vector2(100, -50))
	assert_eq(view.camera_position, before + Vector2(-100, 50))


func test_the_view_stops_at_the_map_edges() -> void:
	view.pan_by_screen(Vector2(100000, 100000))
	assert_eq(view.visible_world_rect().position, Vector2.ZERO, "top-left corner")
	view.pan_by_screen(Vector2(-100000, -100000))
	assert_eq(view.visible_world_rect().end, view.map_size(), "bottom-right corner")


func test_zooming_keeps_the_point_under_the_pointer() -> void:
	var pointer := Vector2(250, 180)
	var under := view.screen_to_world(pointer)
	view.zoom_at(2.0, pointer)
	assert_eq(view.get_zoom(), 2.0)
	assert_almost_eq(view.screen_to_world(pointer), under, Vector2(0.01, 0.01))


func test_zoom_is_limited() -> void:
	view.zoom_at(100.0, Vector2.ZERO)
	assert_eq(view.get_zoom(), MapView.MAX_ZOOM)
	view.zoom_at(0.0001, Vector2.ZERO)
	assert_eq(view.get_zoom(), MapView.MIN_ZOOM)


func test_a_map_smaller_than_the_view_is_centred() -> void:
	view.zoom_at(0.0001, Vector2.ZERO)
	assert_eq(view.camera_position, view.map_size() / 2.0)


func test_the_wheel_zooms_in_and_out() -> void:
	view._gui_input(_button(MOUSE_BUTTON_WHEEL_UP, true))
	assert_almost_eq(view.get_zoom(), MapView.WHEEL_ZOOM, 0.0001)
	view._gui_input(_button(MOUSE_BUTTON_WHEEL_DOWN, true))
	view._gui_input(_button(MOUSE_BUTTON_WHEEL_DOWN, true))
	assert_almost_eq(view.get_zoom(), 1.0 / MapView.WHEEL_ZOOM, 0.0001)


func test_a_middle_drag_pans() -> void:
	# The right button opens the pie menus now (F6).
	for button: MouseButton in [MOUSE_BUTTON_MIDDLE]:
		var before := view.camera_position
		view._gui_input(_button(button, true))
		view._gui_input(_motion(Vector2(30, 20)))
		view._gui_input(_button(button, false))
		view._gui_input(_motion(Vector2(30, 20)))
		assert_eq(view.camera_position, before - Vector2(30, 20), "button %d" % button)


func test_space_and_a_left_drag_pans() -> void:
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	var before := view.camera_position
	view._gui_input(_motion(Vector2(40, 0)))
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true))
	view._gui_input(_motion(Vector2(40, 0)))
	assert_eq(view.camera_position, before, "a left drag alone doesn't pan")
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false))
	view._gui_input(space)
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true))
	view._gui_input(_motion(Vector2(40, 0)))
	assert_eq(view.camera_position, before - Vector2(40, 0))


func test_a_trackpad_scroll_pans_and_a_pinch_zooms() -> void:
	var before := view.camera_position
	var scroll := InputEventPanGesture.new()
	scroll.delta = Vector2(2, 1)
	view._gui_input(scroll)
	assert_eq(view.camera_position, before + Vector2(2, 1) * MapView.TRACKPAD_PAN)
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.5
	pinch.position = Vector2(400, 300)
	view._gui_input(pinch)
	assert_almost_eq(view.get_zoom(), 1.5, 0.0001)


func test_arrow_keys_pan() -> void:
	view.grab_focus()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	Input.flush_buffered_events()
	var before := view.camera_position
	view._process(0.1)
	var release := right.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert_almost_eq(view.camera_position.x, before.x + MapView.KEY_PAN_SPEED * 0.1, 0.01)
	assert_eq(view.camera_position.y, before.y)


# 1989's edge auto-scroll: a drag held at the view's edge scrolls 16
# points every 10 ms, toward the edge for a tool, the other way for a pan.
func test_a_tool_drag_at_the_edge_scrolls_and_paints_on() -> void:
	engine.set_funds(100000)
	view.tool = CityEngine.Tool.ROAD
	var edge := Vector2(view.size.x - 4, 300)
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true, edge))
	var start := view.tile_at(edge)
	var before := view.camera_position
	assert_eq(view.auto_scroll(edge, 0.03), 3, "three 10 ms steps")
	assert_eq(view.camera_position, before + Vector2(3 * MapView.AUTO_SCROLL_STEP, 0))
	var now := view.tile_at(edge)
	assert_gt(now.x, start.x, "the pointer is over a tile further east")
	for x in range(start.x, now.x + 1):
		# Road tiles run from 64 (ROADBASE) to 206 (LASTROAD), crossings included.
		assert_between(engine.get_tile(x, start.y) & CityEngine.TILE_INDEX_MASK, 64, 206,
			"road painted on to the tile under the pointer (%d)" % x)
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false, edge))
	assert_eq(view.auto_scroll(edge, 0.03), 0, "not after the button comes up")


func test_a_pan_drag_at_the_edge_scrolls_the_other_way() -> void:
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, true, Vector2(400, 300)))
	var before := view.camera_position
	assert_eq(view.auto_scroll(Vector2(3, 3), 0.01), 1)
	assert_eq(view.camera_position, before + Vector2(1, 1) * MapView.AUTO_SCROLL_STEP,
		"pointer at the top-left: the map keeps coming with it")
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, false, Vector2(3, 3)))


func test_no_scroll_inside_the_edge_or_without_a_drag() -> void:
	var before := view.camera_position
	assert_eq(view.auto_scroll(Vector2(view.size.x - 4, 300), 0.1), 0, "no drag")
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, true, Vector2(400, 300)))
	assert_eq(view.auto_scroll(Vector2(view.size.x - MapView.AUTO_SCROLL_EDGE - 1, 300), 0.1), 0,
		"just inside the edge")
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, false, Vector2(400, 300)))
	assert_eq(view.camera_position, before)


func test_the_scroll_is_in_screen_points_at_any_zoom() -> void:
	view.zoom_at(2.0, view.size / 2.0)
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, true, Vector2(400, 300)))
	var before := view.camera_position
	view.auto_scroll(Vector2(view.size.x - 1, 300), 0.01)
	assert_eq(view.camera_position, before - Vector2(MapView.AUTO_SCROLL_STEP / 2.0, 0))
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, false, Vector2(400, 300)))


# 1989's auto-goto glide (w_editor.c's HandleAutoGoto): 75 map pixels a
# step, eased in over the first five, landing on the place's centre with
# DidStopPan; nothing for a place within 64 pixels; no steps while a drag is
# held.
func test_a_glide_eases_in_then_runs_at_75_pixels_a_step() -> void:
	view.center_on_tile(Vector2i(30, 50))
	var start := view.camera_position
	assert_true(view.glide_to_tile(Vector2i(100, 50)), "70 tiles away: it goes")
	var moved: Array[float] = []
	var last := start
	for i in 7:
		assert_eq(view.glide(1), 1)
		moved.append(view.camera_position.x - last.x)
		last = view.camera_position
	assert_eq(moved, [15.0, 30.0, 45.0, 60.0, 75.0, 75.0, 75.0] as Array[float],
		"a fifth of the speed more each step, then the speed")
	assert_eq(view.camera_position.y, start.y, "straight at it")


func test_a_glide_lands_on_the_place_and_says_so_once() -> void:
	watch_signals(view)
	view.center_on_tile(Vector2i(20, 20))
	view.glide_to_tile(Vector2i(50, 70))
	var steps := 0
	while view.is_gliding() and steps < 100:
		steps += view.glide(1)
		if view.is_gliding():
			assert_signal_not_emitted(view, "glide_stopped", "not before it lands")
	assert_false(view.is_gliding())
	assert_eq(view.tile_at(view.size / 2.0), Vector2i(50, 70), "centred on the place")
	assert_eq(view.camera_position, (Vector2(50, 70) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE)
	assert_signal_emit_count(view, "glide_stopped", 1)
	# From (400, 328), where the view stops at the map's left edge, it's 898 map
	# pixels: 150 in the first four steps, nine of 75, and the landing.
	assert_eq(steps, 14)
	assert_eq(view.glide(5), 0, "nothing more to do")


func test_a_place_within_four_tiles_isnt_glided_to() -> void:
	watch_signals(view)
	view.center_on_tile(Vector2i(60, 50))
	var before := view.camera_position
	assert_false(view.glide_to_tile(Vector2i(63, 52)), "64 map pixels or less: AutoGoal stays put")
	assert_eq(view.glide(10), 0)
	assert_eq(view.camera_position, before)
	assert_signal_not_emitted(view, "glide_stopped", "and no Skid")


func test_a_glide_waits_while_a_drag_is_held() -> void:
	view.center_on_tile(Vector2i(20, 50))
	view.glide_to_tile(Vector2i(100, 50))
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, true))
	var held := view.camera_position
	assert_eq(view.glide(3), 0, "a pan drag (tool mode -1)")
	assert_eq(view.camera_position, held)
	view._gui_input(_button(MOUSE_BUTTON_MIDDLE, false))
	engine.set_funds(100000)
	view.tool = CityEngine.Tool.ROAD
	view._gui_input(_button(MOUSE_BUTTON_LEFT, true))
	assert_eq(view.glide(3), 0, "a tool drag (tool mode 1)")
	view._gui_input(_button(MOUSE_BUTTON_LEFT, false))
	assert_eq(view.glide(3), 3, "then it carries on")
	assert_true(view.is_gliding())


func test_a_glide_to_the_edge_stops_where_the_view_can_go() -> void:
	watch_signals(view)
	view.center_on_tile(Vector2i(60, 50))
	view.glide_to_tile(Vector2i(0, 0))
	var steps := 0
	while view.is_gliding() and steps < 100:
		steps += view.glide(1)
	assert_lt(steps, 100, "it ends")
	assert_eq(view.camera_position, view.size / 2.0, "the corner as far as the view shows it")
	assert_signal_emit_count(view, "glide_stopped", 1)


func test_a_new_place_starts_the_glide_afresh() -> void:
	view.center_on_tile(Vector2i(20, 50))
	view.glide_to_tile(Vector2i(100, 50))
	view.glide(6)
	var at := view.camera_position
	view.glide_to_tile(Vector2i(100, 10))
	view.glide(1)
	assert_almost_eq(view.camera_position.distance_to(at), 15.0, 1.0, "eased in again")
	view.stop_glide()
	assert_false(view.is_gliding())
	assert_eq(view.glide(1), 0)
