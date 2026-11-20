extends Control

const TIPS := [
	"اسحب الجويستك لتتحرك، واسحب يمين الشاشة لتدور بالكاميرا.",
	"اضغط الزر الأخضر للدخول إلى المحلات وشراء الأسلحة والملابس والسيارات.",
	"ما تگدر تسرق السيارات: اشتغل، اجمع فلوس، واشتري سيارتك أو دراجتك.",
	"من الهاتف تگدر تطلب تكسي من الشارع أو تبدأ شغل التكسي بسيارتك.",
	"اتبع العلامات الخضراء على الخريطة لتنجز المهام وتاخذ الأجرة.",
]

var bar: ProgressBar
var _t: float = 0.0
var _started: bool = false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	add_child(box)
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
	tip.custom_minimum_size = Vector2(900, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(700, 26)
	bar.max_value = 100
	box.add_child(bar)
	ResourceLoader.load_threaded_request(Game.next_scene)

func _process(delta: float) -> void:
	_t += delta
	var prog: Array = []
	var st := ResourceLoader.load_threaded_get_status(Game.next_scene, prog)
	var real: float = prog[0] * 100.0 if prog.size() > 0 else 0.0
	bar.value = minf(maxf(real, _t / 3.0 * 100.0), 100.0) if st != ResourceLoader.THREAD_LOAD_LOADED else minf(_t / 3.0 * 100.0, 100.0)
	if _t >= 3.0 and st == ResourceLoader.THREAD_LOAD_LOADED and not _started:
		_started = true
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(Game.next_scene))
