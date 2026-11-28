extends Control
## Main menu: animated sunset skyline of the city with mosques and palms, driving cars, and styled buttons.

var quality_btn: Button
var _t: float = 0.0
var _layers: Array = []
var _stars: Array = []
const PERIOD := 2600.0

func _ready() -> void:
	Game.load_game_if_first()
	Game.apply_quality()
	var rr := RandomNumberGenerator.new()
	rr.seed = 11
	for i in 80:
		_stars.append(Vector3(rr.randf(), rr.randf() * 0.5, rr.randf_range(0.5, 1.6)))
	_layers = [
		_make_layer(rr, 12.0, 70.0, 150.0, Color(0.30, 0.20, 0.30), false),
		_make_layer(rr, 26.0, 100.0, 210.0, Color(0.17, 0.12, 0.20), false),
		_make_layer(rr, 52.0, 130.0, 280.0, Color(0.07, 0.06, 0.10), true),
	]
	_build_ui()

func _make_layer(rr: RandomNumberGenerator, spd: float, hmin: float, hmax: float, col: Color, lit: bool) -> Dictionary:
	var items: Array = []
	var x := 0.0
	while x < PERIOD:
		var roll := rr.randf()
		var kind := 0
		var w := rr.randf_range(50.0, 130.0)
		if roll > 0.9:
			kind = 1
			w = rr.randf_range(110.0, 150.0)
		elif roll > 0.72:
			kind = 2
			w = 36.0
		items.append([x, w, rr.randf_range(hmin, hmax), kind, rr.randi()])
		x += w + rr.randf_range(4.0, 26.0)
	return {"speed": spd, "items": items, "color": col, "lit": lit}

func _style(c: Color, border: Color, r: int = 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb

func _button(t: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(460, 76 if primary else 64)
	b.add_theme_font_size_override("font_size", 32 if primary else 26)
	var base := Color(0.96, 0.58, 0.16, 0.97) if primary else Color(0.10, 0.12, 0.2, 0.82)
	var border := Color(1, 0.85, 0.5) if primary else Color(0.55, 0.62, 0.8, 0.8)
	b.add_theme_stylebox_override("normal", _style(base, border))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.15), border))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), border))
	var fc := Color(0.1, 0.06, 0.02) if primary else Color(0.95, 0.95, 1.0)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.pressed.connect(cb)
	return b

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "درب الرافدين"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.02))
	title.add_theme_constant_override("outline_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Darb Al-Rafidain  -  ابدأ مشوارك في شوارع بغداد"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(1, 0.95, 0.88))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("outline_size", 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(btns)
	if Game.has_save():
		btns.add_child(_button("متابعة اللعبة", true, func():
			Game.load_game()
			_play()))
		btns.add_child(_button("لعبة جديدة", false, func():
			Game.reset_progress()
			_play()))
	else:
		btns.add_child(_button("ابدأ اللعبة", true, func():
			Game.reset_progress()
			_play()))
	quality_btn = _button("", false, func():
		Game.quality = (Game.quality + 1) % 4
		Game.apply_quality()
		_refresh_quality())
	btns.add_child(quality_btn)
	_refresh_quality()
	btns.add_child(_button("خروج", false, func(): get_tree().quit()))
	var badge := Label.new()
	badge.text = "صُنع في العراق  -  2026  -  الإصدار 1.0"
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(badge)
	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, 0.9)

func _refresh_quality() -> void:
	var names := ["منخفضة", "متوسطة", "عالية", "تلقائي (حسب جهازك)"]
	quality_btn.text = "الجودة: " + names[Game.quality]

