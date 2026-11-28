class_name Vehicle
extends CharacterBody3D
## Arcade car / bike. Kinematic (no wheel physics), so it never sinks, flips or drives backwards.
## Forward is -Z. Steering positive = left.

var spec: Dictionary = {}
var vid: String = ""
var owned: bool = false
var is_taxi: bool = false
var is_bike: bool = false
var driver_is_player: bool = false
var ai_on: bool = false
var route: Array = []
var route_done: Callable = Callable()
var power: float = 2000.0
var max_speed: float = 30.0
var mass: float = 1000.0
var cruise: float = 11.0
var driver: Node3D = null
var speed: float = 0.0
var steer_ang: float = 0.0
var wheelbase: float = 2.6
var linear_velocity: Vector3:
	get:
		return velocity
var _ray: RayCast3D
var _rev_t: float = 0.0
var _stuck_t: float = 0.0
var _blocked: bool = false
var _blocked_t: float = 0.0
var _eng: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _crash: AudioStreamPlayer3D
var _eng_ui: AudioStreamPlayer
var _horn_ui: AudioStreamPlayer
var _horn_t: float = 0.0
var _hlights: Array = []
var _wheels: Array = []
var _wr: float = 0.35

static func mat(c: Color, a: float = 1.0, rough: float = 0.5, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = rough
	m.metallic = metal
	return m

static func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi

static func build_mesh(s: Dictionary) -> Node3D:
	var root := Node3D.new()
	var dim: Vector3 = s["dim"]
	var col: Color = s["color"]
	var body_m := mat(col, 1.0, 0.35, 0.4)
	var glass := mat(Color(0.12, 0.18, 0.24), 0.45, 0.1, 0.0)
	var dark := mat(Color(0.05, 0.05, 0.06))
	if s.get("bike", false):
		_box(root, Vector3(0, 0.55, 0.1), Vector3(dim.x * 0.6, 0.3, dim.z * 0.55), body_m)
		_box(root, Vector3(0, 0.8, 0.25), Vector3(dim.x * 0.5, 0.1, dim.z * 0.3), dark)
		_box(root, Vector3(0, 0.75, -dim.z * 0.38), Vector3(0.12, 0.7, 0.12), dark)
		_box(root, Vector3(0, 1.1, -dim.z * 0.36), Vector3(dim.x * 1.0, 0.07, 0.07), dark)
		var hm := mat(Color(1, 1, 0.8))
		hm.emission_enabled = true
		hm.emission = Color(1, 0.95, 0.7)
		_box(root, Vector3(0, 0.95, -dim.z * 0.46), Vector3(0.2, 0.15, 0.1), hm)
		return root
	var h_low := dim.y * 0.42
	var h_cab := dim.y * 0.58
	_box(root, Vector3(0, 0.3 + h_low * 0.5, 0), Vector3(dim.x, h_low, dim.z), body_m)
	var cab_len := dim.z * 0.5
	if s["id"] == "pickup":
		cab_len = dim.z * 0.38
	var cab_z := dim.z * 0.05
	if s["id"] == "pickup":
		cab_z = -dim.z * 0.12
	_box(root, Vector3(0, 0.3 + h_low + h_cab * 0.5, cab_z), Vector3(dim.x * 0.92, h_cab, cab_len), glass)
	_box(root, Vector3(0, 0.3 + h_low + h_cab, cab_z), Vector3(dim.x * 0.94, 0.06, cab_len + 0.05), body_m)
	var tail := mat(Color(0.8, 0.05, 0.05))
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.05)
	var head := mat(Color(1, 1, 0.85))
	head.emission_enabled = true
	head.emission = Color(1, 0.95, 0.75)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(sx * dim.x * 0.36, 0.3 + h_low * 0.65, -dim.z * 0.5), Vector3(0.3, 0.14, 0.06), head)
		_box(root, Vector3(sx * dim.x * 0.36, 0.3 + h_low * 0.65, dim.z * 0.5), Vector3(0.3, 0.14, 0.06), tail)
	if s.get("taxi", false):
		var orange := mat(Color(0.98, 0.55, 0.05))
		_box(root, Vector3(dim.x * 0.501, 0.3 + h_low * 0.45, 0), Vector3(0.03, 0.18, dim.z * 0.8), orange)
		_box(root, Vector3(-dim.x * 0.501, 0.3 + h_low * 0.45, 0), Vector3(0.03, 0.18, dim.z * 0.8), orange)
		var sign_m := mat(Color(0.98, 0.7, 0.1))
		sign_m.emission_enabled = true
		sign_m.emission = Color(1, 0.7, 0.1)
		_box(root, Vector3(0, 0.3 + h_low + h_cab + 0.14, cab_z), Vector3(0.55, 0.2, 0.25), sign_m)
	return root

