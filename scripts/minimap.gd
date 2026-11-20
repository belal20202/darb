class_name Minimap
extends Control

var world: Node3D
const K := 0.9

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var sz := size
	var c := sz * 0.5
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.1, 0.13, 0.78))
	if world == null or world.player == null:
		return
	var p: Vector3 = world.player.global_position
	var rw := Nav.R * 2.0 * K
	for i in range(-Nav.N, Nav.N + 1):
		var sx := c.x + (i * Nav.B - p.x) * K
		var sy := c.y + (i * Nav.B - p.z) * K
		draw_line(Vector2(sx, 0), Vector2(sx, sz.y), Color(0.45, 0.45, 0.5), rw)
		draw_line(Vector2(0, sy), Vector2(sz.x, sy), Color(0.45, 0.45, 0.5), rw)
	for m in world.map_markers():
		var mp: Vector3 = m["pos"]
		var d := Vector2(mp.x - p.x, mp.z - p.z) * K
		var lim := sz * 0.5 - Vector2(8, 8)
		d = Vector2(clampf(d.x, -lim.x, lim.x), clampf(d.y, -lim.y, lim.y))
		draw_circle(c + d, 7.0, m["color"])
	var h: float = world.player.heading()
	var pts := PackedVector2Array([Vector2(0, -11), Vector2(-7, 8), Vector2(7, 8)])
	for k in pts.size():
		pts[k] = c + pts[k].rotated(-h)
	draw_colored_polygon(pts, Color(1, 1, 1))
