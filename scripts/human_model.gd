class_name HumanModel
extends Node3D
## Low-poly procedural human (pedestrians, AI drivers, fallback player). Has knees so seating looks right.

var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var held: Node3D = null
var armed: bool = false
var seated: bool = false
var _t: float = 0.0

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

static func _m(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	_mats[k] = m
	return m

static func _caps(r: float, h: float) -> CapsuleMesh:
	var k := "c%.3f_%.3f" % [r, h]
	if _meshes.has(k):
		return _meshes[k]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 3
	_meshes[k] = m
	return m

static func _sph(r: float) -> SphereMesh:
	var k := "s%.3f" % r
	if _meshes.has(k):
		return _meshes[k]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	_meshes[k] = m
	return m

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var k := "b%.3f_%.3f_%.3f" % [x, y, z]
	if _meshes.has(k):
		return _meshes[k]
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	_meshes[k] = m
	return m

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _m(c)
	parent.add_child(mi)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func build(shirt: Color, pants: Color, skin: Color, robe: bool = false, head_item: String = "") -> void:
	for c in get_children():
		c.queue_free()
	held = null
	_part(self, _caps(0.24, 0.75), Vector3(0, 1.15, 0), shirt)
	_part(self, _sph(0.15), Vector3(0, 1.72, 0), skin)
	_part(self, _sph(0.155), Vector3(0, 1.79, 0.02), Color(0.08, 0.06, 0.05))
	if head_item == "ghutra":
		_part(self, _sph(0.19), Vector3(0, 1.77, 0.01), Color(0.96, 0.96, 0.96))
	var shoe := Color(0.08, 0.08, 0.08)
	for side in 2:
		var sx := -0.11 if side == 0 else 0.11
		var hip := _pivot(self, Vector3(sx, 0.82, 0))
		_part(hip, _caps(0.1, 0.44), Vector3(0, -0.2, 0), pants)
		var knee := _pivot(hip, Vector3(0, -0.4, 0))
		_part(knee, _caps(0.085, 0.42), Vector3(0, -0.2, 0), pants)
		_part(knee, _box(0.13, 0.07, 0.28), Vector3(0, -0.4, -0.06), shoe)
		if side == 0:
			leg_l = hip
			knee_l = knee
		else:
			leg_r = hip
			knee_r = knee
		var sh := -0.33 if side == 0 else 0.33
		var arm := _pivot(self, Vector3(sh, 1.45, 0))
		_part(arm, _caps(0.07, 0.64), Vector3(0, -0.3, 0), shirt)
		_part(arm, _sph(0.07), Vector3(0, -0.64, 0), skin)
		if side == 0:
			arm_l = arm
		else:
			arm_r = arm
	if robe:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.31
		cyl.height = 0.75
		cyl.radial_segments = 10
		cyl.rings = 1
		_part(self, cyl, Vector3(0, 0.6, 0), shirt)

func set_weapon(kind: String) -> void:
	if held != null:
		held.queue_free()
		held = null
	armed = kind != ""
	if not armed or arm_r == null:
		return
	held = Node3D.new()
	arm_r.add_child(held)
	var length := 0.3
	match kind:
		"smg": length = 0.5
		"shotgun": length = 0.85
		"rifle": length = 0.9
	_part(held, _box(0.06, 0.1, length), Vector3(0, -0.66, -length * 0.4), Color(0.1, 0.1, 0.11))

func pose_seated() -> void:
	seated = true
	leg_l.rotation.x = 1.5
	leg_r.rotation.x = 1.5
	knee_l.rotation.x = -1.5
	knee_r.rotation.x = -1.5
	arm_l.rotation.x = 1.0
	arm_r.rotation.x = 1.0

func animate(speed: float, delta: float) -> void:
	if seated:
		return
	_t += delta * (4.0 + speed * 1.6)
	var amp := clampf(speed / 3.0, 0.0, 1.0) * 0.7
	var s := sin(_t) * amp
	var c := cos(_t) * amp
	leg_l.rotation.x = s
	leg_r.rotation.x = -s
	knee_l.rotation.x = -maxf(0.0, c) * 1.3
	knee_r.rotation.x = -maxf(0.0, -c) * 1.3
	arm_l.rotation.x = -s * 0.8
	arm_r.rotation.x = 1.2 if armed else s * 0.8