func setup(s: Dictionary) -> void:
	spec = s
	vid = s["id"]
	is_taxi = s.get("taxi", false)
	is_bike = s.get("bike", false)
	power = s["power"]
	max_speed = s["max_speed"]
	mass = s["mass"]
	var dim: Vector3 = s["dim"]
	wheelbase = maxf(dim.z * 0.6, 1.0)
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(dim.x, dim.y * 0.9, dim.z)
	cs.shape = bs
	cs.position = Vector3(0, 0.3 + dim.y * 0.45, 0)
	add_child(cs)
	add_child(build_mesh(s))
	_wr = 0.3 if is_bike else 0.35
	var track := 0.22 if is_bike else dim.x * 0.5 - 0.05
	var zf := -dim.z * 0.33
	var zr := dim.z * 0.33
	for i in 4:
		var front := i < 2
		var left := i % 2 == 0
		var pivot := Node3D.new()
		pivot.position = Vector3(-track if left else track, _wr, zf if front else zr)
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var wm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = _wr
		cm.bottom_radius = _wr
		cm.height = 0.25
		cm.radial_segments = 14
		cm.rings = 1
		wm.mesh = cm
		wm.rotation_degrees = Vector3(0, 0, 90)
		wm.material_override = mat(Color(0.04, 0.04, 0.04), 1.0, 0.9)
		spin.add_child(wm)
		var hub := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.27, 0.12, 0.12)
		hub.mesh = hb
		hub.material_override = mat(Color(0.75, 0.75, 0.78), 1.0, 0.3, 0.8)
		spin.add_child(hub)
		_wheels.append({"pivot": pivot, "spin": spin, "front": front})
	_ray = RayCast3D.new()
	_ray.position = Vector3(0, 0.8, -dim.z * 0.5)
	_ray.target_position = Vector3(0, 0, -9.0)
	_ray.collision_mask = 2 | 4 | 8
	add_child(_ray)
	_eng = AudioStreamPlayer3D.new()
	_eng.stream = Sfx.get_sound("engine")
	_eng.unit_size = 12.0
	_eng.max_distance = 90.0
	_eng.volume_db = -4.0
	add_child(_eng)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = Sfx.get_sound("horn")
	_horn.unit_size = 16.0
	_horn.max_distance = 100.0
	add_child(_horn)
	_crash = AudioStreamPlayer3D.new()
	_crash.stream = Sfx.get_sound("crash")
	_crash.unit_size = 14.0
	add_child(_crash)
	_eng_ui = AudioStreamPlayer.new()
	_eng_ui.stream = Sfx.get_sound("engine")
	_eng_ui.volume_db = -6.0
	add_child(_eng_ui)
	_horn_ui = AudioStreamPlayer.new()
	_horn_ui.stream = Sfx.get_sound("horn")
	_horn_ui.volume_db = -3.0
	add_child(_horn_ui)
	var xs: Array = [0.0] if is_bike else [-dim.x * 0.35, dim.x * 0.35]
	for x in xs:
		var sl := SpotLight3D.new()
		sl.position = Vector3(x, 0.8, -dim.z * 0.5)
		sl.rotation_degrees.x = -4.0
		sl.spot_range = 35.0
		sl.spot_angle = 38.0
		sl.light_energy = 3.0
		sl.visible = false
		add_child(sl)
		_hlights.append(sl)

