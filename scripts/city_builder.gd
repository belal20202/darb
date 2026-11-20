class_name CityBuilder
extends RefCounted
## Procedural Iraqi-style city: grid roads, houses, towers, mosques, parks, enterable shops.

const WALL_SHADER := """
shader_type spatial;
uniform vec4 wall_color : source_color = vec4(0.8, 0.7, 0.55, 1.0);
uniform float night = 0.0;
uniform float floor_h = 3.4;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 col = wall_color.rgb;
	float emis = 0.0;
	if (abs(wnrm.y) < 0.5) {
		float u = (wpos.x + wpos.z) / 3.0;
		float v = wpos.y / floor_h;
		vec2 cell = vec2(floor(u), floor(v));
		vec2 f = vec2(fract(u), fract(v));
		bool win = f.x > 0.25 && f.x < 0.75 && f.y > 0.3 && f.y < 0.75 && v > 1.0;
		if (win) {
			float lit = step(0.55, hash(cell));
			col = mix(vec3(0.12, 0.2, 0.3), vec3(1.0, 0.85, 0.5), lit * night);
			emis = lit * night;
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = vec3(1.0, 0.8, 0.4) * emis * 1.5;
}
"""

var root: Node3D
var rng := RandomNumberGenerator.new()
var shader: Shader
var wall_mats: Array = []
var cache: Dictionary = {}
var doors: Array = []        # {pos, shop}
var shops: Array = []        # {name, type, cats}
var blocks: Array = []       # {x0,x1,z0,z1}
var home_door: Vector3 = Vector3.ZERO
var parking: Array = []
var poles_body: StaticBody3D
var palm_pos: Array = []
var lamp_pos: Array = []
var font: Font
var ground_mat: StandardMaterial3D
var park_mat: StandardMaterial3D
var crown_mat: StandardMaterial3D
var shop_lights: Array = []

const GROUND := [Color(0.62, 0.64, 0.42), Color(0.78, 0.66, 0.45), Color(0.7, 0.58, 0.4), Color(0.55, 0.56, 0.46)]
const GRASS := [Color(0.3, 0.6, 0.25), Color(0.5, 0.55, 0.25), Color(0.55, 0.45, 0.2), Color(0.25, 0.42, 0.28)]
const CROWN := [Color(0.25, 0.6, 0.25), Color(0.2, 0.5, 0.22), Color(0.5, 0.5, 0.2), Color(0.18, 0.38, 0.24)]

const SPECIAL := {
	Vector2i(0, 0): "mall", Vector2i(-2, -1): "car", Vector2i(2, 1): "car", Vector2i(1, -2): "bike",
	Vector2i(-1, 1): "clothes", Vector2i(3, -1): "clothes", Vector2i(-3, -2): "clothes_small", Vector2i(2, -3): "weapons",
	Vector2i(-3, 2): "mosque", Vector2i(1, 2): "mosque", Vector2i(-1, -3): "park", Vector2i(3, 2): "park",
	Vector2i(-3, -3): "home",
}
const PALETTE := [Color(0.85, 0.75, 0.58), Color(0.9, 0.85, 0.72), Color(0.78, 0.55, 0.4), Color(0.7, 0.7, 0.68), Color(0.92, 0.88, 0.8), Color(0.8, 0.65, 0.5)]
const SIGNS := ["مطعم الشط", "صيدلية الشفاء", "مخبز السلام", "بقالة النور", "مكتبة بغداد", "مقهى الأصدقاء", "حلويات الزوراء", "مطعم دجلة"]

func _flat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key := "f" + c.to_html()
	if cache.has(key):
		return cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	cache[key] = m
	return m

func _wall(c: Color) -> ShaderMaterial:
	var key := "w" + c.to_html()
	if cache.has(key):
		return cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("wall_color", c)
	cache[key] = m
	wall_mats.append(m)
	return m

func set_night(v: float) -> void:
	for m in wall_mats:
		m.set_shader_parameter("night", v)
	for l in shop_lights:
		l.light_energy = v * 1.8
		l.visible = v > 0.05

