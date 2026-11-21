class_name Compass
extends Control
## Arrow pointing to the current mission / taxi target, with distance.

var world: Node3D

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world == null or world.player == null or world.in_shop >= 0:
		return
	var t = world.current_target()
	if t == null:
		return
	var p: Vector3 = world.player.global_position
	var to := Vector3(t.x - p.x, 0.0, t.z - p.z)
	var dist := to.length()
	var f := Basis(Vector3.UP, world.player.yaw) * Vector3(0, 0, -1)
	var ang := f.signed_angle_to(to.normalized(), Vector3.UP)
	var c := Vector2(size.x * 0.5, 34.0)
	var pts := PackedVector2Array([Vector2(0, -24), Vector2(-17, 16), Vector2(0, 8), Vector2(17, 16)])
	for k in pts.size():
		pts[k] = c + pts[k].rotated(-ang)
	draw_colored_polygon(pts, Color(0.2, 0.95, 0.45, 0.95))
	draw_string(Game.font, Vector2(0, 94), "%d م" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1))
