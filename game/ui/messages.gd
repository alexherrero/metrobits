## The text of the engine's messages (message_sent's index).
##
## 1 to 44 are the original's strings, read at runtime from the content's
## stri.301.txt, one per line. The C++ engine renumbered the messages after 44
## (text.h), so the file's later lines don't match; those few come from
## text.h's own descriptions.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Messages
extends RefCounted

const FILE := "data/stri.301.txt"
## The last message stri.301.txt numbers the way the engine does.
const LAST_FROM_FILE := 44
const LATER := {
	45: "Started a New City.",
	46: "Restored a Saved City.",
	47: "You won the scenario!",
	48: "You lost the scenario.",
	49: "About Micropolis.",
	50: "Dullsville", 51: "San Francisco", 52: "Hamburg", 53: "Bern",
	54: "Tokyo", 55: "Detroit", 56: "Boston", 57: "Rio de Janeiro",
}

static var _lines := PackedStringArray()


## The message's text, or "" for a number the engine doesn't use.
static func text(index: int) -> String:
	if index > LAST_FROM_FILE:
		return LATER.get(index, "")
	if _lines.is_empty() and Content.has(FILE):
		_lines = FileAccess.get_file_as_string(Content.path(FILE)).split("\n")
	if index < 1 or index > _lines.size():
		return ""
	return _lines[index - 1].strip_edges()
