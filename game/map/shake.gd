## The earthquake's shake, as the OLPC drew it (w_tk.c's DoEarthQuake and
## StopEarthquake, w_editor.c, w_map.c): each quake adds one to ShakeNow, and
## 3 seconds after the last it stops. While it lasts, each redraw moves the
## picture by the sum, for each quake, of a number from -8 to 8 across and
## another down: the editor by that offset, the map the other way.
##
## The OLPC took those numbers from the simulation's own Rand(), so the shake
## changed the city's random sequence. These come from their own generator,
## so the city runs the same with or without a picture drawn.
##
## Part of Metrobits: GPLv3 with Electronic Arts' additional terms (see
## LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).
class_name Shake
extends RefCounted

## earthquake_delay: 3,000 ms.
const SECONDS := 3.0

## How many quakes are shaking (ShakeNow), and the offset now.
var count := 0
var offset := Vector2.ZERO
var rng := RandomNumberGenerator.new()

var _left := 0.0


func _init() -> void:
	rng.randomize()


## A quake: one more, and 3 seconds from now.
func start() -> void:
	count += 1
	_left = SECONDS


func stop() -> void:
	count = 0
	_left = 0.0
	offset = Vector2.ZERO


func is_shaking() -> bool:
	return count > 0


## Moves on by delta seconds; returns the offset for this redraw.
func step(delta: float) -> Vector2:
	if count == 0:
		return Vector2.ZERO
	_left -= delta
	if _left <= 0.0:
		stop()
		return offset
	offset = Vector2.ZERO
	for i in count:
		# Rand(16) is 0 to 16.
		offset += Vector2(rng.randi_range(0, 16) - 8, rng.randi_range(0, 16) - 8)
	return offset
