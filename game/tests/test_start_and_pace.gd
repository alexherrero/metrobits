# The start in the game window: it opens on the city chooser, as the OLPC did
# (its splash picture was never released); and the OLPC's Priority menu sets the loop's rate,
# so the sim, the sprites and the tile animation keep its pace together
#, with keys 0 to 3 on its levels.
extends GutTest

const MAIN := "res://main.gd"

var main: Control


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)


func after_each() -> void:
	load(MAIN).start_scenario = CityEngine.Scenario.DETROIT


func _main_from_the_start() -> Control:
	load(MAIN).start_scenario = CityEngine.Scenario.NONE
	var fresh: Control = load("res://main.tscn").instantiate()
	add_child_autofree(fresh)
	return fresh


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## Runs `seconds` of 60 fps frames; returns {loops, animation, sprite_moved,
## city_time}: the loops run, the animation frames stepped, how far the
## monster was seen to move, and how far the city's time went.
func _run(game: Control, seconds: float) -> Dictionary:
	var out := {loops = 0, animation = 0, sprite_moved = 0.0, city_time = 0}
	var time: int = game.engine.get_city_time()
	var steps: int = game.map_view.city_map.frames_stepped
	var last := Vector2.INF
	for frame in roundi(seconds * 60):
		game.advance(1.0 / 60.0)
		out.loops += game.last_loops
		var monster: Dictionary = game.map_view.sprites.find(CityEngine.SpriteType.MONSTER)
		if not monster.is_empty():
			var at := Vector2(monster.x, monster.y)
			if last != Vector2.INF:
				out.sprite_moved += at.distance_to(last)
			last = at
	out.animation = game.map_view.city_map.frames_stepped - steps
	out.city_time = game.engine.get_city_time() - time
	return out


# The start ------------------------------------------------------------------

func test_the_game_opens_on_the_chooser() -> void:
	var game := _main_from_the_start()
	assert_true(game.new_city_screen.visible, "the city chooser at once, as UIPickScenarioMode")
	assert_true(game.engine.is_paused(), "nothing runs behind it")
	assert_ne(game.engine.get_map().count(0), game.engine.get_map().size(), "with a map generated at once")
	assert_null(game.get_node_or_null("Splash"), "no splash")


func test_a_city_loaded_from_the_chooser_closes_it() -> void:
	var game := _main_from_the_start()
	game.load_scenario(CityEngine.Scenario.BERN)
	assert_false(game.new_city_screen.visible)
	assert_false(game.engine.is_paused())


func test_a_named_city_skips_the_chooser() -> void:
	assert_false(main.new_city_screen.visible, "the tests name Detroit (tests/pre_run.gd)")
	assert_eq(main.engine.get_city_name(), "Detroit")


# Priority -------------------------------------------------------------------

func test_the_priority_menu_is_the_olpcs() -> void:
	var menu: PopupMenu = main.priority_menu
	var labels := []
	for i in menu.item_count:
		labels.append(menu.get_item_text(i))
	assert_eq(labels, ["Super Fast", "Fast", "Normal", "Slow", "Super Slow", "Pause"])
	assert_true(menu.is_item_checked(menu.get_item_index(main.Priority.NORMAL)), "Normal at the start, as the OLPC")
	menu.id_pressed.emit(main.Priority.SUPER_SLOW)
	assert_eq(main.priority, main.Priority.SUPER_SLOW)
	assert_true(menu.is_item_checked(menu.get_item_index(main.Priority.SUPER_SLOW)))
	assert_false(menu.is_item_checked(menu.get_item_index(main.Priority.NORMAL)))
	menu.id_pressed.emit(main.PAUSE_ITEM)
	assert_true(main.engine.is_paused())
	assert_true(menu.is_item_checked(menu.get_item_index(main.PAUSE_ITEM)))
	assert_eq(main.message_label.text, "Time pauses.", "1989's message")
	assert_eq(main.head.priority_label.text, "Paused")
	menu.id_pressed.emit(main.PAUSE_ITEM)
	assert_false(main.engine.is_paused())
	assert_eq(main.message_label.text, "Time flows fast.")
	assert_eq(main.head.priority_label.text, "Priority: Super Slow")


