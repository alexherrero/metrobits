## What the front end knows about each tool: the engine's 20, and the OLPC's
## Chalk and Eraser, which only the front end has (they draw on and rub out
## the chalk overlay, ChalkLayer): its name and cost label, its palette icon
## and place, its key, its cursor colours and the tile its ghost preview
## shows. Names, icons, places and cursor colours are the 1989 editor's
## (micropolis.tcl ToolInfo, weditor.tcl, w_tool.c toolColors).
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Tools
extends RefCounted

const T := CityEngine.Tool
## The OLPC's chalk and eraser (chalkState, eraserState), past the engine's tools.
const CHALK := 100
const ERASER := 101

## The palette, in the 1989 order (which X and Z step through): each tool with
## the top-left of its button in the 130-point palette column, where
## weditor.tcl placed it, Chalk and Eraser in their row. The engine's four
## tools the OLPC palette lacked (Water, Land, Forest, Network) are ours
##, set apart in two rows of their own under the airport.
const PALETTE := [
	[T.RESIDENTIAL, Vector2(9, 58)], [T.COMMERCIAL, Vector2(47, 58)], [T.INDUSTRIAL, Vector2(85, 58)],
	[T.FIRE_STATION, Vector2(9, 112)], [T.QUERY, Vector2(47, 112)], [T.POLICE_STATION, Vector2(85, 112)],
	[T.WIRE, Vector2(28, 150)], [T.BULLDOZER, Vector2(66, 150)],
	[T.RAILROAD, Vector2(6, 188)], [T.ROAD, Vector2(66, 188)],
	[CHALK, Vector2(28, 216)], [ERASER, Vector2(66, 216)],
	[T.STADIUM, Vector2(1, 254)], [T.PARK, Vector2(47, 254)], [T.SEAPORT, Vector2(85, 254)],
	[T.COAL_POWER, Vector2(1, 300)], [T.NUCLEAR_POWER, Vector2(85, 300)],
	[T.AIRPORT, Vector2(35, 346)],
	[T.WATER, Vector2(28, 424)], [T.LAND, Vector2(66, 424)],
	[T.FOREST, Vector2(28, 462)], [T.NETWORK, Vector2(66, 462)],
]
## Where our four tools start: a gap under the airport sets them apart.
const EXTRAS_TOP := 424

const NAMES := {
	T.RESIDENTIAL: "Residential Zone", T.COMMERCIAL: "Commercial Zone", T.INDUSTRIAL: "Industrial Zone",
	T.FIRE_STATION: "Fire Station", T.QUERY: "Query", T.POLICE_STATION: "Police Station",
	T.WIRE: "Wire", T.BULLDOZER: "Bulldozer", T.RAILROAD: "Rail", T.ROAD: "Road",
	T.STADIUM: "Stadium", T.PARK: "Park", T.SEAPORT: "Seaport", T.COAL_POWER: "Coal Power Plant",
	T.NUCLEAR_POWER: "Nuclear Power Plant", T.AIRPORT: "Airport", T.NETWORK: "Network",
	T.WATER: "Water", T.LAND: "Land", T.FOREST: "Forest", CHALK: "Chalk", ERASER: "Eraser",
}

## The original's icons, images/<name>.png and <name>hi.png when selected.
## The last four tools have none; Palette draws theirs from ICON_TILES.
const ICONS := {
	T.RESIDENTIAL: "icres", T.COMMERCIAL: "iccom", T.INDUSTRIAL: "icind",
	T.FIRE_STATION: "icfire", T.QUERY: "icqry", T.POLICE_STATION: "icpol",
	T.WIRE: "icwire", T.BULLDOZER: "icdozr", T.RAILROAD: "icrail", T.ROAD: "icroad",
	T.STADIUM: "icstad", T.PARK: "icpark", T.SEAPORT: "icseap", T.COAL_POWER: "iccoal",
	T.NUCLEAR_POWER: "icnuc", T.AIRPORT: "icairp", CHALK: "icchlk", ERASER: "icersr",
}
const ICON_TILES := {T.NETWORK: 844, T.WATER: 2, T.LAND: 0, T.FOREST: 37}

## One key per tool. B, R, P (power) and T (transit) are the 1989 editor's;
## holding a tool's key while clicking uses it and switches back on release, as
## the original did for those four. X and Z step through the palette.
const KEYS := {
	T.RESIDENTIAL: KEY_H, T.COMMERCIAL: KEY_C, T.INDUSTRIAL: KEY_I, T.FIRE_STATION: KEY_F,
	T.POLICE_STATION: KEY_O, T.QUERY: KEY_Q, T.WIRE: KEY_P, T.BULLDOZER: KEY_B,
	T.RAILROAD: KEY_T, T.ROAD: KEY_R, T.STADIUM: KEY_S, T.PARK: KEY_K, T.SEAPORT: KEY_E,
	T.COAL_POWER: KEY_L, T.NUCLEAR_POWER: KEY_N, T.AIRPORT: KEY_A, T.NETWORK: KEY_M,
	T.WATER: KEY_W, T.LAND: KEY_D, T.FOREST: KEY_G,
}
const NEXT_KEY := KEY_X
const PREVIOUS_KEY := KEY_Z