func set_driver(model: Node3D) -> void:
	if driver != null:
		driver.queue_free()
	driver = model
	var dim: Vector3 = spec["dim"]
	add_child(model)
	model.scale = Vector3.ONE * 0.85
	var seat_y := 0.85 if is_bike else 0.7
	var sx := 0.0 if is_bike else -dim.x * 0.24
	var sz := 0.2 if is_bike else dim.z * 0.06
	if model is PlayerCharacter:
		model.position = Vector3(sx, seat_y - PlayerCharacter.SIT_HIPS * 0.85, sz)
		(model as PlayerCharacter).play("Sit", 0.0)
		return
	var hm := model as HumanModel
	hm.position = Vector3(sx, seat_y - 0.82 * 0.85, sz)
	hm.pose_seated()
	if is_bike:
		hm.leg_l.rotation.x = 1.0
		hm.leg_r.rotation.x = 1.0
		hm.knee_l.rotation.x = -1.3
		hm.knee_r.rotation.x = -1.3

func remove_driver() -> void:
	if driver != null:
		driver.queue_free()
		driver = null

func start_ai(r: Array, spd: float = 11.0) -> void:
	ai_on = true
	route = r
	cruise = spd

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_in := 0.0
	var brk := 0.0
	if driver_is_player:
		var v := Game.move_vec()
		throttle = -v.y
		steer_in = -v.x
		if Input.is_action_pressed("brake"):
			brk = 1.0
	elif ai_on:
		var r := _ai_inputs(delta, speed)
		throttle = r.x
		steer_in = r.y
		brk = r.z
	else:
		brk = 1.0
	_update_audio(delta, throttle)
	if not driver_is_player and not ai_on and absf(speed) < 0.01:
		return
	var acc := clampf(power / mass * 1.8, 3.0, 8.0)
	var target := 0.0
	if throttle > 0.0:
		target = max_speed * throttle
	elif throttle < 0.0:
		target = -max_speed * 0.3 * -throttle
	var rate := acc
	if brk > 0.0:
		target = 0.0
		rate = 14.0
	elif absf(throttle) < 0.05:
		rate = 2.5
	elif signf(target) != signf(speed) and absf(speed) > 0.5:
		rate = 12.0
	speed = move_toward(speed, target, rate * delta)
	var lim := 0.55 / (1.0 + absf(speed) * 0.06)
	steer_ang = move_toward(steer_ang, steer_in * lim, 2.5 * delta)
	if absf(speed) > 0.05:
		rotate_y(speed * tan(steer_ang) / wheelbase * delta)
	var fwd := -global_transform.basis.z
	velocity = fwd * speed
	var before := speed
	move_and_slide()
	global_position.y = 0.0
	var real := get_real_velocity().dot(fwd)
	if absf(real) < absf(speed):
		speed = real
	if before - speed > 6.0 and absf(before) > 6.0:
		if driver_is_player:
			Game.play_ui("crash")
		else:
			_crash.play()
	_spin_wheels(delta)

func _spin_wheels(delta: float) -> void:
	for w in _wheels:
		var sp: Node3D = w["spin"]
		sp.rotation.x -= speed * delta / _wr
		if w["front"]:
			(w["pivot"] as Node3D).rotation.y = steer_ang

