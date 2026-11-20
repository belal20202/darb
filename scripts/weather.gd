class_name Weather
extends Node
## Weather: clear, cloudy, rain (with thunder), dust storm, fog. Probabilities depend on the season.

const NAMES := ["صافي", "غائم", "مطر", "غبار", "ضباب"]
const SEASON_NAMES := ["الربيع", "الصيف", "الخريف", "الشتاء"]
const TABLE := [
	[0.45, 0.25, 0.2, 0.1, 0.0],
	[0.8, 0.05, 0.0, 0.15, 0.0],
	[0.55, 0.25, 0.1, 0.1, 0.0],
	[0.3, 0.3, 0.3, 0.0, 0.1],
]
const BASE_TEMP := [24.0, 42.0, 28.0, 12.0]
const CLOUD := [0.0, 0.6, 0.9, 0.5, 0.4]

var world: Node3D
var kind: int = 0
var cloud: float = 0.0
var rain: float = 0.0
var dust: float = 0.0
var mist: float = 0.0
var flash: float = 0.0
var _timer: float = 60.0
var _thunder_t: float = 15.0
var _fx: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _wind_snd: AudioStreamPlayer
var _thunder: AudioStreamPlayer

func _ready() -> void:
	_fx = GPUParticles3D.new()
	_fx.amount = 700
	_fx.lifetime = 1.1
	_fx.local_coords = false
	_fx.visibility_aabb = AABB(Vector3(-30, -25, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -9.8, 0)
	_fx.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.45, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.82, 0.95, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	_fx.draw_pass_1 = bm
	_fx.emitting = false
	add_child(_fx)
	_rain_snd = _make_player("rain", true)
	_wind_snd = _make_player("wind", true)
	_thunder = _make_player("thunder", false)
	_choose()
	_snap()

func _make_player(n: String, _loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_sound(n)
	p.volume_db = -40.0
	add_child(p)
	return p

func _choose() -> void:
	var row: Array = TABLE[Game.season]
	var r := randf()
	var acc := 0.0
	for i in row.size():
		acc += row[i]
		if r <= acc:
			kind = i
			break
	_timer = randf_range(90.0, 180.0)

func _targets() -> Array:
	return [CLOUD[kind], 1.0 if kind == 2 else 0.0, 1.0 if kind == 3 else 0.0, 1.0 if kind == 4 else 0.0]

func _snap() -> void:
	var t := _targets()
	cloud = t[0]
	rain = t[1]
	dust = t[2]
	mist = t[3]

func temp(h: float) -> float:
	return BASE_TEMP[Game.season] + 7.0 * sin((h - 9.0) / 24.0 * TAU) - rain * 4.0 + dust * 2.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_choose()
	var t := _targets()
	var k := clampf(delta / 8.0, 0.0, 1.0)
	cloud = lerpf(cloud, t[0], k)
	rain = lerpf(rain, t[1], k)
	dust = lerpf(dust, t[2], k)
	mist = lerpf(mist, t[3], k)
	var pl = world.player
	if pl != null:
		_fx.global_position = pl.global_position + Vector3(0, 14, 0)
	_fx.emitting = rain > 0.05 and world.in_shop < 0
	_fx.amount_ratio = clampf(rain, 0.05, 1.0)
	var indoors: bool = world.in_shop >= 0
	_set_snd(_rain_snd, rain > 0.03 and not indoors, lerpf(-40.0, -8.0, rain))
	_set_snd(_wind_snd, dust > 0.05 and not indoors, lerpf(-40.0, -6.0, dust))
	flash = maxf(0.0, flash - delta * 4.0)
	if rain > 0.6:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(12.0, 35.0)
			flash = 1.0
			get_tree().create_timer(0.5).timeout.connect(func(): _thunder.play())

func _set_snd(p: AudioStreamPlayer, on: bool, db: float) -> void:
	if on:
		p.volume_db = db
		if not p.playing:
			p.play()
	elif p.playing:
		p.stop()
