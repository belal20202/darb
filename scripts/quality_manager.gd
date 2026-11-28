class_name QualityManager
extends Node
## Automatic graphics quality: picks a start level from the device, then raises or lowers
## the 3D resolution, shadows and draw distance depending on the real frame rate.

const BUDGET := [0.9e6, 1.4e6, 2.0e6, 3.0e6]      # 3D pixels per frame for levels 0..3
const FAR := [140.0, 200.0, 260.0, 320.0]
const CULL := [50.0, 70.0, 90.0, 110.0]
const RAIN := [0.3, 0.5, 0.8, 1.0]
const MANUAL := [0, 1, 3]

var world: Node3D
var level: int = 1
var auto_mode: bool = true
var _acc: float = 0.0
var _low: int = 0
var _high: int = 0
var _cool: float = 0.0
var _warm: float = 6.0

func _ready() -> void:
	auto_mode = Game.quality >= 3
	if auto_mode:
		level = Game.tier
	else:
		level = MANUAL[clampi(Game.quality, 0, 2)]

func apply() -> void:
	var vp := get_viewport()
	var win := DisplayServer.window_get_size()
	var px := float(maxi(win.x * win.y, 1))
	vp.scaling_3d_scale = clampf(sqrt(float(BUDGET[level]) / px), 0.4, 1.0)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var sun: DirectionalLight3D = world.sun
	sun.shadow_enabled = level >= 2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0 if level == 2 else 80.0
	world.player.cam.far = FAR[level]
	world.env.glow_enabled = level >= 2
	world.cull_dist = CULL[level]
	if world.weather != null:
		world.weather.fx_scale = RAIN[level]

func _process(delta: float) -> void:
	if not auto_mode:
		return
	_warm -= delta
	if _warm > 0.0:
		return
	_acc += delta
	_cool -= delta
	if _acc < 1.0:
		return
	_acc = 0.0
	var fps := Engine.get_frames_per_second()
	if fps < 42.0:
		_low += 1
		_high = 0
	elif fps > 57.0:
		_high += 1
		_low = 0
	else:
		_low = 0
		_high = 0
	if _low >= 3 and level > 0:
		level -= 1
		_low = 0
		_cool = 25.0
		apply()
	elif _high >= 15 and level < 3 and _cool <= 0.0:
		level += 1
		_high = 0
		apply()
