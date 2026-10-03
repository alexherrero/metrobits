# The OLPC's own images, sounds and fonts, imported from
# micropolis-activity into micropolis-core/olpc, each listed in
# PROVENANCE.md; the XPM loader that reads the images at runtime; and the
# originals in use where 1.9 drew stand-ins: the graph window's switches, the
# map's legends and small tiles, and the font and Tk's bevels.
extends GutTest

var main: Control


func before_each() -> void:
	main = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	main.engine.set_fixed_seed(1989)
	main.load_scenario(CityEngine.Scenario.DETROIT)


## PROVENANCE.md's file table: {path: sha256}; the licence it wrote has "–".
func _provenance() -> Dictionary:
	var rows := {}
	var text := FileAccess.get_file_as_string(Content.olpc_path("PROVENANCE.md"))
	for line in text.split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells := line.split("|")
		rows[cells[1].strip_edges().trim_prefix("`").trim_suffix("`")] = cells[3].strip_edges().trim_prefix("`").trim_suffix("`")
	return rows


## Every file under folder, hidden ones too, as paths relative to it.
func _files(folder: String, prefix := "") -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	dir.include_hidden = true
	for file in dir.get_files():
		out.append(prefix + file)
	for sub in dir.get_directories():
		out.append_array(_files(folder.path_join(sub), prefix + sub + "/"))
	return out


# The files and their provenance ------------------------------------------------

func test_every_file_is_listed_with_its_hash_and_nothing_else_is_there() -> void:
	var rows := _provenance()
	assert_eq(rows.size(), 83, "53 images, 3 sounds, 21 fonts and 3 font files, the README, the licence, .gitattributes")
	var present := _files(Content.olpc_path(""))
	present.erase("PROVENANCE.md")
	present.sort()
	var listed: Array = rows.keys()
	listed.sort()
	assert_eq(present, listed, "the folder holds exactly what PROVENANCE.md lists")
	var changed := []
	for path: String in rows:
		if rows[path] != "–" and FileAccess.get_sha256(Content.olpc_path(path)) != rows[path]:
			changed.append(path)
	assert_eq(changed, [], "each file is the original, byte for byte")


func test_the_named_images_are_all_there() -> void:
	var names := ["background-micropolis", "demandg", "micropoliss", "micropolisg", "tilessm", "key2city",
		"legendmm", "legendpm", "legendn", "playhilite", "lefthilite", "leftdisabled", "righthilite",
		"rightdisabled"]
	for i in range(1, 5):
		names.append("button%dhilite" % i)
	for i in range(1, 4):
		for state in ["hilite", "checked", "hilitechecked"]:
			names.append("checkbox%d%s" % [i, state])
	for i in range(1, 9):
		names.append("scenario%dhilite" % i)
	for graph in ["res", "com", "ind", "mony", "crim", "poll", "10", "120"]:
		names.append("gr" + graph)
		names.append("gr%shi" % graph)
	assert_eq(names.size(), 51)
	for image_name in names:
		assert_true(FileAccess.file_exists(Content.olpc_path("images/%s.xpm" % image_name)), image_name)


func test_nothing_in_the_olpc_folder_is_imported() -> void:
	var project := ProjectSettings.globalize_path("res://").simplify_path()
	assert_false(Content.olpc_path("").begins_with(project), "outside the Godot project")
	assert_eq(_files(Content.olpc_path("")).filter(func(f: String) -> bool: return f.ends_with(".import")), [])


# The XPM loader ------------------------------------------------------------------

func test_every_image_loads_at_the_size_its_header_gives() -> void:
	for file in DirAccess.get_files_at(Content.olpc_path("images")):
		var text := FileAccess.get_file_as_string(Content.olpc_path("images/" + file))
		var header := RegEx.create_from_string("\"(\\d+) (\\d+) \\d+ \\d+").search(text)
		var image := Content.olpc_image(file.get_basename())
		assert_not_null(image, file)
		if image:
			assert_eq(image.get_size(), Vector2i(header.get_string(1).to_int(), header.get_string(2).to_int()), file)
	assert_eq(Content.olpc_image("background-micropolis").get_size(), Vector2i(1200, 900), "the chooser's screen")


