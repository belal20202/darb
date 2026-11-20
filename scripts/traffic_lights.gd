class_name TrafficLights
extends Node
## Traffic lights at every intersection. state(): 0 green, 1 yellow, 2 red.

const CYCLE := 36.0
var t: float = 0.0
var mats: Dictionary = {}
var _acc: float = 0.0

func state(along_z: bool) -> int:
	var p := fposmod(t, CYCLE)
	if along_z:
		if p < 15.0:
			return 0
		if p < 17.0:
			return 1
		return 2
	if p < 18.0:
		return 2
	if p < 33.0:
		return 0
	if p < 35.0:
		return 1
	return 2

func build(root: Node3D, poles_body: StaticBody3D) -> void:
	var pos: Array = []
	for gx in range(-Nav.N, Nav.N + 1):
		for gz in range(-Nav.N, Nav.N + 1):
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					pos.append(Vector3(gx * Nav.B + sx * (Nav.R + 2.5), 0.0, gz * Nav.B + sz * (Nav.R + 2.5)))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.1
	pole.height = 5.5
	var mp := MultiMesh.new()
	mp.transform_format = MultiMesh.TRANSFORM_3D
	mp.mesh = pole
	mp.instance_count = pos.size()
	for k in pos.size():
		var p: Vector3 = pos[k]
		mp.set_instance_transform(k, Transform3D(Basis(), p + Vector3(0, 2.75, 0)))
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.15
		cy.height = 5.5
		cs.shape = cy
		cs.position = p + Vector3(0, 2.75, 0)
		poles_body.add_child(cs)
	var mpi := MultiMeshInstance3D.new()
	mpi.multimesh = mp
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.2, 0.22)
	mpi.material_override = pm
	root.add_child(mpi)
	var lamp := SphereMesh.new()
	lamp.radius = 0.17
	lamp.height = 0.34
	var cols := {"r": Color(1, 0.1, 0.05), "y": Color(1, 0.75, 0.1), "g": Color(0.1, 1, 0.3)}
	var hts := {"r": 5.5, "y": 5.1, "g": 4.7}
	for axis in ["ns", "ew"]:
		var xo := -0.35 if axis == "ns" else 0.35
		for c in ["r", "y", "g"]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = lamp
			mm.instance_count = pos.size()
			for k in pos.size():
				var p2: Vector3 = pos[k]
				mm.set_instance_transform(k, Transform3D(Basis(), p2 + Vector3(xo, hts[c], 0)))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			var m := StandardMaterial3D.new()
			var base: Color = cols[c]
			m.albedo_color = base.darkened(0.7)
			m.emission_enabled = true
			m.emission = base
			m.emission_energy_multiplier = 0.0
			mi.material_override = m
			root.add_child(mi)
			mats[axis + "_" + c] = m

func _process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc < 0.2 or mats.is_empty():
		return
	_acc = 0.0
	var ns := state(true)
	var ew := state(false)
	mats["ns_r"].emission_energy_multiplier = 3.0 if ns == 2 else 0.0
	mats["ns_y"].emission_energy_multiplier = 3.0 if ns == 1 else 0.0
	mats["ns_g"].emission_energy_multiplier = 3.0 if ns == 0 else 0.0
	mats["ew_r"].emission_energy_multiplier = 3.0 if ew == 2 else 0.0
	mats["ew_y"].emission_energy_multiplier = 3.0 if ew == 1 else 0.0
	mats["ew_g"].emission_energy_multiplier = 3.0 if ew == 0 else 0.0
