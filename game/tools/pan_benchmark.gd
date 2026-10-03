## Measures the frame rate while the camera pans across the whole 120x100 map
## with the sim running at the Priority (Normal unless --priority= says), the
## map window open, and with --graph the graph window too. Run it windowed,
## not headless:
##   godot --path game -- --benchmark
## It sweeps the map row by row at each zoom in ZOOMS, then prints the average
## and lowest frames per second (Godot's Performance monitor, sampled every
## second) and the slowest single frame. Under vsync the frame rate can't pass
## the display's, so it also prints the headroom: the time the sim and map
## redraw took each frame (main.advance) and the viewport's render time on the
## CPU and GPU, average and worst, and the most sprites drawn at once. Then it
## quits. With --sprites it first sets off a tornado and a monster, so the
## sprite layer has more than the city's own trains, ships and aircraft.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name PanBenchmark
extends Node

const ZOOMS := [1.0, 2.0, 0.5, 0.25]
## Screen pixels a second the view moves.
const SPEED := 1500.0
const WARM_UP := 1.0

var _main: Node
var _view: MapView
var _path: Array[Vector2] = []
var _target := 0
var _zoom := 0
var _elapsed := 0.0
var _frames := 0
var _worst := 0.0
var _cost := {advance = [0.0, 0.0], render_cpu = [0.0, 0.0], render_gpu = [0.0, 0.0]}
var _samples: Array[float] = []
var _since_sample := 0.0
var _warming := WARM_UP
var _most_sprites := 0
var _refreshes := 0
var _refresh_usec := [0, 0]
var _refresh_count := 0
var _loops := 0


func run(main: Node, disasters := false, graph := false) -> void:
	_main = main
	# The year's budget, or running out of money, would stop the sim for the
	# player; at Super Fast a century goes by in the run.
	main.engine.set_auto_budget(true)
	main.engine.set_funds(10000000)
	if graph:
		main.open_graph()
	if disasters:
		main.trigger_disaster(main.DisasterItem.TORNADO)
		main.trigger_disaster(main.DisasterItem.MONSTER)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_view = main.map_view
	_start_zoom()


func _start_zoom() -> void:
	var zoom: float = ZOOMS[_zoom]
	_view.zoom_at(zoom / _view.get_zoom(), _view.size / 2.0)
	# A serpentine over the map, one view height apart, row by row.
	var view := _view.visible_world_rect().size
	var map := _view.map_size()
	_path.clear()
	var y := view.y / 2.0
	var left := true
	while true:
		_path.append(Vector2(view.x / 2.0 if left else map.x - view.x / 2.0, y))
		_path.append(Vector2(map.x - view.x / 2.0 if left else view.x / 2.0, y))
		left = not left
		if y >= map.y - view.y / 2.0:
			break
		y = minf(y + view.y * 0.75, map.y - view.y / 2.0)
	# Aim only where the view can go: it stays on the map.
	for i in _path.size():
		_view.camera_position = _path[i]
		_path[i] = _view.camera_position
	_view.camera_position = _path[0]
	_target = 1


func _process(delta: float) -> void:
	if _main == null:
		return
	if _warming > 0.0:
		_warming -= delta
		return
	_frames += 1
	_elapsed += delta
	_most_sprites = maxi(_most_sprites, _view.sprites.sprites.size())
	_worst = maxf(_worst, delta)
	var viewport := get_viewport().get_viewport_rid()
	_add_cost("advance", _main.last_advance_usec / 1000.0)
	_loops += _main.last_loops
	if _main.map_window.refreshes != _refreshes:
		_refreshes = _main.map_window.refreshes
		_refresh_count += 1
		_refresh_usec[0] += _main.map_window.last_refresh_usec
		_refresh_usec[1] = maxi(_refresh_usec[1], _main.map_window.last_refresh_usec)
	_add_cost("render_cpu", RenderingServer.viewport_get_measured_render_time_cpu(viewport))
	_add_cost("render_gpu", RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	_since_sample += delta
	if _since_sample >= 1.0:
		_since_sample -= 1.0
		_samples.append(Performance.get_monitor(Performance.TIME_FPS))
	var step := SPEED * delta / _view.get_zoom()
	_view.camera_position = _view.camera_position.move_toward(_path[_target], step)
	if _view.camera_position.distance_to(_path[_target]) < 0.5:
		_target += 1
		if _target >= _path.size():
			_zoom += 1
			if _zoom >= ZOOMS.size():
				_finish()
				return
			_start_zoom()


func _add_cost(key: String, ms: float) -> void:
	_cost[key][0] += ms
	_cost[key][1] = maxf(_cost[key][1], ms)


func _cost_text(key: String) -> String:
	return "%.2f/%.2f ms" % [_cost[key][0] / _frames, _cost[key][1]]


func _finish() -> void:
	var low: float = _samples.min() if not _samples.is_empty() else 0.0
	var line := "BENCHMARK pan: %d frames in %.1f s, average %.1f fps, lowest %.0f fps (per-second monitor), slowest frame %.1f ms; average/worst per frame: sim and map %s, render CPU %s, render GPU %s; up to %d sprites; zooms %s, window %s, city %s, priority %s (%.0f loops a second), map window %s, graph window %s" % [
		_frames, _elapsed, _frames / _elapsed, low, _worst * 1000.0,
		_cost_text("advance"), _cost_text("render_cpu"), _cost_text("render_gpu"), _most_sprites, ZOOMS,
		_main.get_window().size, _main.engine.get_city_name(), _main.PRIORITY_NAMES[_main.priority], _loops / _elapsed,
		_main.map_window.visible, _main.graph_window.visible]
	if _refresh_usec[0] > 0:
		line += "; map window redraws (%d a second) average/worst %.2f/%.2f ms" % [
			roundi(1.0 / MapWindow.REFRESH_SECONDS), _refresh_usec[0] / 1000.0 / maxi(1, _refresh_count),
			_refresh_usec[1] / 1000.0]
	print(line)
	_main = null
	get_tree().quit()
