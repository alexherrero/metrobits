# Where the game finds micropolis-core, in the repo and inside
# an exported app, and the app's name and user folder.
extends GutTest


func test_from_the_repo_it_reads_micropolis_core_beside_the_project() -> void:
	var core := Content.core_dir()
	assert_eq(core, ProjectSettings.globalize_path("res://../micropolis-core").simplify_path())
	assert_true(DirAccess.dir_exists_absolute(core.path_join("content/cities")))
	assert_true(FileAccess.file_exists(Content.olpc_path(Content.OLPC_FONT)))
	assert_eq(Content.path("images/icres.png"), core.path_join("content/images/icres.png"))


func test_an_exported_app_reads_the_copy_inside_it() -> void:
	assert_eq(Content.bundled_core_dir("/Applications/Metrobits.app/Contents/MacOS/Metrobits", "macOS"),
		"/Applications/Metrobits.app/Contents/Resources/micropolis-core", "a Mac app's Resources")
	assert_eq(Content.bundled_core_dir("/opt/metrobits/metrobits.x86_64", "Linux"),
		"/opt/metrobits/micropolis-core", "elsewhere, beside the executable")


func test_the_engine_reads_the_same_content() -> void:
	var engine := MicropolisCityEngine.new()
	assert_eq(engine.get_content_dir(), Content.path("").simplify_path())
	assert_true(engine.load_scenario(CityEngine.Scenario.DULLSVILLE))


func test_the_app_is_metrobits_with_its_own_user_folder() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Metrobits")
	assert_true(ProjectSettings.get_setting("application/config/use_custom_user_dir"))
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name"), "Metrobits")


# What the app carries ---------------------------------------------

func _shipped() -> PackedStringArray:
	var listed := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../packaging/content-used.txt"))
	return listed.strip_edges().split("\n")


func test_the_app_carries_only_files_that_exist_and_no_windows_art() -> void:
	var shipped := _shipped()
	assert_gt(shipped.size(), 200)
	for relative: String in shipped:
		assert_true(FileAccess.file_exists(Content.core_dir().path_join(relative)), relative)
		assert_false(relative.contains("tilesets"), relative + ": the Windows art never ships")
	assert_true(shipped.has("content/images/tiles.png"))
	assert_true(shipped.has("olpc/res/sounds/explosion-high.wav"))


func test_every_shipped_content_file_is_traced() -> void:
	var provenance := FileAccess.get_file_as_string(Content.core_dir().path_join("CONTENT-PROVENANCE.md"))
	for relative: String in _shipped():
		if relative.begins_with("content/"):
			assert_true(provenance.contains("| `%s` |" % relative), relative + " is in CONTENT-PROVENANCE.md")
	assert_false(provenance.contains("**untraced**"))


# About Metrobits --------------------------------------------------------------------

func test_the_version_is_one_number_in_both_places() -> void:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var version := Notices.version()
	assert_string_contains(version, ".")
	assert_eq(presets.get_value("preset.0.options", "application/short_version"), version,
		"the installer's version is the project's")
	assert_eq(presets.get_value("preset.0.options", "application/version"), version)


func test_about_metrobits_shows_the_version_and_the_notices() -> void:
	var text := Notices.app_about_text()
	assert_string_starts_with(text, "Version %s\n\n" % Notices.version())
	assert_string_contains(text, "Metrobits is a modified version of Micropolis.")
	assert_string_ends_with(text, Notices.COURTESY_TEXT)
	assert_string_starts_with(Notices.about_text(), "Metrobits %s (built on Micropolis)" % Notices.version(),
		"the game's own About names the version too")


func test_the_macos_about_item_opens_it() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child_autofree(main)
	main._notification(NOTIFICATION_WM_ABOUT)
	assert_eq(main.app_about_count, 1, "About Metrobits, in the menu bar")
