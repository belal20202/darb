class_name PlayerCharacter
extends Node3D
## Wraps the animated .glb character (Idle/Walk/Run/Sprint/Jump/Landing/Sit).
## The model faces +Z in the file, so it is turned by PI to face Godot's forward (-Z).

const SCENE_PATH := "res://assets/character_godot4_animations_fixed.glb"
const LOOPS := ["Idle", "Walk", "Walk_Relaxed", "Run", "Sprint", "Walk_Backward", "Strafe_Left", "Strafe_Right"]

var ok: bool = false
var ap: AnimationPlayer = null
var _names: Dictionary = {}
var _cur: String = ""
var _lock: float = 0.0
var _was_air: bool = false

func _ready() -> void:
	if not ResourceLoader.exists(SCENE_PATH):
		return
	var res = load(SCENE_PATH)
	if not (res is PackedScene):
		return
	var inst: Node3D = (res as PackedScene).instantiate()
	inst.rotation.y = PI
	add_child(inst)
	ap = _find_ap(inst)
	if ap == null:
		return
	for n in ap.get_animation_list():
		_names[String(n).to_lower()] = String(n)
	for l in LOOPS:
		var key := _res(l)
		if key != "":
			ap.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	ok = true
	play("Idle", 0.0)

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null

func _res(n: String) -> String:
	return _names.get(n.to_lower(), "")

func play(n: String, blend: float = 0.2, speed: float = 1.0) -> void:
	if ap == null:
		return
	var key := _res(n)
	if key == "":
		return
	if _cur != key:
		_cur = key
		ap.play(key, blend)
	ap.speed_scale = speed

func update_motion(hspeed: float, on_floor: bool, delta: float) -> void:
	if not ok:
		return
	if _lock > 0.0:
		_lock -= delta
		return
	if not on_floor:
		_was_air = true
		play("Jump", 0.1)
		return
	if _was_air:
		_was_air = false
		_lock = 0.24
		play("Landing", 0.05)
		return
	if hspeed < 0.3:
		play("Idle", 0.25, 1.0)
	elif hspeed < 4.8:
		play("Walk", 0.2, clampf(hspeed / 2.6, 0.6, 1.6))
	elif hspeed < 6.3:
		play("Run", 0.2, clampf(hspeed / 5.5, 0.8, 1.3))
	else:
		play("Sprint", 0.2, clampf(hspeed / 7.0, 0.8, 1.3))
