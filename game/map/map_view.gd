## The editor view: the city map, clipped to this control, with a camera the
## player pans and zooms, and the selected tool under the pointer.
##
## Build: a left click applies the tool through the engine's own click path
## (tool_down, which reports no money and bulldoze-first), and a left drag
## paints it from tile to tile (tool_drag), as the original's editor did.
## Pan: a middle drag, Space and a left drag, the arrow keys, or a two-finger
## trackpad scroll (a Mac's stand-in for the middle button). The right
## button, or Shift with the left, opens the OLPC's pie menus (PieMenus),
## which take the press from here. Zoom: the wheel or a pinch, about the pointer.
## The camera never shows past the map's edges, as in the original. While a
## tool drag or a pan is held with the pointer at the view's edge, the view
## scrolls, as 1989's TileAutoScrollProc did.
##
## Auto-goto and a click on a notice's view glide the view to their place, as
## 1989's editor did: the game calls glide() once a loop.
##
## The chalk and the eraser draw on and rub out the chalk overlay (ChalkLayer)
## instead, following the pointer rather than stepping from tile to tile.
## Ctrl with a press holds a drag to a row or a column, once it has moved 16
## pixels one way (EditorTool's constrain_start), and Tab clicks where the
## pointer is (weditor.tcl). Over the view the pointer is a hand (hand2), and
## while panning the view shows 1989's pan cross instead of the tool.
##
## The map draws straight into the window's canvas, under a clip, rather than
## through a SubViewport, so it renders at the screen's full resolution on a
## Retina display.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name MapView
extends Control

## A click or drag applied the tool.
signal tool_used(tool: int)
## A click put the tool down, starting a drag (1989's EditorToolDown).
signal tool_started(tool: int)
## A glide reached its place (1989's DidStopPan, which played Skid).
signal glide_stopped

const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
## One wheel notch zooms by this factor.
const WHEEL_ZOOM := 1.1
## Arrow keys pan this many screen pixels a second.
const KEY_PAN_SPEED := 900.0
## A trackpad scroll pans this many screen pixels per unit of its delta.
const TRACKPAD_PAN := 12.0
## 1989's edge auto-scroll (w_tk.c): within AUTO_SCROLL_EDGE points of an edge,
## or past it, a drag moves the view AUTO_SCROLL_STEP points that way every
## AUTO_SCROLL_DELAY seconds (AutoScrollEdge 16, AutoScrollStep 16,
## AutoScrollDelay 10 ms).
const AUTO_SCROLL_EDGE := 16.0
const AUTO_SCROLL_STEP := 16.0
const AUTO_SCROLL_DELAY := 0.01
## At most this many steps catch up in one frame.
const MAX_AUTO_SCROLL_STEPS := 4
## 1989's glide (w_editor.c's HandleAutoGoto): GLIDE_SPEED map pixels a step
## (the view's auto_speed, 75), eased in over the first GLIDE_EASE steps
## (1/5, 2/5 ... of the speed); a place within GLIDE_NEAR map pixels isn't
## glided to at all (EditorCmdAutoGoal: "actually go there if more than a
## block away").
const GLIDE_SPEED := 75.0
const GLIDE_EASE := 5
const GLIDE_NEAR := 64.0

## How far a constrained drag moves before it locks to a row or a column.
const CONSTRAIN_FREE := 16.0

## Holds everything drawn in map coordinates: one unit is one pixel of a tile
## at zoom 1.
var world: Node2D
## The chalk overlay, over the sprites and under the cursor.
var chalk: ChalkLayer
## The pie menus, which the right button opens; set by the game window.
var pie: PieMenus
## A constrained drag: where it started, and the x or y it's held to (NAN when
## that coordinate is free), in map pixels; empty when there's none.
var constraint := {}
var city_map: CityMap
## The engine's trains, planes, monster and the rest, over the map.
var sprites: SpriteLayer
var cursor: ToolCursor
## The tool a left click applies.
var tool := CityEngine.Tool.BULLDOZER:
	set(value):
		tool = value
		cursor.tool = value
## The world point at the centre of the view, kept on the map.
var camera_position: Vector2:
	get:
		return _camera
	set(value):
		_camera = value
		_clamp_camera()

