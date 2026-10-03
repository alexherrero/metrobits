## The player's preferences that outlast a session, kept in a ConfigFile they
## can also edit by hand. The default file is user://settings.cfg, which on
## macOS is ~/Library/Application Support/Metrobits/settings.cfg:
##
##   [options]
##   auto_goto=true
##   sound=false
##
## A tile_set key, from when the Classic art was an option, is ignored.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Settings
extends RefCounted

const SECTION := "options"

## Where a new Settings keeps its file. "" keeps settings in memory only, which
## the tests use (tests/pre_run.gd) so they never touch the player's file.
static var default_path := "user://settings.cfg"

## Whether the editor glides to a message's place: off unless the player
## turned it on, as the OLPC's editor started (weditor.tcl's AutoGoto 0; its
## sim flag was on, but each editor followed only with its own on).
var auto_goto: bool:
	get:
		return _config.get_value(SECTION, "auto_goto", false)
	set(value):
		_config.set_value(SECTION, "auto_goto", value)
		_save()


## Whether the game plays its sounds (Options, then Sound): on unless the
## player turned them off, as in 1989.
var sound: bool:
	get:
		return _config.get_value(SECTION, "sound", true)
	set(value):
		_config.set_value(SECTION, "sound", value)
		_save()

var path: String

var _config := ConfigFile.new()


func _init(file := default_path) -> void:
	path = file
	if path != "" and FileAccess.file_exists(path):
		_config.load(path)


func _save() -> void:
	if path != "":
		_config.save(path)
