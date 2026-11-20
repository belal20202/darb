class_name MissionManager
extends Node
## Two-stage missions: go to giver (dialogue) -> go to destination (dialogue + reward).

var world: Node3D
var marker: Node3D
var m: Dictionary = {}
var stage: int = 0
var wait: bool = false
var _t: float = 0.0
var _warn_t: float = 0.0

func begin() -> void:
	if marker == null:
		marker = world.make_marker(Color(0.2, 0.9, 0.4))
	m = Game.make_mission(Game.mission_index)
	stage = 0
	wait = false
	_refresh()

func target_idx() -> int:
	return int(m["from"]) if stage == 0 else int(m["to"])

func target_pos() -> Vector3:
	return Nav.grid_to_pos(Game.landmarks[target_idx()]["grid"])

func _refresh() -> void:
	marker.global_position = target_pos()
	marker.visible = true

func _process(delta: float) -> void:
	if m.is_empty() or wait or Game.busy or world.in_shop >= 0:
		return
	var p: Node3D = world.player
	if world.player.ride_car != null:
		return
	_t += delta
	_warn_t -= delta
	var t := target_pos()
	var d := Vector2(p.global_position.x - t.x, p.global_position.z - t.z).length()
	if _t > 0.4:
		_t = 0.0
		var action := "اذهب إلى" if stage == 0 else "وصّل إلى"
		world.hud.set_mission("%s\n%s %s (%d م)" % [m["title"], action, Game.landmarks[target_idx()]["name"], int(d)])
	if d < 7.0:
		if stage == 1 and m["vehicle"] and not world.player.in_vehicle():
			if _warn_t <= 0.0:
				world.hud.toast("هذا المشوار يحتاج سيارة أو دراجة")
				_warn_t = 6.0
			return
		_arrive()

func _arrive() -> void:
	wait = true
	if stage == 0:
		world.hud.say(m["intro"], func():
			stage = 1
			wait = false
			_refresh())
	else:
		world.hud.say(m["outro"], func():
			Game.money += int(m["reward"])
			world.hud.set_money()
			Game.play_ui("coin")
			world.hud.toast("حصلت على " + Game.fmt(int(m["reward"])))
			Game.mission_index += 1
			Game.save_game()
			begin())
