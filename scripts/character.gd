class_name PlayerCharacter
extends Node3D
## Animated player body. The .glb animations are not used (their Idle has a raised foot and
## Walk/Run/Sprint are the same loop re-timed). The skeleton is posed in code with 2-bone leg IK:
## the planted foot stays fixed on the ground (no skating) and the stride follows the real speed.

const SCENE_PATH := "res://assets/character_godot4_animations_fixed.glb"
const SIT_DROP := 0.366   # hips drop (metres) so flat feet touch the floor when seated
const SIT_HIPS := 0.591   # hips height above the soles when seated

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
var _prof_l: Dictionary = {}
var _prof_r: Dictionary = {}
var _ag: float = 0.119      # ankle height above the ground at rest
var _hj0: float = 0.903     # hip joint height at rest
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
	var origin_y := to_local(skel.global_position).y
	_prof_l = _leg_profile("Left", origin_y)
	_prof_r = _leg_profile("Right", origin_y)
	_ag = _prof_l["ank"]
	_hj0 = _prof_l["hj"]
	ok = true
	_pose(_gait_params(0.0, 0.0, 0.0))

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null

func _leg_profile(side: String, origin_y: float) -> Dictionary:
	var u := skel.find_bone(side + "UpperLeg")
	var l := skel.find_bone(side + "LowerLeg")
	var f := skel.find_bone(side + "Foot")
	var pu: Vector3 = skel.get_bone_global_rest(u).origin * _k
	var pl: Vector3 = skel.get_bone_global_rest(l).origin * _k
	var pf: Vector3 = skel.get_bone_global_rest(f).origin * _k
	var v1 := pl - pu
	var v2 := pf - pl
	return {
		"L1": Vector2(v1.y, v1.z).length(), "L2": Vector2(v2.y, v2.z).length(),
		"rt": atan2(v1.z, -v1.y), "rs": atan2(v2.z, -v2.y),
		"hj": origin_y + pu.y, "ank": origin_y + pf.y,
	}

# p: aL aR (thigh increment, rad) kL kR (knee increment) armL armR (arm forward) elbow lean twist dy (metres) adduct
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

## 2-bone IK in the leg plane. tz = ankle forward of the hip joint, ty = ankle height relative to it.
## Returns (thigh forward angle from vertical, knee flexion).
func _ik(pr: Dictionary, tz: float, ty: float) -> Vector2:
	var l1: float = pr["L1"]
	var l2: float = pr["L2"]
	var d := sqrt(tz * tz + ty * ty)
	d = clampf(d, absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var cg := clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0)
	var knee := PI - acos(cg)
	var cd := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var beta := atan2(tz, -ty)
	return Vector2(beta + acos(cd), knee)

func _leg_target(u: float, stride: float, duty: float, lift: float) -> Vector2:
	if u < duty:
		return Vector2(stride * 0.5 - stride * (u / duty), 0.0)
	var us := (u - duty) / (1.0 - duty)
	return Vector2(-stride * 0.5 + stride * (0.5 - 0.5 * cos(PI * us)), lift * sin(PI * us))

func _gait_params(spd: float, delta: float, crouch: float) -> Dictionary:
	var w := clampf(spd / 0.6, 0.0, 1.0)
	var steps := minf(1.5 + 0.28 * spd, 3.6)
	var period := 2.0 / steps
	var duty := 0.62
	if spd > 0.05:
		duty = clampf(1.0 / maxf(spd * period, 0.01), 0.25, 0.62)
	var stride := spd * duty * period
	var lift := minf(0.05 + 0.025 * spd, 0.2)
	_phase = fposmod(_phase + delta / period, 1.0)
	var tl := _leg_target(_phase, stride, duty, lift) * w
	var tr := _leg_target(fposmod(_phase + 0.5, 1.0), stride, duty, lift) * w
	var l_l: float = _prof_l["L1"] + _prof_l["L2"]
	var l_r: float = _prof_r["L1"] + _prof_r["L2"]
	var reach := 0.995
	var cap_l := _ag + tl.y + sqrt(maxf(pow(reach * l_l, 2.0) - tl.x * tl.x, 0.0))
	var cap_r := _ag + tr.y + sqrt(maxf(pow(reach * l_r, 2.0) - tr.x * tr.x, 0.0))
	var pref := _hj0 - (0.01 + 0.012 * spd) - crouch
	var hj := minf(pref, minf(cap_l, cap_r))
	var ikl := _ik(_prof_l, tl.x, _ag + tl.y - hj)
	var ikr := _ik(_prof_r, tr.x, _ag + tr.y - hj)
	var amp := minf(0.2 + 0.06 * spd, 0.7)
	var half := maxf(stride * 0.5, 0.2)
	return {
		"aL": ikl.x - float(_prof_l["rt"]), "aR": ikr.x - float(_prof_r["rt"]),
		"kL": ikl.y + float(_prof_l["rs"]) - float(_prof_l["rt"]),
		"kR": ikr.y + float(_prof_r["rs"]) - float(_prof_r["rt"]),
		"armL": -amp * tl.x / half * w, "armR": -amp * tr.x / half * w,
		"elbow": minf(0.25 + 0.09 * spd, 1.2) * w + 0.1,
		"lean": minf(0.02 + 0.03 * spd, 0.35) * w + 0.012 * sin(_t * 2.0),
		"twist": 0.08 * sin(_phase * TAU) * w,
		"dy": hj - _hj0,
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
	_spd = lerpf(_spd, hspeed, clampf(10.0 * delta, 0.0, 1.0))
	if not on_floor:
		_was_air = true
		_air = move_toward(_air, 1.0, delta * 10.0)
	else:
		if _was_air:
			_was_air = false
			_land = 0.22
		_air = move_toward(_air, 0.0, delta * 8.0)
	_land = maxf(0.0, _land - delta)
	var p := _gait_params(_spd, delta, 0.15 * (_land / 0.22))
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
	_pose(p)