func _update_audio(delta: float, throttle: float) -> void:
	var active := driver_is_player or ai_on
	var sp := clampf(absf(speed) / max_speed, 0.0, 1.2)
	var pitch := 0.6 + sp * 1.8 + absf(throttle) * 0.25
	if driver_is_player:
		if _eng.playing:
			_eng.stop()
		if not _eng_ui.playing:
			_eng_ui.play()
		_eng_ui.pitch_scale = pitch
		_eng_ui.volume_db = -9.0 + absf(throttle) * 4.0 + sp * 3.0
	else:
		if _eng_ui.playing:
			_eng_ui.stop()
		if ai_on:
			if not _eng.playing:
				_eng.play()
			_eng.pitch_scale = pitch
			_eng.volume_db = -5.0 + sp * 3.0
		elif _eng.playing:
			_eng.stop()
	var honk := (driver_is_player and Input.is_action_pressed("horn")) or _horn_t > 0.0
	_horn_t = maxf(0.0, _horn_t - delta)
	var hp = _horn_ui if driver_is_player else _horn
	var other = _horn if driver_is_player else _horn_ui
	if other.playing:
		other.stop()
	if honk and not hp.playing:
		hp.play()
	elif not honk and hp.playing:
		hp.stop()
	var lit := driver_is_player and Game.night > 0.35
	for l in _hlights:
		l.visible = lit
	if not active and speed != 0.0:
		speed = move_toward(speed, 0.0, 10.0 * delta)

func _light_dist() -> float:
	var tl = Game.lights
	if tl == null:
		return INF
	var f := -global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		return INF
	var along_z := absf(f.z) > absf(f.x)
	var dir := signf(f.z) if along_z else signf(f.x)
	var pos := global_position.z if along_z else global_position.x
	var lat := global_position.x if along_z else global_position.z
	if absf(lat - roundf(lat / Nav.B) * Nav.B) > Nav.R:
		return INF
	var c := (ceilf(pos / Nav.B) if dir > 0.0 else floorf(pos / Nav.B)) * Nav.B
	var d := (c - pos) * dir - (Nav.R + 2.0)
	if d < -2.0 or d > 30.0:
		return INF
	var st: int = tl.state(along_z)
	if st == 0:
		return INF
	if st == 1 and d < 6.0:
		return INF
	return maxf(d, 0.0)

func _ai_inputs(delta: float, fwd_speed: float) -> Vector3:
	if route.is_empty():
		return Vector3(0, 0, 1)
	_blocked = false
	if _ray.is_colliding():
		var c := _ray.get_collider()
		if c is Vehicle or c is CharacterBody3D:
			_blocked = true
	if _blocked:
		_blocked_t += delta
		if _blocked_t > 2.5 and _horn_t <= 0.0:
			_horn_t = 0.5
		if _blocked_t > 6.0:
			_rev_t = 1.5
			_blocked_t = 0.0
		return Vector3(0, 0, 1)
	_blocked_t = 0.0
	if _rev_t > 0.0:
		_rev_t -= delta
		return Vector3(-0.8, 0.0, 0.0)
	var target: Vector3 = route[0]
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 5.0:
		route.pop_front()
		if route.is_empty():
			if route_done.is_valid():
				route_done.call(self)
			return Vector3(0, 0, 1)
		return Vector3(0.3, 0, 0)
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)
	var steer := clampf(ang * 1.6, -1.0, 1.0)
	var want := cruise
	if absf(ang) > 0.6:
		want = 4.5
	if dist < 14.0:
		want = minf(want, 7.0)
	if route.size() == 1:
		want = minf(want, clampf(dist * 0.5, 2.0, cruise))
	var ld := _light_dist()
	if ld < INF:
		want = minf(want, ld * 0.6)
		if ld < 1.5:
			want = 0.0
	var thr := clampf((want - fwd_speed) * 0.4, -1.0, 1.0)
	var b := 0.0
	if thr < 0.0:
		b = clampf(-thr, 0.0, 1.0)
		thr = 0.0
	if absf(fwd_speed) < 0.4 and thr > 0.2:
		_stuck_t += delta
		if _stuck_t > 2.5:
			_stuck_t = 0.0
			_rev_t = 1.2
	else:
		_stuck_t = 0.0
	return Vector3(thr, steer, b)