func test_each_priority_runs_its_loops_a_second() -> void:
	for priority: int in [main.Priority.SUPER_SLOW, main.Priority.SLOW, main.Priority.NORMAL, main.Priority.FAST]:
		main.set_priority(priority)
		var loops: int = _run(main, 2.0).loops
		assert_almost_eq(loops, int(main.LOOPS_PER_SECOND[priority] * 2), 1,
			"%s: %d loops in 2 s" % [main.PRIORITY_NAMES[priority], loops])
	main.set_priority(main.Priority.SUPER_FAST)
	var fastest: int = _run(main, 0.5).loops
	assert_gt(fastest, int(main.LOOPS_PER_SECOND[main.Priority.FAST] / 2), "Super Fast outruns Fast")


func test_priority_changes_the_animation_and_sprites_with_the_sim() -> void:
	main.engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	main.engine.make_fire()
	main.trigger_disaster(main.DisasterItem.MONSTER)
	main.set_priority(main.Priority.SLOW)
	var slow := _run(main, 1.0)
	main.set_priority(main.Priority.FAST)
	var fast := _run(main, 1.0)
	gut.p("Slow %s; Fast %s" % [slow, fast])
	assert_almost_eq(slow.loops, 10, 1)
	assert_almost_eq(fast.loops, 200, 1, "20 times the loops")
	assert_eq(slow.animation, slow.loops, "a frame of animation per loop, as 1989's")
	assert_eq(fast.animation, fast.loops, "at every Priority")
	assert_gt(fast.sprite_moved, slow.sprite_moved * 5, "the monster keeps pace")
	assert_gt(fast.city_time, slow.city_time, "and so does the city's time")


func test_nothing_runs_or_animates_while_paused() -> void:
	main.set_paused(true)
	var paused := _run(main, 1.0)
	assert_eq([paused.loops, paused.animation, paused.city_time], [0, 0, 0])


func test_keys_0_to_3_map_onto_the_priority() -> void:
	main._unhandled_key_input(_key(KEY_1))
	assert_eq(main.priority, main.Priority.SLOW)
	main._unhandled_key_input(_key(KEY_3))
	assert_eq(main.priority, main.Priority.FAST)
	main._unhandled_key_input(_key(KEY_2))
	assert_eq(main.priority, main.Priority.NORMAL)
	main._unhandled_key_input(_key(KEY_0))
	assert_true(main.engine.is_paused())
	main._unhandled_key_input(_key(KEY_0))
	assert_false(main.engine.is_paused())
	var menu: PopupMenu = main.priority_menu
	assert_eq(menu.get_item_tooltip(menu.get_item_index(main.Priority.FAST)), "Key: 3")


func test_the_engine_stays_at_speed_3() -> void:
	for priority: int in main.Priority.values():
		main.set_priority(priority)
		assert_eq(main.engine.get_speed(), 3, "the OLPC ran the sim at speed 3 and paced the loop")


# The windows over the game stay out of the chooser, as the
# OLPC's WithdrawAll put them away, and the map comes with a city.
func test_the_map_window_waits_for_a_city() -> void:
	var game := _main_from_the_start()
	await wait_process_frames(2)
	assert_false(game.map_window.visible, "not over the chooser")
	game.new_city_screen.activate(NewCityScreen.scenario_button(CityEngine.Scenario.RIO))
	game.new_city_screen.activate("play")
	await wait_process_frames(2)
	assert_true(game.map_window.visible, "then it opens with the city")
	game.open_graph()
	game.open_city_chooser()
	assert_false(game.map_window.visible)
	assert_false(game.graph_window.visible)
