extends Control

const TIPS := [
	"اسحب الجويستك لتتحرك، واسحب يمين الشاشة لتدور بالكاميرا.",
	"اضغط الزر الأخضر للدخول إلى المحلات وشراء الأسلحة والملابس والسيارات.",
	"ما تگدر تسرق السيارات: اشتغل، اجمع فلوس، واشتري سيارتك أو دراجتك.",
	"من الهاتف تگدر تطلب تكسي من الشارع أو تبدأ شغل التكسي بسيارتك.",
	"اتبع السهم الأخضر لتنجز المهام وتاخذ الأجرة.",
]
const SCRIPTS := ["nav", "human_model", "character", "sfx", "vehicle", "pedestrian", "player", "city_builder",
	"traffic_lights", "weather", "missions", "taxi_service", "joystick", "compass", "quality_manager", "hud", "world"]

var bar: ProgressBar
var box: VBoxContainer
var _t: float = 0.0
var _started: bool = false
var _failed: bool = false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	var t := Label.new()
	t.text = "درب الرافدين"
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var tip := Label.new()
	tip.text = TIPS[randi() % TIPS.size()]
	tip.add_theme_font_size_override("font_size", 26)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(800, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(700, 26)
	bar.max_value = 100
	box.add_child(bar)
	var bad := _broken_scripts()
	if not bad.is_empty():
		_fail("فشل تحميل هذه الملفات (فيها أخطاء برمجية):\n" + "\n".join(bad))
		return
	ResourceLoader.load_threaded_request(Game.next_scene)

func _broken_scripts() -> Array:
	var bad: Array = []
	for n in SCRIPTS:
		var sc = load("res://scripts/%s.gd" % n)
		if sc == null or not (sc is GDScript) or not sc.can_instantiate():
			bad.append(n + ".gd")
	return bad

func _fail(msg: String) -> void:
	_failed = true
	bar.visible = false
	var l := Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(800, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var b := Button.new()
	b.text = "رجوع"
	b.custom_minimum_size = Vector2(260, 64)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(b)

func _process(delta: float) -> void:
	if _failed:
		return
	_t += delta
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(Game.next_scene, prog)
	if st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail("فشل تحميل المشهد الرئيسي للعبة.")
		return
	var real: float = prog[0] * 100.0 if prog.size() > 0 else 0.0
	bar.value = minf(maxf(real, _t / 3.0 * 100.0), 100.0) if st != ResourceLoader.THREAD_LOAD_LOADED else minf(_t / 3.0 * 100.0, 100.0)
	if _t >= 3.0 and st == ResourceLoader.THREAD_LOAD_LOADED and not _started:
		_started = true
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(Game.next_scene))
