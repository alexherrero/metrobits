## The original's notices: the colour, title, text and picture shown for a
## message the engine flags as having a picture (a fire, a tornado, a scenario
## won...). Read at runtime from the content's data/notices.xml, which numbers
## them as the engine does, with the English text from data/strings_en-US.xml.
## Also the Query tool's "Query Zone Status" notice, from the 1989 Message 9.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Notices
extends RefCounted

const NOTICES := "data/notices.xml"
const STRINGS := "data/strings_en-US.xml"
## stri.219 names what a tile is; stri.202 grades density, value, crime,
## pollution and growth, four or five grades each.
const ZONE_NAMES := "data/stri.219.txt"
const ZONE_GRADES := "data/stri.202.txt"
const QUERY_TITLE := "Query Zone Status"
const QUERY_COLOR := Color("#ffa500")
## The content's About notice, which numbers the scenarios' notices after it
## (scenario n is notice 49 + n).
const ABOUT := 49
## The OLPC's own About notice, which Micropolis, then About... shows
## (micropolis.tcl's Message 300, with [sim Version] as sim.c's
## MicropolisVersion, 4.0), and the line that marks this as a modified
## version, which EA's additional terms require.
const ABOUT_TITLE := "About Micropolis"
const ABOUT_COLOR := Color("#ffd700")
const ABOUT_VERSION := "4.0"
const ABOUT_TEXT := """Micropolis Version %s Copyright (C) 2007
    by Electronic Arts.
Based on the Original Micropolis Concept and Design
    by Will Wright.
TCL/Tk User Interface Designed and Created
    by Don Hopkins, DUX Software.
Ported to Linux, Optimized and Adapted for OLPC
    by Don Hopkins.
Licensed under the GNU General Public License, 
    version 3, with additional conditions."""
## One line, at the top, with Metrobits' version (application/config/version).
const MODIFIED_TEXT := "Metrobits %s (built on Micropolis): a modified version, restored in Godot."
## Then the Micropolis Public Name License's preferred attribution, word for
## word, as the game shows the Micropolis name: near the top,
## where a notice clipped under the map still shows it.
const COURTESY_TEXT := "Micropolis is a registered trademark of Micropolis Corporation (Micropolis GmbH) and is licensed here as a courtesy of the owner under the Micropolis Public Name License (www.micropolis.com)."

static var _notices := {}
static var _strings := {}
static var _zone_names := PackedStringArray()
static var _zone_grades := PackedStringArray()


## {title, color, text, picture} for a message number, or {} if it has none.
static func for_message(index: int) -> Dictionary:
	_load()
	return _notices.get(index, {})


## The About notice's text: the modified-version line first, where a notice
## clipped by a short window still shows it, then the OLPC's.
static func about_text() -> String:
	return (MODIFIED_TEXT % version()) + "\n" + COURTESY_TEXT + "\n\n" + (ABOUT_TEXT % ABOUT_VERSION)


## Metrobits' version, as the project settings give it, e.g. "1.0.1".
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## What About Metrobits, in the macOS menu bar, shows: the version, what
## Metrobits is, and the two notices every About carries.
static func app_about_text() -> String:
	return "\n\n".join(["Version %s" % version(),
		"Micropolis, the city simulator from 1989, rebuilt to run on a modern Mac with its original look and feel.",
		"Metrobits is a modified version of Micropolis. Electronic Arts and Micropolis GmbH don't make, endorse or support it.",
		COURTESY_TEXT])


## A scenario's notice (data/scenarios.xml: scenario n is notice 49 + n), which
## 1989 showed when the scenario started.
static func for_scenario(scenario: int) -> Dictionary:
	return for_message(ABOUT + scenario) if scenario >= 1 and scenario <= 8 else {}


## A string from data/strings_en-US.xml by id, e.g. "scenario_1_title".
static func string(id: String) -> String:
	_load()
	return _strings.get(id, "")


## The Query tool's report as the 1989 notice laid it out, from the engine's
## zone_status_shown arguments (1-based indices into stri.219 and stri.202).
static func zone_status(category: int, density: int, value: int, crime: int, pollution: int, growth: int) -> String:
	_load()
	var zone := _line(_zone_names, category)
	return "Zone: %s\nDensity: %s\nValue: %s\nCrime: %s\nPollution: %s\nGrowth: %s" % [
		zone if zone != "" else _zone_names[0], _line(_zone_grades, density), _line(_zone_grades, value),
		_line(_zone_grades, crime), _line(_zone_grades, pollution), _line(_zone_grades, growth)]


static func _line(lines: PackedStringArray, one_based: int) -> String:
	return lines[one_based - 1] if one_based >= 1 and one_based <= lines.size() else ""


static func _load() -> void:
	if not _notices.is_empty() or not Content.has(NOTICES):
		return
	_zone_names = _lines(ZONE_NAMES)
	_zone_grades = _lines(ZONE_GRADES)
	var parser := XMLParser.new()
	parser.open(Content.path(STRINGS))
	var id := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				id = parser.get_named_attribute_value_safe("id") if parser.get_node_name() == "string" else ""
			XMLParser.NODE_TEXT:
				if id != "":
					_strings[id] = parser.get_node_data().xml_unescape().replace("<br/>", "\n\n").strip_edges()
					id = ""
	parser = XMLParser.new()
	parser.open(Content.path(NOTICES))
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "notice":
			continue
		var picture := parser.get_named_attribute_value_safe("picture").trim_suffix("_rsrc")
		_notices[parser.get_named_attribute_value_safe("id").to_int()] = {
			title = _strings.get(parser.get_named_attribute_value_safe("title"), ""),
			text = _strings.get(parser.get_named_attribute_value_safe("description"), ""),
			color = Color.html(parser.get_named_attribute_value_safe("color").replace("0x", "#")),
			picture = "images/%s.png" % picture if picture != "" else "",
		}


static func _lines(relative: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in FileAccess.get_file_as_string(Content.path(relative)).split("\n"):
		lines.append(line.strip_edges())
	return lines