var _camera := Vector2.ZERO
var _zoom := 1.0
var _dragging := false
var _space_held := false
var _engine: CityEngine
var _painting := false
var _last_tile := Vector2i.ZERO
var _auto_scroll_clock := 0.0
## Where the glide is going, in map pixels, and its step (1989's auto_going:
## 0 when not gliding, then 1, 2 ...).
## An earthquake's shake (Shake), which moves the picture.
var shake := Shake.new()
var _glide_goal := Vector2.ZERO
var _glide_step := 0


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	city_map = CityMap.new()
	city_map.name = "CityMap"
	world.add_child(city_map)
	sprites = SpriteLayer.new()
	sprites.name = "Sprites"
	world.add_child(sprites)
	chalk = ChalkLayer.new()
	chalk.name = "Chalk"
	world.add_child(chalk)
	cursor = ToolCursor.new()
	cursor.name = "ToolCursor"
	cursor.visible = false
	world.add_child(cursor)
	resized.connect(_clamp_camera)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: cursor.visible = true)
	mouse_exited.connect(func() -> void: cursor.visible = false)


## Shows engine's city, drawn with tiles (default: CityMap's default art).
func setup(engine: CityEngine, tiles: Image = null) -> void:
	_engine = engine
	city_map.setup(engine, tiles)
	sprites.setup(engine)
	cursor.setup(engine, city_map)
	_zoom = 1.0
	center_on_tile(Vector2i(CityEngine.MAP_WIDTH / 2, CityEngine.MAP_HEIGHT / 2))


## The map's size in world pixels.
func map_size() -> Vector2:
	return Vector2(CityEngine.MAP_WIDTH, CityEngine.MAP_HEIGHT) * CityMap.TILE_SIZE


func get_zoom() -> float:
	return _zoom


## A point in this control to a world position on the map.
func screen_to_world(point: Vector2) -> Vector2:
	return camera_position + (point - size / 2.0) / _zoom


func world_to_screen(point: Vector2) -> Vector2:
	return (point - camera_position) * _zoom + size / 2.0


## The tile under a point in this control (may be off the map).
func tile_at(point: Vector2) -> Vector2i:
	return Vector2i((screen_to_world(point) / CityMap.TILE_SIZE).floor())


func center_on_tile(tile: Vector2i) -> void:
	camera_position = (Vector2(tile) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE


## Starts a glide to the centre of a tile, as 1989's AutoGoal did: false, and
## no glide, if the view is already within GLIDE_NEAR of it. A new glide
## replaces one under way and eases in afresh.
func glide_to_tile(tile: Vector2i) -> bool:
	_glide_goal = (Vector2(tile) + Vector2(0.5, 0.5)) * CityMap.TILE_SIZE
	var near := _camera.distance_squared_to(_on_map(_glide_goal)) <= GLIDE_NEAR * GLIDE_NEAR
	_glide_step = 0 if near else 1
	return not near


func is_gliding() -> bool:
	return _glide_step > 0


func stop_glide() -> void:
	_glide_step = 0


## Takes up to `steps` steps of the glide, as 1989 took one each time it drew
## the editor, and none while a tool or pan drag is held (its tool_mode 0
## test); the glide carries on after. The last step lands on the place and
## emits glide_stopped. Returns the steps taken.
func glide(steps: int) -> int:
	var taken := 0
	while taken < steps and _glide_step > 0 and not (_painting or _dragging):
		taken += 1
		# The place as the view can show it, which a zoom may have changed.
		var goal := _on_map(_glide_goal)
		var sloth := minf(float(_glide_step) / GLIDE_EASE, 1.0)
		var to_goal := goal - _camera
		var distance := to_goal.length()
		if distance < GLIDE_SPEED * sloth:
			_glide_step = 0
			camera_position = goal
			glide_stopped.emit()
		else:
			# 1989 added a half and truncated.
			var step := to_goal / distance * GLIDE_SPEED * sloth + Vector2(0.5, 0.5)
			camera_position = _camera + Vector2(int(step.x), int(step.y))
			_glide_step += 1
	return taken


## Moves the view by a distance in screen pixels: the map follows the pointer.
func pan_by_screen(delta: Vector2) -> void:
	camera_position -= delta / _zoom


## Zooms by factor, keeping the world point under `point` where it is.
func zoom_at(factor: float, point: Vector2) -> void:
	var before := screen_to_world(point)
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	camera_position += before - screen_to_world(point)


## The world rectangle the view shows.
func visible_world_rect() -> Rect2:
	var half := size / 2.0 / _zoom
	return Rect2(camera_position - half, half * 2.0)


func _draw() -> void:
	# Around a map smaller than the view.
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)


