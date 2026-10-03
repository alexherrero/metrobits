# The original's images and sounds load at runtime from micropolis-core/content
#, with nothing imported or copied into the Godot project.
extends GutTest


func test_the_content_folder_is_outside_the_godot_project() -> void:
	var project := ProjectSettings.globalize_path("res://").simplify_path()
	assert_false(Content.path("images").begins_with(project), "not under game/")
	assert_true(DirAccess.dir_exists_absolute(Content.path("images")))


func test_the_tile_art_loads_as_960_tiles() -> void:
	var olpc := Content.load_image(CityMap.TILES)
	assert_not_null(olpc)
	assert_eq(olpc.get_size(), Vector2i(256, 960), "the OLPC art: 16 x 60 tiles of 16 pixels")
	assert_same(CityMap.load_tiles(), CityMap.load_tiles(), "loaded once")


func test_the_palette_icons_load_with_their_highlighted_versions() -> void:
	for icon in ["icres", "icroad", "icdozr", "icairp"]:
		assert_not_null(Palette.icon_texture(icon), icon)
		assert_not_null(Palette.icon_texture(icon + "hi"), icon + "hi")
	assert_eq(Palette.icon_texture("icroad").get_image().get_pixel(0, 0), Color8(191, 191, 191),
		"the OLPC's Road icon has a grey ground, where MicropolisCore's PNG has white")


func test_textures_are_cached() -> void:
	assert_same(Content.texture("images/icres.png"), Content.texture("images/icres.png"))


func test_a_sound_loads_as_an_mp3() -> void:
	var siren := Content.sound("Siren")
	assert_true(siren is AudioStreamMP3)
	assert_gt(siren.get_length(), 1.0)


func test_missing_files_give_null() -> void:
	assert_null(Content.load_image("images/no_such_image.png"))
	assert_null(Content.texture("images/no_such_image.png"))
	assert_null(Content.sound("NoSuchSound"))


func test_nothing_from_the_content_folder_is_imported() -> void:
	# Godot writes a .import file next to anything it imports.
	var imported := []
	for folder in ["images", "sounds"]:
		for file in DirAccess.get_files_at(Content.path(folder)):
			if file.ends_with(".import"):
				imported.append(folder.path_join(file))
	assert_eq(imported, [])
