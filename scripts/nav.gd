class_name Nav
extends RefCounted
## Grid-road helpers shared by city, traffic, taxis and minimap.

const B := 70.0   # distance between road centre lines
const R := 9.0    # road half width
const N := 7      # grid goes from -N..N on both axes

static func grid_to_pos(g: Vector2i) -> Vector3:
	return Vector3(g.x * B, 0.0, g.y * B)

static func nearest_grid(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(p.x / B), -N, N), clampi(roundi(p.z / B), -N, N))

static func yaw_for_dir(d: Vector3) -> float:
	return atan2(-d.x, -d.z)

static func segment_points(a: Vector2i, b: Vector2i) -> Array:
	var pa := grid_to_pos(a)
	var pb := grid_to_pos(b)
	var d := (pb - pa).normalized()
	var right := Vector3(-d.z, 0.0, d.x)
	var lift := Vector3(0, 0.6, 0)
	return [pa + d * 15.0 + right * 3.5 + lift, pb - d * 15.0 + right * 3.5 + lift]

static func route_between(a: Vector2i, b: Vector2i) -> Array:
	var pts: Array = []
	var cur := a
	while cur.x != b.x:
		var nxt := Vector2i(cur.x + signi(b.x - cur.x), cur.y)
		pts.append_array(segment_points(cur, nxt))
		cur = nxt
	while cur.y != b.y:
		var nxt2 := Vector2i(cur.x, cur.y + signi(b.y - cur.y))
		pts.append_array(segment_points(cur, nxt2))
		cur = nxt2
	return pts

static func random_route(start: Vector2i, steps: int, rng: RandomNumberGenerator) -> Array:
	var pts: Array = []
	var cur := start
	var prev := Vector2i(999, 999)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in steps:
		var opts: Array = []
		for d in dirs:
			var n: Vector2i = cur + d
			if absi(n.x) <= N and absi(n.y) <= N and n != prev:
				opts.append(n)
		if opts.is_empty():
			break
		var nxt: Vector2i = opts[rng.randi() % opts.size()]
		pts.append_array(segment_points(cur, nxt))
		prev = cur
		cur = nxt
	return pts
