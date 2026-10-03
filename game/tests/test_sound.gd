# The sound: every sound the engine can ask for, and every one the 1989
# front end made, is a file in micropolis-core/content/sounds that loads and
# plays; the game plays them on the engine's signals and the player's actions
# as 1989 did; and Options, then Sound, turns them off, kept in settings.cfg.
# A headless test can't hear them, so it checks what's asked to play.
extends GutTest

var ENGINE := ProjectSettings.globalize_path("res://../micropolis-core/engine/").simplify_path() + "/"

var main: Control
var sounds: Sounds


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	main.engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)
	sounds = main.sounds
	sounds.played.clear()
	sounds._clear_frame()


## The names in the engine's sources passed as a call's second argument, e.g.
## makeSound("city", "Siren", ...).
func _names_in_engine(call: String) -> Array:
	var found := {}
	var pattern := RegEx.create_from_string(call + "\\(\\s*\"[^\"]*\",\\s*\"([^\"]+)\"")
	for file in DirAccess.get_files_at(ENGINE):
		if file.ends_with(".cpp") and file != "emscripten.cpp" and file != "callback.cpp":
			for m in pattern.search_all(FileAccess.get_file_as_string(ENGINE + file)):
				found[m.get_string(1)] = true
	var names := found.keys()
	names.sort()
	return names


func _names_played() -> Array:
	return sounds.played.map(func(play: Dictionary) -> String: return play.name)


func _loads(sound: String) -> bool:
	var file := Sounds.file_for(sound)
	var stream: AudioStream = null
	if file.begins_with("olpc/"):
		stream = Content.olpc_sound(file.get_file().get_basename())
	elif file != "":
		stream = Content.sound(file.get_file().get_basename())
	return stream != null and stream.get_length() > 0.0


# Every sound has a file ----------------------------------------------------------

func test_every_sound_the_engine_asks_for_has_a_file() -> void:
	var names := _names_in_engine("makeSound") + _names_in_engine("FrontendMessageMakeSound")
	var unique := {}
	for sound: String in names:
		unique[sound] = Sounds.file_for(sound)
	gut.p("engine sounds: %s" % unique)
	assert_eq(unique.keys().size(), 13, "the engine's 13 names: %s" % [unique.keys()])
	for sound: String in unique:
		assert_true(_loads(sound), "%s plays %s" % [sound, unique[sound]])


func test_every_tool_the_engine_reports_has_1989s_sound_or_had_none() -> void:
	var reported := []
	var pattern := RegEx.create_from_string("(?:FrontendMessageDidTool|didTool)\\(\"([^\"]+)\"")
	for m in pattern.search_all(FileAccess.get_file_as_string(ENGINE + "tool.cpp")):
		if not reported.has(m.get_string(1)):
			reported.append(m.get_string(1))
	var silent := []
	for tool_name: String in reported:
		if Sounds.DID_TOOL.has(tool_name):
			assert_true(_loads(Sounds.DID_TOOL[tool_name][0]), tool_name)
		elif tool_name != "buildingProps->toolName":
			silent.append(tool_name)
	silent.sort()
	assert_eq(silent, ["Forest", "Land", "Net", "Water"], "MicropolisCore's own tools, which 1989 didn't have")
	for tool_name: String in ["Res", "Com", "Ind", "Pol", "Fire", "Stad", "Coal", "Nuc", "Seap", "Airp"]:
		assert_has(Sounds.DID_TOOL, tool_name, "the buildings' names (tool.cpp's BuildingProperties)")