func set_season(i: int) -> void:
	ground_mat.albedo_color = GROUND[i]
	park_mat.albedo_color = GRASS[i]
	crown_mat.albedo_color = CROWN[i]

func _solid(pos: Vector3, size: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = 280.0
	root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _label(text: String, pos: Vector3, px: float, color: Color = Color(1, 1, 1)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 96
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.shaded = false
	l.position = pos
	l.visibility_range_end = 120.0
	root.add_child(l)

func build(r: Node3D) -> void:
	root = r
	font = load("res://fonts/DejaVuSans.ttf")
	rng.seed = 20261119
	shader = Shader.new()
	shader.code = WALL_SHADER
	ground_mat = StandardMaterial3D.new()
	ground_mat.roughness = 0.95
	park_mat = StandardMaterial3D.new()
	park_mat.roughness = 0.95
	crown_mat = StandardMaterial3D.new()
	set_season(Game.season)
	poles_body = StaticBody3D.new()
	root.add_child(poles_body)
	_ground_and_roads()
	for i in range(-Nav.N, Nav.N):
		for j in range(-Nav.N, Nav.N):
			_build_block(i, j)
	_finish_trees_and_lights()
	_boundary()

func _ground_and_roads() -> void:
	var ext := Nav.N * Nav.B
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	g.mesh = pm
	g.material_override = ground_mat
	root.add_child(g)
	var gb := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1400, 2, 1400)
	gs.shape = bs
	gs.position = Vector3(0, -1, 0)
	gb.add_child(gs)
	root.add_child(gb)
	var asphalt := _flat(Color(0.16, 0.16, 0.18), 0.95)
	var length := ext * 2.0 + Nav.R * 2.0
	for k in range(-Nav.N, Nav.N + 1):
		_solid(Vector3(0, 0.02, k * Nav.B), Vector3(length, 0.04, Nav.R * 2.0), asphalt, false)
		_solid(Vector3(k * Nav.B, 0.021, 0), Vector3(Nav.R * 2.0, 0.04, length), asphalt, false)
	var dash := BoxMesh.new()
	dash.size = Vector3(2.4, 0.02, 0.22)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	var xs: Array = []
	var p := -ext
	while p <= ext:
		var m := fposmod(p, Nav.B)
		if m > Nav.R + 2.0 and m < Nav.B - Nav.R - 2.0:
			xs.append(p)
		p += 6.0
	mm.instance_count = xs.size() * (Nav.N * 2 + 1) * 2
	var n := 0
	for k in range(-Nav.N, Nav.N + 1):
		for x in xs:
			mm.set_instance_transform(n, Transform3D(Basis(), Vector3(x, 0.06, k * Nav.B)))
			n += 1
			mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(k * Nav.B, 0.06, x)))
			n += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _flat(Color(0.95, 0.9, 0.6))
	root.add_child(mi)

func _boundary() -> void:
	var e := Nav.N * Nav.B + Nav.R + 3.0
	for s in [Vector3(0, 10, e), Vector3(0, 10, -e)]:
		_solid(s, Vector3(e * 2 + 6, 20, 2), _flat(Color.WHITE), true).visible = false
	for s in [Vector3(e, 10, 0), Vector3(-e, 10, 0)]:
		_solid(s, Vector3(2, 20, e * 2 + 6), _flat(Color.WHITE), true).visible = false

