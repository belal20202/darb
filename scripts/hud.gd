class_name HUD
extends CanvasLayer
## All in-game UI: joystick, buttons, dialogue, shop, phone, minimap, toasts.

var world: Node3D
var root: Control
var money_l: Label
var time_l: Label
var mission_l: Label
var act_btn: Button
var brake_btn: Button
var jump_btn: Button
var horn_btn: Button
var weather_l: Label
var joystick: Joystick
var compass: Compass
var sprint_btn: Button
var cam_btn: Button
var toast_l: Label
var dlg_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
var modal: PanelContainer
var modal_box: VBoxContainer
var _lines: Array = []
var _li: int = 0
var _on_done: Callable = Callable()
var _toast_t: float = 0.0

static func style(c: Color, r: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _btn(text: String, minsize: Vector2, color: Color = Color(0.15, 0.2, 0.3, 0.85)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsize
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", style(color.lightened(0.3)))
	b.add_theme_font_size_override("font_size", 22)
	return b

func _label(text: String, size: int = 22, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	Game.hud = self
	# compass arrow (top centre, under the weather line)
	compass = Compass.new()
	compass.world = world
	compass.custom_minimum_size = Vector2(130, 100)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(compass)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 92)
	# money + time (top centre)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", style(Color(0, 0, 0, 0.5)))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	top.add_child(hb)
	money_l = _label("", 24, Color(0.6, 1, 0.6))
	time_l = _label("", 24, Color(1, 0.9, 0.5))
	hb.add_child(money_l)
	hb.add_child(time_l)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	# mission text (top-right, left of phone button)
	mission_l = _label("", 20, Color(1, 1, 1))
	mission_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_l.custom_minimum_size = Vector2(380, 0)
	mission_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(mission_l)
	mission_l.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	mission_l.offset_top = 150
	mission_l.offset_left = -400
	var phone := _btn("الهاتف", Vector2(130, 64))
	root.add_child(phone)
	phone.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	phone.pressed.connect(open_phone)
	cam_btn = _btn("الكاميرا", Vector2(130, 56))
	root.add_child(cam_btn)
	cam_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	cam_btn.offset_top = 84
	cam_btn.offset_bottom = 140
	cam_btn.pressed.connect(func(): world.player.cycle_camera())
	# joystick
	joystick = Joystick.new()
	joystick.custom_minimum_size = Vector2(320, 320)
	root.add_child(joystick)
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	# action + brake buttons
	act_btn = _btn("", Vector2(230, 100), Color(0.1, 0.45, 0.25, 0.9))
	act_btn.add_theme_font_size_override("font_size", 26)
	root.add_child(act_btn)
	act_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	act_btn.visible = false
	act_btn.pressed.connect(func(): world.do_interact())
	brake_btn = _btn("فرامل", Vector2(160, 100), Color(0.6, 0.15, 0.15, 0.9))
	root.add_child(brake_btn)
	brake_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	brake_btn.offset_top -= 120
	brake_btn.offset_bottom -= 120
	brake_btn.visible = false
	brake_btn.button_down.connect(func(): Input.action_press("brake"))
	brake_btn.button_up.connect(func(): Input.action_release("brake"))
	jump_btn = _btn("قفز", Vector2(160, 100), Color(0.15, 0.3, 0.55, 0.9))
	root.add_child(jump_btn)
	jump_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	jump_btn.offset_top -= 120
	jump_btn.offset_bottom -= 120
	jump_btn.button_down.connect(func(): Input.action_press("jump"))
	jump_btn.button_up.connect(func(): Input.action_release("jump"))
	sprint_btn = _btn("ركض", Vector2(160, 100), Color(0.55, 0.3, 0.1, 0.9))
	root.add_child(sprint_btn)
	sprint_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	sprint_btn.offset_top -= 120
	sprint_btn.offset_bottom -= 120
	sprint_btn.offset_left -= 180
	sprint_btn.offset_right -= 180
	sprint_btn.button_down.connect(func(): Input.action_press("sprint"))
	sprint_btn.button_up.connect(func(): Input.action_release("sprint"))
	horn_btn = _btn("هورن", Vector2(160, 100), Color(0.5, 0.4, 0.1, 0.9))
	root.add_child(horn_btn)
	horn_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 26)
	horn_btn.offset_top -= 120
	horn_btn.offset_bottom -= 120
	horn_btn.offset_left -= 180
	horn_btn.offset_right -= 180
	horn_btn.visible = false
	horn_btn.button_down.connect(func(): Input.action_press("horn"))
	horn_btn.button_up.connect(func(): Input.action_release("horn"))
	weather_l = _label("", 20, Color(0.85, 0.95, 1.0))
	weather_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(weather_l)
	weather_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	weather_l.custom_minimum_size = Vector2(400, 0)
	weather_l.offset_left = -200
	weather_l.offset_right = 200
	weather_l.offset_top = 62
	# toast
	toast_l = _label("", 26, Color(1, 1, 0.7))
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_l)
	toast_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 100)
	toast_l.custom_minimum_size = Vector2(700, 0)
	toast_l.offset_left = -350
	toast_l.offset_right = 350
	# dialogue
	dlg_panel = PanelContainer.new()
	dlg_panel.add_theme_stylebox_override("panel", style(Color(0.05, 0.06, 0.1, 0.94), 18))
	dlg_panel.custom_minimum_size = Vector2(900, 190)
	root.add_child(dlg_panel)
	dlg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	dlg_panel.visible = false
	var dv := VBoxContainer.new()
	dlg_panel.add_child(dv)
	dlg_name = _label("", 26, Color(1, 0.8, 0.3))
	dv.add_child(dlg_name)
	dlg_text = _label("", 24)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(860, 80)
	dv.add_child(dlg_text)
	var nxt := _btn("التالي", Vector2(160, 52), Color(0.2, 0.35, 0.6, 0.95))
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_END
	nxt.pressed.connect(_next_line)
	dv.add_child(nxt)
	# modal
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", style(Color(0.06, 0.07, 0.1, 0.96), 18))
	modal.custom_minimum_size = Vector2(760, 520)
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	modal.visible = false
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 8)
	modal.add_child(modal_box)
	_grow(top, 2, 1)
	_grow(mission_l, 0, 1)
	_grow(phone, 0, 1)
	_grow(act_btn, 0, 0)
	_grow(brake_btn, 0, 0)
	_grow(jump_btn, 0, 0)
	_grow(horn_btn, 0, 0)
	_grow(toast_l, 2, 1)
	_grow(weather_l, 2, 1)
	_grow(dlg_panel, 2, 0)
	_grow(modal, 2, 2)
	_grow(joystick, 1, 0)
	_grow(sprint_btn, 0, 0)
	_grow(cam_btn, 0, 1)
	_grow(compass, 2, 1)
	set_money()