func test_one_character_pixels() -> void:
	var image := Xpm.parse("/* XPM */\nstatic char *x[] = {\n\"3 2 3 1\",\n\"a c #FF0000\",\n\". c None\",\n" +
		"\"b\tc #00FF00 m #000000\",\n\"a.b\",\n\"bba\"\n};\n")
	assert_eq(image.get_size(), Vector2i(3, 2))
	assert_eq(image.get_pixel(0, 0), Color.RED)
	assert_eq(image.get_pixel(1, 0).a, 0.0, "None is transparent")
	assert_eq(image.get_pixel(2, 0), Color("#00ff00"), "a tab after the characters; c before m")
	assert_eq(image.get_pixel(2, 1), Color.RED)


func test_two_character_pixels_and_sixteen_bit_colours() -> void:
	var image := Xpm.parse("\"2 1 2 2\",\n\"  c #CCCC7F7F6666\",\n\"a. m #FFFFFF\",\n\"  a.\"")
	assert_eq(image.get_pixel(0, 0).to_html(false), "cc7f66", "a space is a pixel's character; 16 bits a channel")
	assert_eq(image.get_pixel(1, 0), Color.WHITE, "only a mono colour: it's used")


func test_the_colours_come_out_as_the_file_gives_them() -> void:
	# demandg.xpm's five colours: black, #007F00, #FF0000, white, #CFCFCF.
	var image := Content.olpc_image("demandg")
	var colours := {}
	for y in image.get_height():
		for x in image.get_width():
			colours[image.get_pixel(x, y).to_html(false)] = true
	var found := colours.keys()
	found.sort()
	assert_eq(found, ["000000", "007f00", "cfcfcf", "ff0000", "ffffff"])


func test_what_isnt_xpm_gives_null() -> void:
	assert_null(Xpm.parse(""))
	assert_null(Xpm.parse("\"1 1 1 1\""), "no colours or pixels")
	assert_null(Xpm.parse("\"1 1 1 1\",\n\"a c #000000\",\n\"b\""), "a pixel with no colour")
	assert_null(Xpm.load_file("/no/such/file.xpm"))
	assert_null(Content.olpc_texture("no_such_image"))


func test_textures_are_cached() -> void:
	assert_same(Content.olpc_texture("grres"), Content.olpc_texture("grres"))


# Sounds and the font ---------------------------------------------------------------

func test_com_and_nuclear_load_as_wavs() -> void:
	for sound in ["Com", "Nuclear"]:
		var stream := Content.olpc_sound(sound)
		assert_true(stream is AudioStreamWAV, sound)
		assert_gt(stream.get_length(), 0.1, sound)
	assert_null(Content.olpc_sound("NoSuchSound"))


func test_the_ui_uses_dejavu_lgc_sans_at_the_xos_sizes() -> void:
	var font := Content.olpc_font()
	assert_eq(font.get_font_name(), "DejaVu LGC Sans")
	assert_same(main.theme.default_font, font)
	assert_same(main.message_label.get_theme_font("font"), font, "the editor's message line")
	assert_same(main.graph_window.graph.get_theme_font("font", "Label"), font, "a window's text")
	# FontInfo's points, doubled by fonts.alias: 9, 8, 7 and 6 points.
	assert_eq([ClassicTheme.BIG, ClassicTheme.LARGE, ClassicTheme.MEDIUM, ClassicTheme.SMALL], [18, 16, 14, 12])
	assert_eq(main.theme.default_font_size, 14, "Medium")
	assert_eq(main.message_label.get_theme_font_size("font_size"), 16, "the message line is Large")
	assert_eq(main.graph_window.graph.font_size, 12, "the graph is Small")


func test_the_font_is_drawn_smoothed() -> void:
	var font := Content.olpc_font()
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_GRAY, "antialiased, as chosen")
	assert_eq(font.hinting, TextServer.HINTING_LIGHT)


