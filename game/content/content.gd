## The original's images and sounds, read at runtime from micropolis-core/content
##. Godot never imports that folder and nothing is copied: files are read
## from disk by path, the way the engine reads its cities: in the repo, beside the
## Godot project; in an exported build, from the copy the packaging puts inside
## the app (see core_dir).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Content
extends RefCounted

## micropolis-core, next to the Godot project in the repo.
const REPO_CORE_DIR := "res://../micropolis-core"
## Its subfolders: the original's content, and the OLPC's own release,
## micropolis-activity (see its PROVENANCE.md), whose named images,
## sounds and fonts live in olpc. Its images are XPM, read by Xpm.
const CONTENT := "content"
const OLPC := "olpc"
## The one face the OLPC's FontInfo asked for ("dejavu lgc sans-medium-r-normal").
const OLPC_FONT := "res/dejavu-lgc/DejaVuLGCSans.ttf"

static var _textures := {}
static var _sounds := {}
static var _olpc_textures := {}
static var _olpc_sounds := {}
static var _font: FontFile
static var _core_dir := ""
## Every path under micropolis-core asked for this run, for the packaging's
## list of what ships (see note_used).
static var used := {}


## The absolute path of micropolis-core: beside the Godot project when the game
## runs from the repo, or, in an exported build, the copy the packaging puts
## inside the app (bundled_core_dir).
static func core_dir() -> String:
	if _core_dir == "":
		_core_dir = (bundled_core_dir(OS.get_executable_path(), OS.get_name()) if OS.has_feature("template")
			else ProjectSettings.globalize_path(REPO_CORE_DIR).simplify_path())
	return _core_dir


## Where an exported build keeps micropolis-core: in a Mac app's
## Contents/Resources, or beside the executable elsewhere.
static func bundled_core_dir(executable: String, os_name: String) -> String:
	var beside := executable.get_base_dir()
	if os_name == "macOS":
		return beside.path_join("../Resources/micropolis-core").simplify_path()
	return beside.path_join("micropolis-core")


## The absolute path of a file in the content folder, e.g. "images/icres.png".
static func path(relative: String) -> String:
	used[CONTENT.path_join(relative)] = true
	return core_dir().path_join(CONTENT).path_join(relative)


static func has(relative: String) -> bool:
	return FileAccess.file_exists(path(relative))


## A PNG or BMP from the content folder, or null.
static func load_image(relative: String) -> Image:
	if not has(relative):
		return null
	return Image.load_from_file(path(relative))


## load_image as a texture, cached.
static func texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		var image := load_image(relative)
		_textures[relative] = ImageTexture.create_from_image(image) if image else null
	return _textures[relative]


## An MP3 from content/sounds by name, e.g. "Siren", cached; or null.
static func sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		var relative := "sounds/%s.mp3" % name
		_sounds[name] = AudioStreamMP3.load_from_file(path(relative)) if has(relative) else null
	return _sounds[name]


## The absolute path of a file in micropolis-core/olpc, e.g. "images/demandg.xpm".
static func olpc_path(relative: String) -> String:
	used[OLPC.path_join(relative)] = true
	return core_dir().path_join(OLPC).path_join(relative)


## When CONTENT_USED names a file, adds to it each file under micropolis-core
## this run asked for, one path a line, relative to micropolis-core.
## packaging/list-content.sh gathers them from the tests, the soak and the
## screens into the list of what the app carries.
static func note_used() -> void:
	var list := OS.get_environment("CONTENT_USED")
	if list == "":
		return
	var file := FileAccess.open(list, FileAccess.READ_WRITE if FileAccess.file_exists(list) else FileAccess.WRITE)
	file.seek_end()
	for relative: String in used:
		if FileAccess.file_exists(core_dir().path_join(relative)):
			file.store_line(relative.simplify_path())


## One of the OLPC's images by name, e.g. "demandg" for images/demandg.xpm,
## read by Xpm; or null.
static func olpc_image(image_name: String) -> Image:
	return Xpm.load_file(olpc_path("images/%s.xpm" % image_name))


## olpc_image as a texture, cached.
static func olpc_texture(image_name: String) -> Texture2D:
	if not _olpc_textures.has(image_name):
		var image := olpc_image(image_name)
		_olpc_textures[image_name] = ImageTexture.create_from_image(image) if image else null
	return _olpc_textures[image_name]


## One of the OLPC's sounds by name, as its player named them ("Com" is
## res/sounds/com.wav), cached; or null.
static func olpc_sound(sound_name: String) -> AudioStream:
	if not _olpc_sounds.has(sound_name):
		var file := olpc_path("res/sounds/%s.wav" % sound_name.to_lower())
		_olpc_sounds[sound_name] = AudioStreamWAV.load_from_file(file) if FileAccess.file_exists(file) else null
	return _olpc_sounds[sound_name]


## DejaVu LGC Sans, the OLPC's font, loaded once. It's drawn antialiased with
## light hinting, chosen over the OLPC's unsmoothed X core fonts after
## comparing the two side by side.
static func olpc_font() -> FontFile:
	if _font == null:
		_font = FontFile.new()
		_font.load_dynamic_font(olpc_path(OLPC_FONT))
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_LIGHT
	return _font
