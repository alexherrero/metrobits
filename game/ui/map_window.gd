## The original's map window (wmap.tcl): the Zones menu (All, Residential,
## Commercial, Industrial, Transportation) and the Overlays menu (Population
## Density, Rate of Growth, Land Value, Crime Rate, Pollution Density, Traffic
## Density, Power Grid, Fire Coverage, Police Coverage), with the legend on
## the right, over the whole city at three pixels a tile (SmallMap), where the
## editor's view is a rectangle to drag. Its title is the map's, as 1989's X11
## windows had it (MapTitles). The OLPC packed it into the head column, and
## that's where it opens.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name MapWindow
extends Window

const ZONES := {
	SmallMap.Mode.ALL: "All", SmallMap.Mode.RESIDENTIAL: "Residential",
	SmallMap.Mode.COMMERCIAL: "Commercial", SmallMap.Mode.INDUSTRIAL: "Industrial",
	SmallMap.Mode.TRANSPORTATION: "Transportation",
}
## In wmap.tcl's order.
const OVERLAYS := {
	SmallMap.Mode.POPULATION_DENSITY: "Population Density", SmallMap.Mode.RATE_OF_GROWTH: "Rate of Growth",
	SmallMap.Mode.LAND_VALUE: "Land Value", SmallMap.Mode.CRIME: "Crime Rate",
	SmallMap.Mode.POLLUTION: "Pollution Density", SmallMap.Mode.TRAFFIC_DENSITY: "Traffic Density",
	SmallMap.Mode.POWER_GRID: "Power Grid", SmallMap.Mode.FIRE_COVERAGE: "Fire Coverage",
	SmallMap.Mode.POLICE_COVERAGE: "Police Coverage",
}
## The map redraws from the engine this often while it runs.
const REFRESH_SECONDS := 0.25

var small_map: SmallMap
var zones_menu: PopupMenu
var overlays_menu: PopupMenu
var legend: MapLegend

## How long the last redraw from the engine took, in microseconds, and how
## many there have been.
var last_refresh_usec := 0
var refreshes := 0

var _since_refresh := 0.0


func _init() -> void:
	title = SmallMap.TITLES[SmallMap.Mode.ALL]
	visible = false
	transient = true
	exclusive = false
	unresizable = true
	wrap_controls = true
	close_requested.connect(hide)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", ClassicTheme.box(true, ClassicTheme.BACKGROUND, 0))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var bar := MenuBar.new()
	bar.prefer_global_menu = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bar)
	zones_menu = _menu(bar, "Zones", ZONES)
	overlays_menu = _menu(bar, "Overlays", OVERLAYS)
	legend = MapLegend.new()
	top.add_child(legend)
	var sunken := PanelContainer.new()
	sunken.add_theme_stylebox_override("panel", ClassicTheme.box(false, Color.BLACK, 1))
	column.add_child(sunken)
	small_map = SmallMap.new()
	small_map.name = "SmallMap"
	sunken.add_child(small_map)


func setup(engine: CityEngine, art: Image, editor: MapView) -> void:
	small_map.setup(engine, art, editor)
	show_map(SmallMap.Mode.ALL)


## One of 1989's maps, from either menu.
func show_map(mode: SmallMap.Mode) -> void:
	small_map.set_mode(mode)
	title = SmallMap.TITLES[mode]
	legend.mode = mode
	for menu: PopupMenu in [zones_menu, overlays_menu]:
		for i in menu.item_count:
			menu.set_item_checked(i, menu.get_item_id(i) == mode)


## Redraws from the engine now (after a load, or a tool used).
func refresh() -> void:
	_since_refresh = 0.0
	if visible:
		var started := Time.get_ticks_usec()
		small_map.refresh()
		last_refresh_usec = Time.get_ticks_usec() - started
		refreshes += 1


func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		refresh()


func _menu(bar: MenuBar, menu_name: String, items: Dictionary) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = menu_name
	for mode: int in items:
		menu.add_radio_check_item(items[mode], mode)
	menu.id_pressed.connect(func(id: int) -> void: show_map(id as SmallMap.Mode))
	bar.add_child(menu)
	return menu


## wmap.tcl's legend, the OLPC's own pictures as UISetMapState chose them:
## legendmm.xpm ("MIN", four swatches, "MAX") for the overlays of amounts,
## legendpm.xpm ("-", two swatches, a no-change sign, two more, "+") for the
## rate of growth, and legendn.xpm (a blank) for the zone maps and the power
## grid.
class MapLegend:
	extends TextureRect

	const PICTURES := {"": "legendn", "minmax": "legendmm", "plusminus": "legendpm"}

	var mode := SmallMap.Mode.ALL:
		set(value):
			mode = value
			texture = Content.olpc_texture(PICTURES[kind()])

	func _init() -> void:
		stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture = Content.olpc_texture(PICTURES[""])

	## Which legend shows: "minmax", "plusminus" or "".
	func kind() -> String:
		if mode == SmallMap.Mode.RATE_OF_GROWTH:
			return "plusminus"
		return "minmax" if SmallMap.OVERLAYS.has(mode) else ""