func _play() -> void:
	Game.next_scene = "res://scenes/world.tscn"
	get_tree().change_scene_to_file("res://scenes/loading.tscn")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _sky_poly(s: Vector2, y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0), Vector2(s.x, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

func _draw() -> void:
	var s := size
	var ground := s.y * 0.80
	_sky_poly(s, 0.0, s.y * 0.45, Color(0.05, 0.07, 0.20), Color(0.34, 0.16, 0.34))
	_sky_poly(s, s.y * 0.45, ground, Color(0.34, 0.16, 0.34), Color(0.98, 0.58, 0.25))
	for st in _stars:
		var a := 0.35 + 0.35 * sin(_t * 1.5 * st.z + st.x * 20.0)
		draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(1, 1, 1, a))
	var sun := Vector2(s.x * 0.5, ground - 40.0)
	for k in 4:
		draw_circle(sun, 160.0 - k * 34.0, Color(1.0, 0.7, 0.3, 0.07 + k * 0.05))
	draw_circle(sun, 62.0, Color(1.0, 0.88, 0.5))
	for layer in _layers:
		_draw_layer(layer, s, ground)
	draw_rect(Rect2(0, ground, s.x, s.y - ground), Color(0.09, 0.08, 0.11))
	draw_rect(Rect2(0, ground + 8, s.x, 74), Color(0.16, 0.16, 0.19))
	var dash_off := fposmod(_t * 220.0, 90.0)
	var xx := -dash_off
	while xx < s.x:
		draw_rect(Rect2(xx, ground + 44, 46, 5), Color(0.95, 0.9, 0.6, 0.9))
		xx += 90.0
	for k in 3:
		var cx := fposmod(_t * (120.0 + k * 35.0) + k * 650.0, s.x + 500.0) - 250.0
		_draw_car(Vector2(cx, ground + 52.0 + (k % 2) * 16.0), k)

func _draw_layer(layer: Dictionary, s: Vector2, ground: float) -> void:
	var off := fposmod(_t * float(layer["speed"]), PERIOD)
	var col: Color = layer["color"]
	var lit: bool = layer["lit"]
	var tiles := int(s.x / PERIOD) + 2
	for tile in tiles:
		for it in layer["items"]:
			var x: float = float(it[0]) - off + tile * PERIOD
			var w: float = it[1]
			if x > s.x or x + w < 0.0:
				continue
			var h: float = it[2]
			var kind: int = it[3]
			var top := ground - h
			if kind == 0:
				draw_rect(Rect2(x, top, w, h), col)
				if lit:
					var rows := int(h / 26.0)
					for r in rows:
						for c in int(w / 20.0):
							if ((int(it[4]) >> (r * 3 + c)) & 1) == 1:
								draw_rect(Rect2(x + 6 + c * 20, top + 10 + r * 26, 9, 12), Color(1, 0.85, 0.45, 0.85))
			elif kind == 1:
				var bh := h * 0.5
				draw_rect(Rect2(x, ground - bh, w, bh), col)
				draw_circle(Vector2(x + w * 0.5, ground - bh), w * 0.34, col)
				draw_rect(Rect2(x + w * 0.5 - 2, ground - bh - w * 0.34 - 26, 4, 26), col)
				draw_rect(Rect2(x - 6, ground - h * 1.25, 12, h * 1.25), col)
				draw_circle(Vector2(x, ground - h * 1.25), 9.0, col)
				draw_rect(Rect2(x + w - 6, ground - h * 1.25, 12, h * 1.25), col)
				draw_circle(Vector2(x + w, ground - h * 1.25), 9.0, col)
			else:
				var px := x + w * 0.5
				draw_line(Vector2(px, ground), Vector2(px + 4, ground - h * 0.8), col, 6.0)
				for a in 5:
					var ang := -PI * 0.5 + (a - 2) * 0.55
					draw_line(Vector2(px + 4, ground - h * 0.8), Vector2(px + 4, ground - h * 0.8) + Vector2(cos(ang), sin(ang)) * 46.0, col, 5.0)

func _draw_car(pos: Vector2, k: int) -> void:
	var body := Color(0.97, 0.97, 0.97) if k == 0 else (Color(0.95, 0.55, 0.1) if k == 1 else Color(0.15, 0.4, 0.8))
	draw_rect(Rect2(pos.x - 56, pos.y - 26, 112, 22), body)
	draw_rect(Rect2(pos.x - 30, pos.y - 46, 62, 22), body.darkened(0.15))
	draw_rect(Rect2(pos.x - 24, pos.y - 42, 22, 15), Color(0.25, 0.35, 0.5))
	draw_rect(Rect2(pos.x + 2, pos.y - 42, 24, 15), Color(0.25, 0.35, 0.5))
	draw_circle(pos + Vector2(-34, -2), 12.0, Color(0.05, 0.05, 0.06))
	draw_circle(pos + Vector2(36, -2), 12.0, Color(0.05, 0.05, 0.06))
	draw_circle(pos + Vector2(60, -16), 9.0, Color(1, 0.95, 0.7, 0.35))
	draw_circle(pos + Vector2(56, -16), 4.0, Color(1, 0.95, 0.7))