func _build_block(i: int, j: int) -> void:
	var half := Nav.B * 0.5 - Nav.R
	var cx := (i + 0.5) * Nav.B
	var cz := (j + 0.5) * Nav.B
	blocks.append({"x0": cx - half, "x1": cx + half, "z0": cz - half, "z1": cz + half})
	var kind: String = SPECIAL.get(Vector2i(i, j), "")
	if kind == "":
		var central: bool = absi(i) <= 1 and absi(j) <= 1
		var roll := rng.randf()
		if central:
			kind = "tower"
		elif roll < 0.35:
			kind = "com"
		else:
			kind = "res"
	var base_c := Color(0.62, 0.6, 0.57)
	if kind == "park":
		base_c = Color(0.3, 0.5, 0.25)
	_solid(Vector3(cx, 0.075, cz), Vector3(half * 2, 0.15, half * 2), park_mat if kind == "park" else _flat(base_c), true)
	var face_z := cz + half - 3.0
	match kind:
		"mall": _shop(cx, cz, face_z, 46.0, 40.0, 14.0, "mall", "مول الرافدين", ["cloth"], Color(0.85, 0.88, 0.92))
		"car": _shop(cx, cz, face_z, 40.0, 24.0, 7.0, "car", "معرض النخيل للسيارات", ["car"], Color(0.9, 0.9, 0.88))
		"bike": _shop(cx, cz, face_z, 30.0, 18.0, 6.0, "bike", "دراجات الفرات", ["bike"], Color(0.85, 0.6, 0.35))
		"clothes": _shop(cx, cz, face_z, 36.0, 22.0, 8.0, "clothes", "أزياء دجلة", ["cloth"], Color(0.85, 0.7, 0.8))
		"clothes_small": _shop(cx, cz, face_z, 28.0, 18.0, 7.0, "clothes", "الأناقة الشرقية", ["cloth"], Color(0.7, 0.78, 0.9))
		"weapons": _shop(cx, cz, face_z, 28.0, 18.0, 7.0, "weapons", "محل الصقر للعدّة", ["weapon"], Color(0.55, 0.55, 0.5))
		"mosque": _mosque(cx, cz)
		"park": _park(cx, cz)
		"home": _home(cx, cz, face_z)
		"tower": _towers(cx, cz)
		"com": _commercial(cx, cz, face_z)
		_: _houses(cx, cz)
	# street lights at two corners
	lamp_pos.append(Vector3(cx - half + 1.0, 0, cz - half + 1.0))
	lamp_pos.append(Vector3(cx + half - 1.0, 0, cz + half - 1.0))
	if kind != "park":
		palm_pos.append(Vector3(cx + half - 1.5, 0, cz - half + 1.5))
		palm_pos.append(Vector3(cx - half + 1.5, 0, cz + half - 1.5))

func _shop(cx: float, cz: float, face_z: float, w: float, d: float, h: float, type: String, nm: String, cats: Array, c: Color) -> void:
	var bz := face_z - d * 0.5
	_solid(Vector3(cx, 0.15 + h * 0.5, bz), Vector3(w, h, d), _wall(c), true)
	_solid(Vector3(cx, 0.15 + h + 0.4, bz), Vector3(w + 0.6, 0.8, d + 0.6), _flat(Color(0.5, 0.48, 0.45)), false)
	# door + awning on the +Z face
	_solid(Vector3(cx, 0.15 + 1.5, face_z + 0.05), Vector3(2.6, 3.0, 0.15), _flat(Color(0.12, 0.1, 0.08)), false)
	_solid(Vector3(cx, 0.15 + 3.4, face_z + 0.9), Vector3(5.5, 0.25, 2.0), _flat(Color(0.7, 0.15, 0.1)), false)
	_solid(Vector3(cx - w * 0.3, 0.15 + 1.6, face_z + 0.05), Vector3(w * 0.25, 2.2, 0.12), _flat(Color(0.3, 0.45, 0.55), 0.1), false)
	_solid(Vector3(cx + w * 0.3, 0.15 + 1.6, face_z + 0.05), Vector3(w * 0.25, 2.2, 0.12), _flat(Color(0.3, 0.45, 0.55), 0.1), false)
	_label(nm, Vector3(cx, 0.15 + minf(h - 1.0, 5.8), face_z + 0.25), 0.012, Color(1, 0.9, 0.5))
	var ol := OmniLight3D.new()
	ol.position = Vector3(cx, 4.5, face_z + 3.0)
	ol.light_color = Color(1.0, 0.85, 0.6)
	ol.omni_range = 16.0
	ol.light_energy = 0.0
	ol.visible = false
	ol.distance_fade_enabled = true
	ol.distance_fade_begin = 70.0
	ol.distance_fade_length = 20.0
	root.add_child(ol)
	shop_lights.append(ol)
	var idx := shops.size()
	shops.append({"name": nm, "type": type, "cats": cats})
	doors.append({"pos": Vector3(cx, 0.15, face_z + 2.2), "shop": idx})

