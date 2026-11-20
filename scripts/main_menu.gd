extends Control

var quality_btn: Button

func _ready() -> void:
	Game.load_game_if_first()
	Game.apply_quality()
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.08, 0.12, 0.25), Color(0.85, 0.45, 0.2), Color(0.95, 0.75, 0.4)])
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var skyline := Control.new()
	skyline.set_anchors_preset(Control.PRESET_FULL_RECT)
	skyline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skyline.draw.connect(func():
		var s := skyline.size
		var rr := RandomNumberGenerator.new()
		rr.seed = 5
		var x := 0.0
		while x < s.x:
			var w := rr.randf_range(50, 110)
			var h := rr.randf_range(60, 200)
			skyline.draw_rect(Rect2(x, s.y - h, w, h), Color(0.07, 0.08, 0.12, 0.95))
			x += w + 6.0
		skyline.draw_circle(Vector2(s.x * 0.12, s.y - 230), 30, Color(0.1, 0.5, 0.55))
		skyline.draw_rect(Rect2(s.x * 0.12 - 6, s.y - 380, 12, 150), Color(0.07, 0.08, 0.12)))
	add_child(skyline)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "درب الرافدين"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Darb Al-Rafidain  -  ابدأ مشوارك"
	sub.add_theme_font_size_override("font_size", 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	if Game.has_save():
		box.add_child(_button("متابعة اللعبة", func():
			Game.load_game()
			_play()))
	box.add_child(_button("لعبة جديدة", func():
		Game.reset_progress()
		_play()))
	quality_btn = _button("", func():
		Game.quality = (Game.quality + 1) % 3
		Game.apply_quality()
		_refresh_quality())
	box.add_child(quality_btn)
	_refresh_quality()
	box.add_child(_button("خروج", func(): get_tree().quit()))
	var badge := Label.new()
	badge.text = "صُنع في العراق  -  2026"
	badge.add_theme_font_size_override("font_size", 20)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(badge)

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(420, 70)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	return b

func _refresh_quality() -> void:
	var names := ["منخفضة", "متوسطة", "عالية"]
	quality_btn.text = "الجودة: " + names[Game.quality]

func _play() -> void:
	Game.next_scene = "res://scenes/world.tscn"
	get_tree().change_scene_to_file("res://scenes/loading.tscn")