func _process(delta: float) -> void:
	if shake.is_shaking():
		shake.step(delta)
		_clamp_camera()
	auto_scroll(get_local_mouse_position(), delta)
	if not has_focus():
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if direction != Vector2.ZERO:
		pan_by_screen(-direction * KEY_PAN_SPEED * delta)


func _gui_input(event: InputEvent) -> void:
	# While a pie is open, its press's moves and release are the pie's.
	if pie != null and pie.is_open() and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var forwarded := event.duplicate() as InputEventMouse
		forwarded.position = forwarded.global_position
		pie.handle(forwarded)
		accept_event()
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		cursor.pointer = screen_to_world(event.position)
		if _dragging:
			pan_by_screen(_constrained_delta(event.relative))
			accept_event()
		else:
			_hover(event.position)
	elif event is InputEventPanGesture:
		pan_by_screen(-event.delta * TRACKPAD_PAN)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
		accept_event()
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		_space_held = event.pressed
		if not event.pressed:
			_set_panning(false)
		accept_event()
	elif event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		click_at(get_local_mouse_position())
		accept_event()


func _mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				var notches := event.factor if event.factor > 0.0 else 1.0
				var step := pow(WHEEL_ZOOM, notches)
				zoom_at(step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step, event.position)
			accept_event()
		MOUSE_BUTTON_MIDDLE:
			_constrain(event)
			_set_panning(event.pressed)
			if event.pressed:
				grab_focus()
			accept_event()
		MOUSE_BUTTON_RIGHT:
			# InitPie's <3>: the Tool pie, centred on the pointer.
			if event.pressed and pie != null:
				grab_focus()
				pie.open(event.global_position)
			accept_event()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
			if event.pressed and event.shift_pressed and pie != null and not _space_held:
				# InitPie's <Shift-1>.
				pie.open(event.global_position)
				accept_event()
				return
			_constrain(event)
			if _space_held or (not event.pressed and _dragging):
				_set_panning(event.pressed)
			elif event.pressed:
				_press(event.position)
			else:
				_painting = false
				cursor.pressed = false
			accept_event()


## Applies the tool at a tile, as a click does, and starts a drag from it.
func click_tile(tile: Vector2i) -> void:
	_apply_tool(tile)
	_painting = false


## A click where a point in the view is, down and up at once, as Tab did.
func click_at(point: Vector2) -> void:
	_press(point)
	_painting = false
	cursor.pressed = false


## The tool goes down at a point in the view: the chalk starts a stroke, the
## eraser rubs out, and every other tool is applied at the tile there.
func _press(point: Vector2) -> void:
	var at := screen_to_world(point)
	cursor.pointer = at
	cursor.pressed = true
	match tool:
		Tools.CHALK:
			tool_started.emit(tool)
			chalk.start(at + ChalkLayer.TIP)
			_painting = true
			tool_used.emit(tool)
		Tools.ERASER:
			tool_started.emit(tool)
			chalk.erase_at(at)
			_painting = true
			tool_used.emit(tool)
		_:
			_apply_tool(tile_at(point))


## Starts or ends a constrained drag: Ctrl with the press holds it until it
## has moved 16 pixels one way, then to that row or column.
func _constrain(event: InputEventMouseButton) -> void:
	if event.pressed and event.ctrl_pressed:
		var at := screen_to_world(event.position)
		constraint = {start = at, x = at.x, y = at.y}
	elif not event.pressed:
		constraint = {}


