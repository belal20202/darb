class_name PlayerCharacter
extends Node3D
## Animated player body. The .glb animations are not used (their Idle has a raised foot and
## Walk/Run/Sprint are the same loop re-timed), so the skeleton is posed procedurally here.
## Gait stride is derived from the real ground speed, so feet do not slide.

const SCENE_PATH := "res://assets/character_godot4_animations_fixed.glb"
const LEG := 0.85
const SIT_DROP := 0.42
const SIT_HIPS := 0.54   # hips height above the soles when seated (metres)

var ok: bool = false
var skel: Skeleton3D = null
var sitting: bool = false
var _n: int = 0
var _par: Array = []
var _rest_g: Array = []
var _rest_p: Array = []
var _names: Array = []
var _order: Array = []
var _hips: int = -1
var _k: float = 1.75
var _phase: float = 0.0
var _spd: float = 0.0
var _air: float = 0.0
var _land: float = 0.0
var _was_air: bool = false
var _t: float = 0.0

func _ready() -> void:
	if not ResourceLoader.exists(SCENE_PATH):
		return
	var res = load(SCENE_PATH)
	if not (res is PackedScene):
		return
	var inst: Node3D = (res as PackedScene).instantiate()
	inst.rotation.y = PI
	add_child(inst)
	var ap := _find(inst, "AnimationPlayer")
	if ap != null:
		ap.queue_free()
	skel = _find(inst, "Skeleton3D") as Skeleton3D
	if skel == null:
		return
	for nm in ["Hips", "Spine", "Head", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"]:
		if skel.find_bone(nm) < 0:
			return
	_n = skel.get_bone_count()
	_hips = skel.find_bone("Hips")
	_par.resize(_n)
	_rest_g.resize(_n)
	_rest_p.resize(_n)
	_names.resize(_n)
	var depth: Array = []
	for i in _n:
		_names[i] = skel.get_bone_name(i)
		_par[i] = skel.get_bone_parent(i)
		_rest_g[i] = skel.get_bone_global_rest(i).basis.orthonormalized()
		_rest_p[i] = skel.get_bone_rest(i).origin
		var d := 0
		var p: int = _par[i]
		while p >= 0:
			d += 1
			p = _par[p]
		depth.append([d, i])
	depth.sort_custom(func(a, b): return a[0] < b[0])
	for e in depth:
		_order.append(e[1])
	var sc := skel.global_transform.basis.get_scale().y
	var me := global_transform.basis.get_scale().y
	if me > 0.0001 and sc > 0.0001:
		_k = sc / me
	ok = true
	_pose(_gait_params(0.0, 0.0))

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null

# p: aL aR (thigh forward, rad) kL kR (knee flex) armL armR (arm forward) elbow lean twist dy (metres) adduct
func _pose(p: Dictionary) -> void:
	var rx := Vector3.RIGHT
	var inc := {}
	inc["LeftUpperLeg"] = Basis(rx, -float(p["aL"]))
	inc["RightUpperLeg"] = Basis(rx, -float(p["aR"]))
	inc["LeftLowerLeg"] = Basis(rx, float(p["kL"]))
	inc["RightLowerLeg"] = Basis(rx, float(p["kR"]))
	inc["Spine"] = Basis(Vector3.UP, float(p["twist"])) * Basis(rx, float(p["lean"]))
	inc["Head"] = Basis(rx, -float(p["lean"]) * 0.7)
	var add := float(p["adduct"])
	inc["LeftUpperArm"] = Basis(rx, -float(p["armL"])) * Basis(Vector3.BACK, -add)
	inc["RightUpperArm"] = Basis(rx, -float(p["armR"])) * Basis(Vector3.BACK, add)
	inc["LeftLowerArm"] = Basis(rx, -float(p["elbow"]))
	inc["RightLowerArm"] = Basis(rx, -float(p["elbow"]))
	var dtot: Array = []
	dtot.resize(_n)
	var ng: Array = []
	ng.resize(_n)
	for i in _order:
		var nm: String = _names[i]
		var par: int = _par[i]
		var d: Basis
		if nm == "LeftFoot" or nm == "RightFoot" or nm == "LeftToes" or nm == "RightToes":
			d = Basis.IDENTITY
		else:
			var pd: Basis = Basis.IDENTITY if par < 0 else dtot[par]
			var ii: Basis = inc.get(nm, Basis.IDENTITY)
			d = ii * pd
		dtot[i] = d
		var g: Basis = d * (_rest_g[i] as Basis)
		ng[i] = g
		var local: Basis = g
		if par >= 0:
			local = (ng[par] as Basis).inverse() * g
		skel.set_bone_pose_rotation(i, local.orthonormalized().get_rotation_quaternion())
	skel.set_bone_pose_position(_hips, (_rest_p[_hips] as Vector3) + Vector3(0, float(p["dy"]) / _k, 0))

func _gait_params(spd: float, delta: float) -> Dictionary:
	var th := 0.30 + 0.08 * minf(spd, 2.5)
	if spd > 2.5:
		th = 0.50 + 0.07 * minf(spd - 2.5, 5.0)
	_phase += spd / maxf(th * LEG, 0.05) * delta
	var gw := clampf(spd / 0.5, 0.0, 1.0)
	var s := sin(_phase)
	var c := cos(_phase)
	var kmax := minf(0.5 + 0.12 * spd, 1.6)
	var arm_a := minf(0.22 + 0.07 * spd, 0.8)
	var a_l := th * s
	var stance := a_l if c < 0.0 else -a_l
	return {
		"aL": a_l * gw, "aR": -a_l * gw,
		"kL": 0.05 + kmax * pow(maxf(0.0, c), 1.5) * gw,
		"kR": 0.05 + kmax * pow(maxf(0.0, -c), 1.5) * gw,
		"armL": -arm_a * s * gw, "armR": arm_a * s * gw,
		"elbow": minf(0.25 + 0.09 * spd, 1.2) * gw + 0.1,
		"lean": minf(0.03 + 0.025 * spd, 0.32) * gw + 0.012 * sin(_t * 2.0),
		"twist": 0.1 * s * gw,
		"dy": LEG * (cos(stance) - 1.0) * gw,
		"adduct": 0.6,
	}

func play(n: String, _blend: float = 0.0, _speed: float = 1.0) -> void:
	if not ok:
		return
	if n == "Sit":
		sitting = true
		_pose({"aL": 1.5, "aR": 1.5, "kL": 1.5, "kR": 1.5, "armL": 0.9, "armR": 0.9, "elbow": 1.1,
			"lean": -0.05, "twist": 0.0, "dy": -SIT_DROP, "adduct": 0.35})
	else:
		sitting = false

func update_motion(hspeed: float, on_floor: bool, delta: float) -> void:
	if not ok or sitting:
		return
	_t += delta
	_spd = lerpf(_spd, hspeed, clampf(12.0 * delta, 0.0, 1.0))
	if not on_floor:
		_was_air = true
		_air = move_toward(_air, 1.0, delta * 10.0)
	else:
		if _was_air:
			_was_air = false
			_land = 0.22
		_air = move_toward(_air, 0.0, delta * 8.0)
	_land = maxf(0.0, _land - delta)
	var p := _gait_params(_spd, delta)
	if _air > 0.0:
		var a := _air
		p["aL"] = lerpf(p["aL"], 0.9, a)
		p["aR"] = lerpf(p["aR"], 0.35, a)
		p["kL"] = lerpf(p["kL"], 1.3, a)
		p["kR"] = lerpf(p["kR"], 0.7, a)
		p["armL"] = lerpf(p["armL"], 2.0, a)
		p["armR"] = lerpf(p["armR"], 2.0, a)
		p["dy"] = lerpf(p["dy"], 0.0, a)
		p["lean"] = lerpf(p["lean"], 0.1, a)
	if _land > 0.0:
		var c := _land / 0.22
		p["aL"] = lerpf(p["aL"], 0.55, c)
		p["aR"] = lerpf(p["aR"], 0.55, c)
		p["kL"] = lerpf(p["kL"], 1.1, c)
		p["kR"] = lerpf(p["kR"], 1.1, c)
		p["dy"] = lerpf(p["dy"], -0.18, c)
		p["lean"] = float(p["lean"]) + 0.25 * c
	_pose(p)