func test_every_palette_sound_has_a_file() -> void:
	var missing := []
	for tool: int in Sounds.PALETTE:
		if Sounds.file_for(Sounds.PALETTE[tool]) == "":
			missing.append(Sounds.PALETTE[tool])
	assert_eq(missing, [])
	# The content has no com.mp3 or nuclear.mp3: the OLPC's own WAVs play (F5).
	assert_eq(Sounds.file_for("Com"), "olpc/res/sounds/com.wav")
	assert_eq(Sounds.file_for("Nuclear"), "olpc/res/sounds/nuclear.wav")
	assert_eq(Sounds.file_for("Chalk"), "sounds/chalk.mp3", "the chalk and eraser's, from the content")
	assert_eq(Sounds.file_for("Eraser"), "sounds/eraser.mp3")
	main.palette.tool_selected.emit(CityEngine.Tool.COMMERCIAL)
	assert_eq(sounds.played.back().file, "olpc/res/sounds/com.wav", "Com plays")
	assert_true(sounds.played.size() > 0 and sounds._players.any(func(p: AudioStreamPlayer) -> bool:
		return p.stream is AudioStreamWAV), "as a WAV")


func test_the_front_ends_own_sounds_have_files() -> void:
	for sound in ["Boing", "Rumble", "Skid", "Sorry", "O", "A", "E"]:
		assert_true(_loads(sound), sound)
	assert_eq(Sounds.file_for("Explosion-High"), "olpc/res/sounds/explosion-high.wav",
		"the OLPC's own: MicropolisCore's ExplosionHigh.mp3 is another sound")
	assert_eq(Sounds.file_for("ExplosionHigh"), "olpc/res/sounds/explosion-high.wav", "the engine's other spelling")
	assert_eq(Sounds.file_for("Explosion-Low"), "sounds/ExplosionLow.mp3", "the engine's dashes dropped")
	assert_eq(Sounds.file_for("O"), "sounds/o.mp3", "the OLPC's lower-case files")
	assert_eq(Sounds.file_for("Nothing"), "")


# They play ------------------------------------------------------------------------

func test_a_sound_plays() -> void:
	assert_true(sounds.play("Siren"))
	assert_true(sounds.is_playing(), "a voice is sounding")
	assert_false(sounds.play("Siren"), "not twice in one frame")
	assert_true(sounds.play("Monster"), "but another does")
	await wait_process_frames(1)
	assert_true(sounds.play("Siren"), "and again next frame")


func test_a_disasters_message_plays_its_sound() -> void:
	main.trigger_disaster(main.DisasterItem.TORNADO)
	assert_has(_names_played(), "Siren", "the tornado's message")
	sounds._clear_frame()
	main.trigger_disaster(main.DisasterItem.MONSTER)
	assert_has(_names_played(), "Monster")


func test_building_plays_1989s_tool_sound_at_its_speed() -> void:
	var engine: CityEngine = main.engine
	engine.set_funds(100000)
	var site := Vector2i(-1, -1)
	for y in range(5, 90):
		for x in range(5, 110):
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					clear = clear and engine.get_tile(x + dx, y + dy) & CityEngine.TILE_INDEX_MASK == 0
			if clear and site.x < 0:
				site = Vector2i(x, y)
	main.select_tool(CityEngine.Tool.RESIDENTIAL)
	main.map_view.click_tile(site)
	var play: Dictionary = sounds.played.back()
	assert_eq([play.name, play.file, play.volume], ["O", "sounds/o.mp3", 100], "UIDidToolRes: O")
	assert_eq([play.speed, play.pitch], [140, 1.0], "1989's -speed 140, played at its own pitch, as the OLPC did")
	sounds._clear_frame()
	main.select_tool(CityEngine.Tool.BULLDOZER)
	main.map_view.click_tile(site)
	assert_has(_names_played(), "Rumble", "the bulldozer going down")
	assert_has(_names_played(), "Explosion-High", "the engine's explosion for a 3x3 zone")


func test_a_failed_tool_plays_the_engines_sound() -> void:
	main.engine.set_funds(0)
	main.select_tool(CityEngine.Tool.ROAD)
	main.map_view.click_tile(Vector2i(5, 5))
	assert_has(_names_played(), "Sorry")