## The 1989 cursor's band colours, [foreground, background]: solid when they
## match, dashed when they don't (w_tool.c, with w_x.c's palette). Water, Land
## and Forest weren't in it; theirs follow the same scheme.
const LIGHT_GREEN := Color("#00e600")
const LIGHT_BLUE := Color("#6666e6")
const DARK_BLUE := Color("#0000e6")
const DARK_GREEN := Color("#007f00")
const YELLOW := Color("#ffff00")
const ORANGE := Color("#ff7f00")
const RED := Color("#ff0000")
const OLIVE := Color("#997f4c")
const LIGHT_BROWN := Color("#cc7f66")
const LIGHT_GRAY := Color("#bfbfbf")
const DARK_GRAY := Color("#3f3f3f")
const CURSOR_COLORS := {
	T.RESIDENTIAL: [LIGHT_GREEN, LIGHT_GREEN], T.COMMERCIAL: [LIGHT_BLUE, LIGHT_BLUE],
	T.INDUSTRIAL: [YELLOW, YELLOW], T.FIRE_STATION: [LIGHT_GREEN, RED], T.QUERY: [ORANGE, ORANGE],
	T.POLICE_STATION: [LIGHT_GREEN, LIGHT_BLUE], T.WIRE: [DARK_GRAY, YELLOW],
	T.BULLDOZER: [LIGHT_BROWN, LIGHT_BROWN], T.RAILROAD: [DARK_GRAY, OLIVE],
	T.ROAD: [DARK_GRAY, Color.WHITE], T.STADIUM: [LIGHT_GRAY, LIGHT_GREEN],
	T.PARK: [LIGHT_BROWN, LIGHT_GREEN], T.SEAPORT: [LIGHT_GRAY, LIGHT_BLUE],
	T.COAL_POWER: [LIGHT_GRAY, YELLOW], T.NUCLEAR_POWER: [LIGHT_GRAY, YELLOW],
	T.AIRPORT: [LIGHT_GRAY, LIGHT_BROWN], T.NETWORK: [LIGHT_GRAY, RED],
	T.WATER: [LIGHT_BLUE, DARK_BLUE], T.LAND: [LIGHT_BROWN, OLIVE], T.FOREST: [DARK_GREEN, LIGHT_GREEN],
	CHALK: [LIGHT_GRAY, LIGHT_GRAY], ERASER: [DARK_GRAY, DARK_GRAY],
}

## The top-left tile of what a tool builds, for its ghost preview. Buildings
## are laid out row by row from it, as the engine's putBuilding does. The
## bulldozer and query build nothing.
const GHOST_TILES := {
	T.RESIDENTIAL: 240, T.COMMERCIAL: 423, T.INDUSTRIAL: 612, T.FIRE_STATION: 761,
	T.POLICE_STATION: 770, T.STADIUM: 779, T.SEAPORT: 693, T.COAL_POWER: 745,
	T.NUCLEAR_POWER: 811, T.AIRPORT: 709,
	T.WIRE: 210, T.RAILROAD: 226, T.ROAD: 66, T.PARK: 40,
	T.NETWORK: 844, T.WATER: 2, T.LAND: 0, T.FOREST: 37,
}


## Whether a tool is the engine's, rather than the chalk or the eraser.
static func is_engine_tool(tool: int) -> bool:
	return tool != CHALK and tool != ERASER


## Whether a tool draws on the chalk overlay.
static func is_chalk(tool: int) -> bool:
	return tool == CHALK or tool == ERASER


## A tool's cost: the engine's, or nothing for the chalk and the eraser.
static func cost(engine: CityEngine, tool: int) -> int:
	return engine.get_tool_cost(tool) if is_engine_tool(tool) else 0


## A tool's size in tiles: the engine's, or one for the chalk and the eraser.
static func size(engine: CityEngine, tool: int) -> int:
	return engine.get_tool_size(tool) if is_engine_tool(tool) else 1


## Tools in palette order.
static func ordered() -> Array[int]:
	var tools: Array[int] = []
	for entry: Array in PALETTE:
		tools.append(entry[0])
	return tools


## The original's cost label: "$5,000", or "free".
static func cost_label(cost: int) -> String:
	return "free" if cost == 0 else HeadPanel.format_money(cost)


## A tool's key, or KEY_NONE: the chalk and the eraser had none.
static func key_for(tool: int) -> Key:
	return KEYS.get(tool, KEY_NONE)


## The tool whose key this is, or -1.
static func tool_for_key(keycode: Key) -> int:
	for tool: int in KEYS:
		if KEYS[tool] == keycode:
			return tool
	return -1


## A tool's footprint for a click on `tile`: the clicked tile is the top-left
## one for a one-tile tool, and one in from the top-left for bigger ones (the
## engine builds around it; w_tool.c's toolOffset).
static func footprint(tile: Vector2i, size: int) -> Rect2i:
	var offset := 1 if size > 1 else 0
	return Rect2i(tile - Vector2i(offset, offset), Vector2i(size, size))


## Whether dragging paints with the tool from tile to tile. Every engine tool
## does, as in the original, except Query, which would open a report for each
## tile it crossed; the chalk and the eraser follow the pointer instead.
static func drags(tool: int) -> bool:
	return tool != T.QUERY and is_engine_tool(tool)