func _home(cx: float, cz: float, face_z: float) -> void:
	var bz := face_z - 8.0
	_solid(Vector3(cx, 0.15 + 4.0, bz), Vector3(20.0, 8.0, 16.0), _wall(Color(0.9, 0.82, 0.65)), true)
	_solid(Vector3(cx, 0.15 + 8.3, bz), Vector3(20.6, 0.6, 16.6), _flat(Color(0.55, 0.45, 0.35)), false)
	_solid(Vector3(cx, 0.15 + 1.4, face_z + 0.05), Vector3(2.0, 2.8, 0.15), _flat(Color(0.3, 0.18, 0.1)), false)
	_label("بيتك", Vector3(cx, 4.2, face_z + 0.2), 0.012, Color(0.6, 1, 0.7))
	home_door = Vector3(cx, 0.15, face_z + 1.8)
	for k in 8:
		parking.append(Vector3(cx - 24.0 + k * 6.5, 0.9, cz + 23.0 + 5.5))

func _houses(cx: float, cz: float) -> void:
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var h := 6.0 + float(rng.randi() % 3) * 3.4
			var c: Color = PALETTE[rng.randi() % PALETTE.size()]
			var px := cx + qx * 11.5
			var pz := cz + qz * 11.5
			_solid(Vector3(px, 0.15 + h * 0.5, pz), Vector3(15.0, h, 15.0), _wall(c), true)
			_solid(Vector3(px, 0.15 + h + 0.35, pz), Vector3(15.6, 0.7, 15.6), _flat(c.darkened(0.2)), false)
			_solid(Vector3(px + 3.0, 0.15 + h + 1.2, pz + 3.0), Vector3(2.0, 1.6, 2.0), _flat(Color(0.7, 0.7, 0.72)), false)

func _towers(cx: float, cz: float) -> void:
	for q in [-1.0, 1.0]:
		var h := 22.0 + float(rng.randi() % 5) * 7.0
		var c: Color = [Color(0.55, 0.62, 0.7), Color(0.7, 0.72, 0.75), Color(0.6, 0.5, 0.42)][rng.randi() % 3]
		var px := cx + q * 12.0
		_solid(Vector3(px, 0.15 + h * 0.5, cz), Vector3(18.0, h, 30.0), _wall(c), true)
		_solid(Vector3(px, 0.15 + h + 1.0, cz), Vector3(18.5, 2.0, 30.5), _flat(Color(0.35, 0.35, 0.38)), false)

func _commercial(cx: float, cz: float, face_z: float) -> void:
	var h := 9.0 + float(rng.randi() % 3) * 3.4
	var c: Color = PALETTE[rng.randi() % PALETTE.size()]
	_solid(Vector3(cx, 0.15 + h * 0.5, face_z - 14.0), Vector3(40.0, h, 28.0), _wall(c), true)
	_solid(Vector3(cx, 0.15 + h + 0.4, face_z - 14.0), Vector3(40.6, 0.8, 28.6), _flat(c.darkened(0.25)), false)
	_label(SIGNS[rng.randi() % SIGNS.size()], Vector3(cx, 4.4, face_z + 0.25), 0.011, Color(1, 1, 1))
	_solid(Vector3(cx, 0.15 + 1.4, face_z + 0.05), Vector3(2.4, 2.8, 0.15), _flat(Color(0.15, 0.12, 0.1)), false)