func test_picking_from_the_palette_says_the_tool() -> void:
	main.palette.tool_selected.emit(CityEngine.Tool.ROAD)
	assert_eq(_names_played(), ["Road"])
	sounds._clear_frame()
	main._unhandled_key_input(_key(KEY_P))
	assert_eq(_names_played(), ["Road"], "a key picks quietly, as 1989's did")


func test_pausing_and_the_budget_boing() -> void:
	main.toggle_pause()
	assert_eq(sounds.played.back().name, "Boing")
	assert_eq([sounds.played.back().speed, sounds.played.back().pitch], [90, 1.0], "-speed 90, unpitched")
	sounds._clear_frame()
	main.toggle_pause()
	assert_eq([sounds.played.back().speed, sounds.played.back().pitch], [130, 1.0], "-speed 130, unpitched")


func test_auto_goto_skids_to_a_stop() -> void:
	main.engine.set_auto_goto(true)
	main.map_view.center_on_tile(Vector2i(5, 5))
	var is_skid := func(play: Dictionary) -> bool: return play.name == "Skid"
	main.trigger_disaster(main.DisasterItem.FIRE)
	assert_true(main.map_view.is_gliding())
	assert_eq(sounds.played.filter(is_skid).size(), 0, "not while it glides")
	for frame in 600:
		if not main.map_view.is_gliding():
			break
		sounds._clear_frame()
		main.advance(1.0 / 60.0)
	var skid: Array = sounds.played.filter(is_skid)
	assert_eq(skid.size(), 1, "once, when it stops")
	assert_eq([skid[0].volume, skid[0].db], [25, 0.0], "UIDidStopPan asked for volume 25; it plays at full")


func test_sound_can_be_turned_off_and_stays_off() -> void:
	var menu: PopupMenu = main.options_menu
	assert_true(menu.is_item_checked(menu.get_item_index(main.OptionItem.SOUND)), "on at the start, as in 1989")
	menu.id_pressed.emit(main.OptionItem.SOUND)
	assert_false(sounds.enabled)
	assert_false(main.settings.sound, "kept in settings.cfg")
	assert_false(menu.is_item_checked(menu.get_item_index(main.OptionItem.SOUND)))
	main.trigger_disaster(main.DisasterItem.TORNADO)
	main.toggle_pause()
	assert_eq(sounds.played, [], "nothing plays")
	assert_false(sounds.is_playing())
	menu.id_pressed.emit(main.OptionItem.SOUND)
	assert_true(sounds.play("Siren"))


func test_the_setting_is_read_at_start() -> void:
	const FILE := "user://test_sound_settings.cfg"
	var settings := Settings.new(FILE)
	settings.sound = false
	var game: Control = load("res://main.tscn").instantiate()
	game.settings_path = FILE
	add_child_autofree(game)
	assert_false(game.sounds.enabled, "off, as the file says")
	var menu: PopupMenu = game.options_menu
	assert_false(menu.is_item_checked(menu.get_item_index(game.OptionItem.SOUND)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	assert_true(Settings.new("").sound, "a fresh file defaults to on")


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_a_ships_horn_is_honkhonk_low() -> void:
	main.engine.sound_requested.emit("city", "FogHornLow", 10, 10)
	assert_eq(sounds.played.back().name, "HonkHonkLow", "as the OLPC heard San Francisco's ships")
	sounds._clear_frame()
	main.engine.sound_requested.emit("city", "HonkHonkLow", 10, 10)
	assert_eq(sounds.played.back().name, "HonkHonkLow")


func test_no_sound_is_pitched() -> void:
	for i in 20:
		sounds._clear_frame()
		sounds.play("O", 50 + i * 10)
	for player in sounds._players:
		assert_eq(player.pitch_scale, 1.0)


func test_no_sound_is_quieter() -> void:
	for volume in [25, 40, 85, 100]:
		sounds._clear_frame()
		sounds.play("Boing", 100, volume)
		assert_eq(sounds.played.back().db, 0.0, "asked for %d, played at full volume, as the OLPC did" % volume)
	for player in sounds._players:
		assert_eq(player.volume_db, 0.0)