func _grow(c: Control, h: int, v: int) -> void:
	c.grow_horizontal = h as Control.GrowDirection
	c.grow_vertical = v as Control.GrowDirection

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_l.text = ""

func set_money() -> void:
	money_l.text = Game.fmt(Game.money)

func set_time(h: float) -> void:
	var hh := int(h) % 24
	var mm := int((h - floorf(h)) * 60.0)
	time_l.text = "%02d:%02d" % [hh, mm]

func set_weather(t: String) -> void:
	weather_l.text = t

func set_mission(t: String) -> void:
	mission_l.text = t

func set_prompt(t: String) -> void:
	act_btn.visible = t != "" and not Game.busy
	act_btn.text = t

func show_driving(on: bool) -> void:
	brake_btn.visible = on
	jump_btn.visible = not on
	horn_btn.visible = on
	sprint_btn.visible = not on

func toast(t: String) -> void:
	toast_l.text = t
	_toast_t = 3.5

# ------------------------------------------------------------- dialogue
func say(lines: Array, done: Callable = Callable()) -> void:
	_lines = lines
	_li = 0
	_on_done = done
	Game.busy = true
	dlg_panel.visible = true
	act_btn.visible = false
	_show_line()

func _show_line() -> void:
	var l: Array = _lines[_li]
	dlg_name.text = l[0]
	dlg_text.text = l[1]

func _next_line() -> void:
	_li += 1
	if _li >= _lines.size():
		dlg_panel.visible = false
		Game.busy = false
		if _on_done.is_valid():
			_on_done.call()
	else:
		_show_line()

