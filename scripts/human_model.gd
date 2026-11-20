class_name HumanModel
extends Node3D
## Procedural low-poly human. Replace with a rigged .glb later if you want.

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var held: Node3D = null
var armed: bool = false
var seated: bool = false
var _t: float = 0.0

static func _m(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _m(c)
	parent.add_child(mi)
	return mi

func build(shirt: Color, pants: Color, skin: Color, robe: bool = false, head_item: String = "") -> void:
	for c in get_children():
		c.queue_free()
	held = null
	var torso := CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.75
	_part(self, torso, Vector3(0, 1.15, 0), shirt)
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	_part(self, head, Vector3(0, 1.72, 0), skin)
	var hair := SphereMesh.new()
	hair.radius = 0.155
	hair.height = 0.16
	_part(self, hair, Vector3(0, 1.8, 0.02), Color(0.08, 0.06, 0.05))
	if head_item == "ghutra":
		var g := SphereMesh.new()
		g.radius = 0.19
		g.height = 0.3
		_part(self, g, Vector3(0, 1.77, 0.01), Color(0.96, 0.96, 0.96))
		var ig := TorusMesh.new()
		ig.inner_radius = 0.17
		ig.outer_radius = 0.2
		_part(self, ig, Vector3(0, 1.84, 0.01), Color(0.05, 0.05, 0.05))
	var legm := CapsuleMesh.new()
	legm.radius = 0.1
	legm.height = 0.8
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.11, 0.8, 0)
	add_child(leg_l)
	_part(leg_l, legm, Vector3(0, -0.4, 0), pants)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.11, 0.8, 0)
	add_child(leg_r)
	_part(leg_r, legm, Vector3(0, -0.4, 0), pants)
	var armm := CapsuleMesh.new()
	armm.radius = 0.07
	armm.height = 0.65
	var hand := SphereMesh.new()
	hand.radius = 0.07
	hand.height = 0.14
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.33, 1.45, 0)
	add_child(arm_l)
	_part(arm_l, armm, Vector3(0, -0.3, 0), shirt)
	_part(arm_l, hand, Vector3(0, -0.66, 0), skin)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.33, 1.45, 0)
	add_child(arm_r)
	_part(arm_r, armm, Vector3(0, -0.3, 0), shirt)
	_part(arm_r, hand, Vector3(0, -0.66, 0), skin)
	if robe:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.31
		cyl.height = 0.75
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
	var bm := BoxMesh.new()
	var length := 0.3
	match kind:
		"smg": length = 0.5
		"shotgun": length = 0.85
		"rifle": length = 0.9
	bm.size = Vector3(0.06, 0.1, length)
	_part(held, bm, Vector3(0, -0.66, -length * 0.4), Color(0.1, 0.1, 0.11))

func pose_seated() -> void:
	seated = true
	leg_l.rotation.x = 1.4
	leg_r.rotation.x = 1.4
	arm_l.rotation.x = 1.1
	arm_r.rotation.x = 1.1

func animate(speed: float, delta: float) -> void:
	if seated:
		return
	_t += delta * (4.0 + speed * 1.6)
	var amp := clampf(speed / 3.0, 0.0, 1.0) * 0.8
	var s := sin(_t) * amp
	leg_l.rotation.x = s
	leg_r.rotation.x = -s
	arm_l.rotation.x = -s * 0.8
	arm_r.rotation.x = 1.2 if armed else s * 0.8