func _mosque(cx: float, cz: float) -> void:
	_solid(Vector3(cx, 0.15 + 6.0, cz), Vector3(26.0, 12.0, 26.0), _flat(Color(0.93, 0.9, 0.82)), true)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 18.0
	dome.mesh = sm
	dome.material_override = _flat(Color(0.1, 0.55, 0.6), 0.3)
	dome.position = Vector3(cx, 0.15 + 12.0, cz)
	dome.scale = Vector3(1.0, 0.85, 1.0)
	root.add_child(dome)
	for q in [Vector2(-1, -1), Vector2(1, 1)]:
		var mx := cx + q.x * 15.0
		var mz := cz + q.y * 15.0
		var cm := CylinderMesh.new()
		cm.top_radius = 1.1
		cm.bottom_radius = 1.5
		cm.height = 30.0
		var mn := MeshInstance3D.new()
		mn.mesh = cm
		mn.material_override = _flat(Color(0.93, 0.9, 0.82))
		mn.position = Vector3(mx, 15.15, mz)
		root.add_child(mn)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(2.6, 30.0, 2.6)
		cs.shape = bx
		sb.add_child(cs)
		mn.add_child(sb)
		var tip := MeshInstance3D.new()
		var ts := SphereMesh.new()
		ts.radius = 1.3
		ts.height = 2.6
		tip.mesh = ts
		tip.material_override = _flat(Color(0.9, 0.7, 0.2), 0.3)
		tip.position = Vector3(mx, 31.5, mz)
		root.add_child(tip)
	_label("جامع", Vector3(cx, 14.0, cz + 13.3), 0.015, Color(1, 1, 1))

func _park(cx: float, cz: float) -> void:
	for k in 10:
		palm_pos.append(Vector3(cx + rng.randf_range(-21, 21), 0, cz + rng.randf_range(-21, 21)))
	var fm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0
	cm.bottom_radius = 4.5
	cm.height = 0.9
	fm.mesh = cm
	fm.material_override = _flat(Color(0.5, 0.75, 0.85), 0.2)
	fm.position = Vector3(cx, 0.6, cz)
	root.add_child(fm)

func _finish_trees_and_lights() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 6.0
	var crown := SphereMesh.new()
	crown.radius = 2.4
	crown.height = 2.0
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.mesh = trunk
	mt.instance_count = palm_pos.size()
	var mc := MultiMesh.new()
	mc.transform_format = MultiMesh.TRANSFORM_3D
	mc.mesh = crown
	mc.instance_count = palm_pos.size()
	for k in palm_pos.size():
		var p: Vector3 = palm_pos[k]
		mt.set_instance_transform(k, Transform3D(Basis(), p + Vector3(0, 3.15, 0)))
		mc.set_instance_transform(k, Transform3D(Basis(), p + Vector3(0, 6.3, 0)))
		_pole_shape(p + Vector3(0, 3.0, 0), 0.3, 6.0)
	var a := MultiMeshInstance3D.new()
	a.multimesh = mt
	a.material_override = _flat(Color(0.4, 0.3, 0.2))
	root.add_child(a)
	var b := MultiMeshInstance3D.new()
	b.multimesh = mc
	b.material_override = crown_mat
	root.add_child(b)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.14
	pole.height = 7.0
	var lamp := SphereMesh.new()
	lamp.radius = 0.35
	lamp.height = 0.7
	var mp := MultiMesh.new()
	mp.transform_format = MultiMesh.TRANSFORM_3D
	mp.mesh = pole
	mp.instance_count = lamp_pos.size()
	var ml := MultiMesh.new()
	ml.transform_format = MultiMesh.TRANSFORM_3D
	ml.mesh = lamp
	ml.instance_count = lamp_pos.size()
	for k in lamp_pos.size():
		var p2: Vector3 = lamp_pos[k]
		mp.set_instance_transform(k, Transform3D(Basis(), p2 + Vector3(0, 3.65, 0)))
		ml.set_instance_transform(k, Transform3D(Basis(), p2 + Vector3(0, 7.2, 0)))
		_pole_shape(p2 + Vector3(0, 3.5, 0), 0.2, 7.0)
	var c := MultiMeshInstance3D.new()
	c.multimesh = mp
	c.material_override = _flat(Color(0.25, 0.25, 0.28))
	root.add_child(c)
	var d := MultiMeshInstance3D.new()
	d.multimesh = ml
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 0.95, 0.7)
	lm.emission_enabled = true
	lm.emission = Color(1, 0.9, 0.6)
	lm.emission_energy_multiplier = 1.5
	d.material_override = lm
	root.add_child(d)

func _pole_shape(pos: Vector3, radius: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius
	cy.height = h
	cs.shape = cy
	cs.position = pos
	poles_body.add_child(cs)