# ------------------------------------------------------------- modal helpers
func _open_modal(title: String) -> void:
	for c in modal_box.get_children():
		c.queue_free()
	modal.visible = true
	Game.busy = true
	var t := _label(title, 30, Color(1, 0.85, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(t)

func close_modal() -> void:
	modal.visible = false
	Game.busy = false

func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 340)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_box.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

func _close_btn() -> void:
	var c := _btn("إغلاق", Vector2(200, 56), Color(0.5, 0.15, 0.15, 0.95))
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.pressed.connect(close_modal)
	modal_box.add_child(c)

# ------------------------------------------------------------- shop
func open_shop(title: String, cats: Array) -> void:
	_open_modal(title)
	var info := _label("", 20, Color(0.6, 1, 0.6))
	modal_box.add_child(info)
	var list := _scroll()
	_fill_shop(list, cats, info)
	_close_btn()

func _fill_shop(list: VBoxContainer, cats: Array, info: Label) -> void:
	for c in list.get_children():
		c.queue_free()
	info.text = "رصيدك: " + Game.fmt(Game.money)
	for it in Game.items_of(cats):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := _label(it["name"], 22)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(_label(Game.fmt(int(it["price"])), 20, Color(0.9, 0.9, 0.5)))
		var id: String = it["id"]
		var cat: String = it["cat"]
		var owned := Game.is_owned(id)
		var txt := "شراء"
		if owned:
			if cat == "weapon" or cat == "cloth":
				var on := Game.weapon_equipped == id or Game.outfit.values().has(id)
				txt = "إزالة" if on else "استخدام"
			else:
				txt = "تملكه"
		var b := _btn(txt, Vector2(140, 52), Color(0.15, 0.4, 0.25, 0.95) if not owned else Color(0.25, 0.3, 0.4, 0.95))
		b.disabled = owned and (cat == "car" or cat == "bike")
		b.pressed.connect(func():
			if owned:
				Game.equip(id)
			else:
				var err := Game.buy(id)
				if err != "":
					toast(err)
					return
				if cat == "weapon" or cat == "cloth":
					Game.equip(id)
				Game.play_ui("coin")
				toast("تم الشراء: " + it["name"])
			set_money()
			world.on_inventory_changed(id)
			_fill_shop(list, cats, info))
		row.add_child(b)
		list.add_child(row)

# ------------------------------------------------------------- phone
func open_phone() -> void:
	if Game.busy:
		return
	_open_modal("الهاتف")
	var m: Dictionary = world.missions.m
	var txt := "لا توجد مهمة"
	if not m.is_empty():
		txt = "المهمة: %s\nمن: %s\nالمكافأة: %s" % [m["title"], m["giver"], Game.fmt(int(m["reward"]))]
	var l := _label(txt, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(l)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	modal_box.add_child(col)
	var b1 := _btn("اطلب تكسي", Vector2(500, 60))
	b1.pressed.connect(func():
		close_modal()
		world.taxi.hail())
	col.add_child(b1)
	var b2 := _btn("ابدأ / أوقف شغل التكسي (تحتاج تكسي ملكك)", Vector2(500, 60))
	b2.pressed.connect(func():
		close_modal()
		world.taxi.toggle_job())
	col.add_child(b2)
	var b3 := _btn("حفظ اللعبة", Vector2(500, 60))
	b3.pressed.connect(func():
		Game.save_game()
		toast("تم الحفظ"))
	col.add_child(b3)
	var b4 := _btn("القائمة الرئيسية", Vector2(500, 60), Color(0.4, 0.2, 0.2, 0.95))
	b4.pressed.connect(func():
		Game.save_game()
		Game.busy = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	col.add_child(b4)
	_close_btn()

func open_destinations(cb: Callable) -> void:
	_open_modal("وين تريد تروح؟")
	var list := _scroll()
	for i in Game.landmarks.size():
		var b := _btn(Game.landmarks[i]["name"], Vector2(660, 52))
		var idx := i
		b.pressed.connect(func():
			close_modal()
			cb.call(idx))
		list.add_child(b)
