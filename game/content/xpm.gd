## A reader for XPM, the X PixMap text format the OLPC Micropolis kept its
## images in (micropolis-core/olpc/images). Godot has no XPM importer,
## so the originals are read at runtime, as the content's PNGs are:
## nothing is converted, and only the .xpm files are in the repo.
##
## It reads what the OLPC's files use and a little more: XPM 3 (the C array
## form), any number of characters per pixel, colours as #RGB to
## #RRRRGGGGBBBB, "None" (transparent) or a name Godot knows, taking the
## colour ("c") key before the grey ("g4", "g") and mono ("m") ones.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Xpm
extends RefCounted

## The keys of a colour line, most wanted first.
const KEYS := ["c", "g4", "g", "m"]

static var _strings := RegEx.create_from_string("\"([^\"]*)\"")


## The image in an XPM file, as RGBA8, or null if it can't be read.
static func load_file(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_string(path))


## The image in XPM text, as RGBA8, or null if it isn't XPM.
static func parse(text: String) -> Image:
	var strings: Array[String] = []
	for found in _strings.search_all(text):
		strings.append(found.get_string(1))
	if strings.is_empty():
		return null
	var header := strings[0].split(" ", false)
	if header.size() < 4:
		return null
	var width := header[0].to_int()
	var height := header[1].to_int()
	var count := header[2].to_int()
	var per_pixel := header[3].to_int()
	if width <= 0 or height <= 0 or count <= 0 or per_pixel <= 0 or strings.size() < 1 + count + height:
		return null

	# Each colour as a little-endian RGBA word, and a table from a pixel's
	# characters to it: by byte for one character, by two bytes for two, and
	# by string beyond that.
	var words := PackedInt64Array()
	var by_code := PackedInt32Array()
	var by_key := {}
	if per_pixel <= 2:
		by_code.resize(1 << (8 * per_pixel))
		by_code.fill(-1)
	for i in count:
		var line := strings[1 + i]
		var key := line.substr(0, per_pixel)
		words.append(_word(color(line.substr(per_pixel))))
		if per_pixel <= 2:
			by_code[_code(key.to_ascii_buffer(), 0, per_pixel)] = i
		else:
			by_key[key] = i

	var data := PackedByteArray()
	data.resize(width * height * 4)
	var at := 0
	for y in height:
		var row := strings[1 + count + y].to_ascii_buffer()
		if row.size() < width * per_pixel:
			return null
		for x in width:
			var index: int
			if per_pixel == 1:
				index = by_code[row[x]]
			elif per_pixel == 2:
				index = by_code[(row[2 * x] << 8) | row[2 * x + 1]]
			else:
				index = by_key.get(row.slice(x * per_pixel, (x + 1) * per_pixel).get_string_from_ascii(), -1)
			if index < 0:
				return null
			data.encode_u32(at, words[index])
			at += 4
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


## A colour line's colour, after its pixel characters: e.g. "c #FF0000",
## "c #FFFF00000000 m #000000" or "s none c None".
static func color(spec: String) -> Color:
	var words := spec.replace("\t", " ").split(" ", false)
	var values := {}
	var i := 0
	while i + 1 < words.size():
		values[words[i].to_lower()] = words[i + 1]
		i += 2
	for key: String in KEYS:
		if values.has(key):
			return named(values[key])
	return Color.BLACK


## A colour value: "#RGB" to "#RRRRGGGGBBBB" (each channel scaled from its
## own number of digits, as X did), "None", or a name.
static func named(value: String) -> Color:
	if value.to_lower() == "none":
		return Color.TRANSPARENT
	if value.begins_with("#"):
		var hex := value.substr(1)
		var digits := hex.length() / 3
		if digits > 0 and digits * 3 == hex.length() and hex.is_valid_hex_number():
			var top := float((1 << (4 * digits)) - 1)
			return Color(hex.substr(0, digits).hex_to_int() / top, hex.substr(digits, digits).hex_to_int() / top,
				hex.substr(2 * digits, digits).hex_to_int() / top)
	return Color.from_string(value, Color.BLACK)


static func _word(value: Color) -> int:
	return value.r8 | (value.g8 << 8) | (value.b8 << 16) | (value.a8 << 24)


static func _code(bytes: PackedByteArray, from: int, count: int) -> int:
	return bytes[from] if count == 1 else (bytes[from] << 8) | bytes[from + 1]