func test_tks_colours_and_bevels() -> void:
	assert_eq(ClassicTheme.BACKGROUND, Color("#b0b0b0"), "*background")
	assert_eq(ClassicTheme.ACTIVE, Color("#d0d0d0"), "*activeBackground")
	# tk3d.c: light is 14/10 of the background, dark 60/100.
	assert_eq(TkBorder.light(ClassicTheme.BACKGROUND).to_html(false), "f6f6f6")
	assert_eq(TkBorder.dark(ClassicTheme.BACKGROUND).to_html(false), "6a6a6a")
	assert_eq(TkBorder.light(Color("#d0d0d0")), Color.WHITE, "capped at white")
	var button: StyleBox = main.theme.get_stylebox("normal", "Button")
	assert_true(button is TkBorder)
	assert_eq([button.relief, button.width], [TkBorder.Relief.RAISED, 2], "Tk's buttons: raised, 2 pixels")
	var pressed: TkBorder = main.theme.get_stylebox("pressed", "Button")
	assert_eq([pressed.relief, pressed.background], [TkBorder.Relief.SUNKEN, ClassicTheme.ACTIVE])
	assert_eq(pressed.shades(), [TkBorder.dark(ClassicTheme.ACTIVE), TkBorder.light(ClassicTheme.ACTIVE)],
		"sunken: dark on top and left")


func test_a_raised_border_draws_light_on_top_and_left_and_dark_below_and_right() -> void:
	if DisplayServer.get_name() == "headless":
		pass_test("nothing is drawn headless: the shades are checked above")
		return
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", TkBorder.make(TkBorder.Relief.RAISED, ClassicTheme.BACKGROUND, 2, 0))
	panel.size = Vector2(20, 12)
	panel.position = Vector2(40, 40)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(100, 100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(panel)
	add_child_autofree(viewport)
	await wait_process_frames(3)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert_eq(image.get_pixel(50, 40).to_html(false), "f6f6f6", "top")
	assert_eq(image.get_pixel(41, 46).to_html(false), "f6f6f6", "left")
	assert_eq(image.get_pixel(50, 51).to_html(false), "6a6a6a", "bottom")
	assert_eq(image.get_pixel(59, 46).to_html(false), "6a6a6a", "right")
	assert_eq(image.get_pixel(50, 46).to_html(false), "b0b0b0", "inside")


# The originals in use ----------------------------------------------------------------

func test_the_graph_windows_switches_are_its_pictures() -> void:
	var window: GraphWindow = main.graph_window
	for type in 6:
		assert_same(window.switches[type].texture_normal, Content.olpc_texture("gr%shi" % GraphWindow.PICTURES[type]),
			"%s on: its hi picture" % GraphView.NAMES[type])
	window.toggle(4)
	assert_same(window.switches[4].texture_normal, Content.olpc_texture("grcrim"), "crime off")
	assert_same(window.year_buttons[0].texture_normal, Content.olpc_texture("gr10hi"), "10 years chosen")
	assert_same(window.year_buttons[1].texture_normal, Content.olpc_texture("gr120"))
	window.set_years(CityEngine.HistoryScale.LONG)
	assert_same(window.year_buttons[0].texture_normal, Content.olpc_texture("gr10"))
	assert_same(window.year_buttons[1].texture_normal, Content.olpc_texture("gr120hi"))


func test_the_maps_legends_are_its_pictures() -> void:
	var window: MapWindow = main.map_window
	var shown := {}
	for mode: int in [SmallMap.Mode.ALL, SmallMap.Mode.POWER_GRID, SmallMap.Mode.CRIME, SmallMap.Mode.RATE_OF_GROWTH]:
		window.show_map(mode)
		shown[SmallMap.TITLES[mode]] = window.legend.texture
	assert_same(shown["Micropolis Overall Map"], Content.olpc_texture("legendn"))
	assert_same(shown["Power Grid Map"], Content.olpc_texture("legendn"))
	assert_same(shown["Crime Rate Map"], Content.olpc_texture("legendmm"))
	assert_same(shown["Rate of Growth Map"], Content.olpc_texture("legendpm"))


func test_the_small_map_draws_the_olpcs_small_tiles() -> void:
	var small := SmallMap.olpc_small_tiles()
	var source := Content.olpc_image("tilessm")
	for tile in [0, 2, 21, 244, 766, 959]:
		for y in 3:
			for x in 3:
				assert_eq(small.get_pixel((tile % 16) * 3 + x, (tile / 16) * 3 + y), source.get_pixel(x, tile * 3 + y),
					"tile %d at %d,%d" % [tile, x, y])
	assert_eq(small.get_pixel(0, 60 * 3), SmallMap.POWERED, "then the power grid's colours")
	assert_same(main.map_window.small_map._small, small, "the OLPC art's map uses them")