## A point in the view as the constraint holds it.
func constrained(point: Vector2) -> Vector2:
	if constraint.is_empty():
		return point
	var at := screen_to_world(point)
	if not is_nan(constraint.x) and not is_nan(constraint.y):
		var moved: Vector2 = at - constraint.start
		if absf(moved.x) > CONSTRAIN_FREE:
			constraint.x = NAN
		elif absf(moved.y) > CONSTRAIN_FREE:
			constraint.y = NAN
	if not is_nan(constraint.x):
		at.x = constraint.x
	if not is_nan(constraint.y):
		at.y = constraint.y
	return world_to_screen(at)


## A pan drag's move, as the constraint holds it.
func _constrained_delta(delta: Vector2) -> Vector2:
	if constraint.is_empty():
		return delta
	var pointer := get_local_mouse_position()
	var before := constrained(pointer - delta)
	return constrained(pointer) - before


## A pan starts or ends: the pan cross shows instead of the tool (tool mode -1).
func _set_panning(on: bool) -> void:
	_dragging = on
	cursor.panning = on


## Paints the tool from one tile to another, as a drag does.
func drag_tiles(from: Vector2i, to: Vector2i) -> void:
	_engine.tool_drag(tool, from.x, from.y, to.x, to.y)
	city_map.sync()
	tool_used.emit(tool)


func _apply_tool(tile: Vector2i) -> void:
	if _engine == null:
		return
	tool_started.emit(tool)
	_engine.tool_down(tool, tile.x, tile.y)
	city_map.sync()
	_painting = true
	_last_tile = tile
	cursor.tile = tile
	tool_used.emit(tool)


func _hover(point: Vector2) -> void:
	point = constrained(point)
	var tile := tile_at(point)
	cursor.visible = true
	cursor.tile = tile
	cursor.pointer = screen_to_world(point)
	if not _painting:
		return
	match tool:
		Tools.CHALK:
			chalk.add(screen_to_world(point) + ChalkLayer.TIP)
		Tools.ERASER:
			chalk.erase_at(screen_to_world(point))
		_:
			if tile != _last_tile and Tools.drags(tool):
				drag_tiles(_last_tile, tile)
				_last_tile = tile


## 1989's edge auto-scroll, for delta seconds with the pointer at `pointer` (in
## this control): during a tool drag the view moves toward the edge the
## pointer is at, and the tool paints on to the tile under it; during a pan
## drag it moves the other way, as 1989's did for its pan (tool mode -1).
## Returns how many steps it moved.
func auto_scroll(pointer: Vector2, delta: float) -> int:
	var direction := Vector2(_edge(pointer.x, size.x), _edge(pointer.y, size.y))
	if not (_painting or _dragging) or direction == Vector2.ZERO:
		_auto_scroll_clock = 0.0
		return 0
	if _dragging:
		direction = -direction
	_auto_scroll_clock += delta
	var steps := mini(floori(_auto_scroll_clock / AUTO_SCROLL_DELAY), MAX_AUTO_SCROLL_STEPS)
	_auto_scroll_clock = minf(_auto_scroll_clock - steps * AUTO_SCROLL_DELAY, AUTO_SCROLL_DELAY)
	if steps > 0:
		camera_position += direction * AUTO_SCROLL_STEP * steps / _zoom
		if _painting:
			_hover(pointer)
	return steps


## -1, 0 or 1: whether a coordinate is at the low edge, inside, or at the
## high edge of a length.
static func _edge(at: float, length: float) -> float:
	if at < AUTO_SCROLL_EDGE:
		return -1.0
	if at > length - AUTO_SCROLL_EDGE:
		return 1.0
	return 0.0


## Keeps the view on the map, then places the world under it.
func _clamp_camera() -> void:
	_camera = _on_map(_camera)
	if world != null:
		world.scale = Vector2(_zoom, _zoom)
		world.position = size / 2.0 - _camera * _zoom + shake.offset
		cursor.zoom = _zoom


## The nearest point to `point` the view's centre can be on: the map's
## centre along an axis the whole map fits in, and never past an edge.
func _on_map(point: Vector2) -> Vector2:
	var half := size / 2.0 / _zoom
	var map := map_size()
	for axis in 2:
		if map[axis] <= half[axis] * 2.0:
			point[axis] = map[axis] / 2.0
		else:
			point[axis] = clampf(point[axis], half[axis], map[axis] - half[axis])
	return point
