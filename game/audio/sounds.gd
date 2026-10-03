## The original's sound effects, from micropolis-core/content/sounds,
## played as 1989 played them:
##
## - the engine's own sounds (CityEngine.sound_requested): each message's
##   sound (sirens, the monster, explosions, horns), the sprites' (the
##   helicopter, ships, the monster, explosions), the bulldozer's explosions,
##   and the tools' "Sorry" and "UhUh";
## - a tool's sound when the engine says it was used (tool_applied), from the
##   1989 front end's UIDidTool procedures in micropolis.tcl: DID_TOOL;
## - a tool's name when it's picked from the palette (EditorPalletSounds):
##   PALETTE;
## - "Boing" on pausing and resuming (MakeRunningSound), "Rumble" as the
##   bulldozer goes down (EditorToolDown), "Skid" when the map stops at a
##   place (UIDidStopPan), and "Sorry" when a city won't save or load.
##
## A sound plays the OLPC's own WAV where micropolis-core/olpc has it (the
## palette's "Com" and "Nuclear", which the content lacks, and the engine's
## "Explosion-High" or "ExplosionHigh", whose MP3 in the content is another
## sound), matched without dashes or case. Otherwise its
## name is found as a file in content/sounds as it is, without its dashes,
## then in lower case (the OLPC's files), so the front end's "O" plays o.mp3.
##
## Every sound plays at its own pitch and full volume, as the OLPC's player
## played them (RunPlaySound ran it with no options): 1989's "-speed" and "-volume", which the X11 sound server took as a
## playback rate and a loudness, are kept only as a record. Sounds overlap, as the OLPC's did, but a sound asked for
## twice in one frame plays once. Off, nothing plays (Options, then Sound,
## kept in settings.cfg).
##
## A ship's horn is always HonkHonk-Low, as the OLPC heard it: 1989 sometimes
## asked for it at -speed 80 in San Francisco, which the OLPC's player ignored,
## and MicropolisCore plays FogHornLow there instead.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Sounds
extends Node

## The engine's tool_applied names (tool.cpp) to 1989's sounds and speeds
## (micropolis.tcl, UIDidTool<name>). The engine's own tools that 1989 didn't
## have (Net, Water, Land, Forest) had no sound.
const DID_TOOL := {
	Res = ["O", 140], Com = ["A", 140], Ind = ["E", 140], Fire = ["O", 130], Qry = ["E", 200],
	Pol = ["E", 130], Wire = ["O", 120], Dozr = ["Rumble", 100], Rail = ["O", 100], Road = ["E", 100],
	Stad = ["O", 90], Park = ["A", 130], Seap = ["E", 90], Coal = ["O", 75], Nuc = ["E", 75],
	Airp = ["A", 50],
}
## The palette's sounds, by tool (EditorPalletSounds), the chalk and eraser's
## among them. Its palette lacked Network, Water, Land and Forest.
const PALETTE := {
	CityEngine.Tool.RESIDENTIAL: "Res", CityEngine.Tool.COMMERCIAL: "Com",
	CityEngine.Tool.INDUSTRIAL: "Ind", CityEngine.Tool.FIRE_STATION: "Fire",
	CityEngine.Tool.QUERY: "Query", CityEngine.Tool.POLICE_STATION: "Police",
	CityEngine.Tool.WIRE: "Wire", CityEngine.Tool.BULLDOZER: "Bulldozer",
	CityEngine.Tool.RAILROAD: "Rail", CityEngine.Tool.ROAD: "Road",
	CityEngine.Tool.STADIUM: "Stadium", CityEngine.Tool.PARK: "Park",
	CityEngine.Tool.SEAPORT: "Seaport", CityEngine.Tool.COAL_POWER: "Coal",
	CityEngine.Tool.NUCLEAR_POWER: "Nuclear", CityEngine.Tool.AIRPORT: "Airport",
	Tools.CHALK: "Chalk", Tools.ERASER: "Eraser",
}
## The engine's ship horn in San Francisco, and the horn the OLPC played.
const SHIP_HORNS := {"FogHornLow": "HonkHonkLow"}
## Players at once; the oldest is cut off past this.
const VOICES := 16
## How many plays `played` remembers.
const HISTORY := 64

## Whether sounds play (1989's Sound option).
var enabled := true
## The latest plays, oldest first: {name, file, speed (1989's, not used),
## pitch, volume (1989's, not used), db}.
var played: Array[Dictionary] = []

var _players: Array[AudioStreamPlayer] = []
var _next := 0
## The sounds started this frame.
var _this_frame := {}

static var _files := {}
## The content's sound files as they're spelled on disk: macOS finds "O.mp3"
## as o.mp3, where Linux wouldn't, so names are matched against the listing.
static var _on_disk := {}


## The file a sound's name plays: relative to the content folder, or
## "olpc/res/sounds/<name>.wav" for one only the OLPC's release has, or "".
static func file_for(sound: String) -> String:
	if _on_disk.is_empty():
		for file in DirAccess.get_files_at(Content.path("sounds")):
			_on_disk[file] = true
	if not _files.has(sound):
		_files[sound] = ""
		var dashless := sound.replace("-", "")
		for wav in DirAccess.get_files_at(Content.olpc_path("res/sounds")):
			if wav.get_basename().replace("-", "").to_lower() == dashless.to_lower():
				_files[sound] = "olpc/res/sounds/" + wav
				return _files[sound]
		for candidate: String in [sound, dashless, sound.to_lower(), dashless.to_lower()]:
			if _on_disk.has(candidate + ".mp3"):
				_files[sound] = "sounds/%s.mp3" % candidate
				break
	return _files[sound]


func _init() -> void:
	name = "Sounds"
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)


## Plays a sound by name, asked for at a speed and volume in percent, as 1989's
## UIMakeSound did. False if sound is off, the content has no such file, or
## it already started this frame.
func play(sound: String, speed := 100, volume := 100) -> bool:
	var file := file_for(sound)
	if not enabled or file == "" or _this_frame.has(sound):
		return false
	_this_frame[sound] = true
	if _this_frame.size() == 1:
		_clear_frame.call_deferred()
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = (Content.olpc_sound(file.get_file().get_basename()) if file.begins_with("olpc/")
		else Content.sound(file.get_file().get_basename()))
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.play()
	played.append({name = sound, file = file, speed = speed, pitch = player.pitch_scale, volume = volume,
		db = player.volume_db})
	if played.size() > HISTORY:
		played.pop_front()
	return true


## The engine's sound_requested.
func on_engine_sound(_channel: String, sound: String, _x: int, _y: int) -> void:
	play(SHIP_HORNS.get(sound, sound))


## The engine's tool_applied: 1989's UIDidTool sound for the tool.
func on_tool_applied(tool_name: String, _x: int, _y: int) -> void:
	if DID_TOOL.has(tool_name):
		play(DID_TOOL[tool_name][0], DID_TOOL[tool_name][1])


## A tool picked from the palette: its name, as 1989's EditorPallet said it.
func on_palette_pick(tool: int) -> void:
	if PALETTE.has(tool):
		play(PALETTE[tool])


## 1989's MakeRunningSound: a Boing, higher while the game runs.
func running(running_now: bool) -> void:
	play("Boing", 130 if running_now else 90)


## Whether any voice is sounding.
func is_playing() -> bool:
	for player in _players:
		if player.playing:
			return true
	return false


func stop_all() -> void:
	for player in _players:
		player.stop()


func _clear_frame() -> void:
	_this_frame.clear()
