extends Node
## Global state, catalog, missions data, save/load.

const SAVE_PATH := "user://darb_save.json"

var money: int = 5000
var owned_vehicles: Array = ["mini"]
var owned_weapons: Array = []
var owned_clothes: Array = ["shirt_white", "pants_black"]
var outfit: Dictionary = {"shirt": "shirt_white", "pants": "pants_black", "head": ""}
var weapon_equipped: String = ""
var mission_index: int = 0
var hours: float = 8.0
var quality: int = 3        # 0 low, 1 medium, 2 high, 3 auto
var tier: int = 1           # detected device class 0..2
var busy: bool = false
var joy: Vector2 = Vector2.ZERO
var next_scene: String = "res://scenes/world.tscn"
var hud = null
## Not used by the arcade car any more (kept for old saves)
var engine_sign: float = 1.0
var font: Font
var lights = null
var night: float = 0.0
var day: int = 0
var season: int = 0
var _ui: AudioStreamPlayer
var _loaded_once: bool = false

var items: Array = []
var landmarks: Array = []
var givers: Array = ["أبو علي", "الحاج كاظم", "أم حيدر", "الأستاذ ليث", "سعد", "أبو زينب", "نور", "مصطفى", "أبو محمد", "الدكتورة رند"]
var story: Array = []

func _ready() -> void:
	font = load("res://fonts/DejaVuSans.ttf")
	tier = detect_tier()
	_setup_input()
	_build_items()
	_build_landmarks()
	_build_story()

func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_F], "brake": [KEY_SPACE], "jump": [KEY_SPACE], "horn": [KEY_H], "sprint": [KEY_SHIFT], "phone": [KEY_TAB],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)

func detect_tier() -> int:
	var cores := OS.get_processor_count()
	var mem_mb := 0
	var mi := OS.get_memory_info()
	if mi.has("physical"):
		mem_mb = int(mi["physical"]) / 1048576
	var score := 1
	if cores >= 8:
		score += 1
	elif cores <= 4:
		score -= 1
	if mem_mb >= 6000:
		score += 1
	elif mem_mb > 0 and mem_mb < 3500:
		score -= 1
	return clampi(score, 0, 2)

func play_ui(n: String) -> void:
	if _ui == null:
		_ui = AudioStreamPlayer.new()
		add_child(_ui)
	_ui.stream = Sfx.get_sound(n)
	_ui.volume_db = -4.0
	_ui.play()

func move_vec() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if joy.length() > v.length():
		v = joy
	return v

func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out + " د.ع"

# ---------------------------------------------------------------- catalog
func _build_items() -> void:
	items = [
		{"id": "pistol", "cat": "weapon", "name": "مسدس", "price": 400000},
		{"id": "shotgun", "cat": "weapon", "name": "بندقية صيد", "price": 900000},
		{"id": "smg", "cat": "weapon", "name": "رشاش خفيف", "price": 1200000},
		{"id": "rifle", "cat": "weapon", "name": "بندقية آلية", "price": 2500000},
		{"id": "shirt_white", "cat": "cloth", "slot": "shirt", "name": "دشداشة بيضاء", "price": 0, "color": Color(0.94, 0.94, 0.92), "robe": true},
		{"id": "shirt_blue", "cat": "cloth", "slot": "shirt", "name": "قميص أزرق", "price": 8000, "color": Color(0.2, 0.4, 0.8)},
		{"id": "shirt_red", "cat": "cloth", "slot": "shirt", "name": "قميص أحمر", "price": 6500, "color": Color(0.75, 0.12, 0.12)},
		{"id": "shirt_green", "cat": "cloth", "slot": "shirt", "name": "قميص أخضر", "price": 7500, "color": Color(0.15, 0.5, 0.25)},
		{"id": "shirt_black", "cat": "cloth", "slot": "shirt", "name": "قميص أسود", "price": 9000, "color": Color(0.08, 0.08, 0.1)},
		{"id": "suit", "cat": "cloth", "slot": "shirt", "name": "بدلة رسمية", "price": 120000, "color": Color(0.12, 0.13, 0.2)},
		{"id": "pants_black", "cat": "cloth", "slot": "pants", "name": "بنطلون أسود", "price": 0, "color": Color(0.08, 0.08, 0.09)},
		{"id": "pants_jeans", "cat": "cloth", "slot": "pants", "name": "جينز", "price": 12000, "color": Color(0.2, 0.3, 0.5)},
		{"id": "pants_beige", "cat": "cloth", "slot": "pants", "name": "بنطلون بيج", "price": 10000, "color": Color(0.72, 0.62, 0.45)},
		{"id": "head_ghutra", "cat": "cloth", "slot": "head", "name": "غترة وعقال", "price": 20000, "head": "ghutra"},
		{"id": "scooter", "cat": "bike", "name": "سكوتر", "price": 300000, "bike": true, "color": Color(0.9, 0.5, 0.1), "dim": Vector3(0.6, 1.0, 1.7), "power": 650.0, "max_speed": 20.0, "mass": 160.0},
		{"id": "moto", "cat": "bike", "name": "دراجة نارية", "price": 1000000, "bike": true, "color": Color(0.1, 0.1, 0.12), "dim": Vector3(0.7, 1.0, 2.1), "power": 1200.0, "max_speed": 38.0, "mass": 230.0},
		{"id": "mini", "cat": "car", "hidden": true, "name": "سيارتك الصغيرة", "price": 0, "color": Color(0.95, 0.75, 0.15), "dim": Vector3(1.6, 1.25, 3.4), "power": 1600.0, "max_speed": 28.0, "mass": 850.0},
		{"id": "sedan", "cat": "car", "name": "سيدان عائلية", "price": 3000000, "color": Color(0.72, 0.74, 0.8), "dim": Vector3(1.8, 1.3, 4.3), "power": 2300.0, "max_speed": 38.0, "mass": 1100.0},
		{"id": "taxi", "cat": "car", "name": "تكسي (أبيض وبرتقالي)", "price": 3500000, "taxi": true, "color": Color(0.96, 0.96, 0.96), "dim": Vector3(1.8, 1.3, 4.3), "power": 2300.0, "max_speed": 36.0, "mass": 1100.0},
		{"id": "pickup", "cat": "car", "name": "بيك أب", "price": 5000000, "color": Color(0.78, 0.58, 0.25), "dim": Vector3(2.0, 1.6, 5.0), "power": 2800.0, "max_speed": 32.0, "mass": 1700.0},
		{"id": "suv", "cat": "car", "name": "دفع رباعي", "price": 7000000, "color": Color(0.12, 0.18, 0.14), "dim": Vector3(2.0, 1.6, 4.8), "power": 3000.0, "max_speed": 34.0, "mass": 1900.0},
		{"id": "sport", "cat": "car", "name": "سيارة رياضية", "price": 12000000, "color": Color(0.8, 0.1, 0.1), "dim": Vector3(1.9, 1.2, 4.4), "power": 3600.0, "max_speed": 52.0, "mass": 1200.0},
	]

func item(id: String) -> Dictionary:
	for it in items:
		if it["id"] == id:
			return it
	return {}

func items_of(cats: Array) -> Array:
	var out: Array = []
	for it in items:
		if cats.has(it["cat"]) and not it.get("hidden", false):
			out.append(it)
	return out

func is_owned(id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	match it["cat"]:
		"weapon": return owned_weapons.has(id)
		"cloth": return owned_clothes.has(id)
		_: return owned_vehicles.has(id)

## returns "" on success or an error message
func buy(id: String) -> String:
	var it := item(id)
	if it.is_empty():
		return "غير موجود"
	if is_owned(id):
		return "تملكه من قبل"
	if money < int(it["price"]):
		return "فلوسك ما تكفي"
	money -= int(it["price"])
	match it["cat"]:
		"weapon": owned_weapons.append(id)
		"cloth": owned_clothes.append(id)
		_: owned_vehicles.append(id)
	return ""

func equip(id: String) -> void:
	var it := item(id)
	if it.is_empty():
		return
	if it["cat"] == "weapon":
		weapon_equipped = "" if weapon_equipped == id else id
	elif it["cat"] == "cloth":
		var slot: String = it["slot"]
		if slot == "head" and outfit["head"] == id:
			outfit["head"] = ""
		else:
			outfit[slot] = id

func apply_outfit(model: HumanModel) -> void:
	var sh := item(outfit["shirt"])
	var pa := item(outfit["pants"])
	var hd := item(outfit["head"]) if outfit["head"] != "" else {}
	var shirt_c: Color = sh.get("color", Color.WHITE)
	var pants_c: Color = pa.get("color", Color.BLACK)
	var head_k: String = hd.get("head", "")
	model.build(shirt_c, pants_c, Color(0.78, 0.6, 0.45), sh.get("robe", false), head_k)
	model.set_weapon(weapon_equipped)

# ---------------------------------------------------------------- landmarks & missions
func _build_landmarks() -> void:
	var data := [
		["مخبز أبو علي", Vector2i(-3, -2)], ["مقهى الشناشيل", Vector2i(-2, -1)], ["ساحة الرافدين", Vector2i(0, 0)],
		["مول الرافدين", Vector2i(1, 1)], ["سوق الشورجة", Vector2i(-1, 1)], ["مطعم الفرات", Vector2i(2, 0)],
		["جامعة دجلة", Vector2i(3, -1)], ["مستشفى الحياة", Vector2i(-4, 1)], ["جسر الكرخ", Vector2i(4, 3)],
		["كراج النهضة", Vector2i(2, -3)], ["محطة الوقود", Vector2i(-1, -3)], ["حديقة الأمة", Vector2i(0, 3)],
		["جامع الإمام", Vector2i(-3, 3)], ["فندق الشط", Vector2i(3, 2)], ["مدينة الألعاب", Vector2i(-4, -4)],
		["مكتب البريد", Vector2i(1, -1)], ["صيدلية الشفاء", Vector2i(-2, 3)], ["ملعب الشعب", Vector2i(4, -4)],
		["مصفى الدورة", Vector2i(6, 5)], ["حي السكن الشمالي", Vector2i(-6, -5)], ["الجامعة التقنية", Vector2i(5, -6)],
		["سوق الكاظمية", Vector2i(-5, 6)], ["مطار بغداد", Vector2i(7, -7)], ["جسر الجمهورية", Vector2i(-7, 2)],
		["حي الجامعة", Vector2i(6, 1)], ["مجمع الأمل", Vector2i(-6, -1)], ["ميناء النهر", Vector2i(0, -7)], ["قلعة المدينة", Vector2i(0, 7)],
	]
	landmarks.clear()
	for d in data:
		landmarks.append({"name": d[0], "grid": d[1]})

func lm_dist(a: int, b: int) -> float:
	var ga: Vector2i = landmarks[a]["grid"]
	var gb: Vector2i = landmarks[b]["grid"]
	return Vector2(ga - gb).length() * Nav.B

func _build_story() -> void:
	story = [
		{"title": "أول مشوار", "giver": "أبو علي", "from": 0, "to": 1,
		 "intro": [["أبو علي", "هلا بيك ابني! أني أبو علي صاحب المخبز. اليوم المحل مزدحم وما أگدر أترك التنور."],
				   ["أبو علي", "خذ هاي الصمونات الحارة وسلّمها لصاحب مقهى الشناشيل، وبعدها أعطيك أجرتك."]],
		 "outro": [["صاحب المقهى", "الله يخليك! صمون أبو علي ما ينتسى. هاك هاي الأجرة."]]},
		{"title": "أوراق مهمة", "giver": "الأستاذ ليث", "from": 1, "to": 2,
		 "intro": [["الأستاذ ليث", "أنت الشاب اللي يشتغل مشاوير؟ عندي أوراق ضرورية لازم توصل ساحة الرافدين."],
				   ["الأستاذ ليث", "المشاوير القريبة أجرتها قليلة، بس كل ما تبعد أكثر تزيد أجرتك."]],
		 "outro": [["موظف", "وصلت الأوراق! شكراً إلك، هاي أجرتك."]]},
		{"title": "وجبة للمطعم", "giver": "أبو علي", "from": 2, "to": 5,
		 "intro": [["أبو علي", "خذ هاي الأكلة لمطعم الفرات. وإذا جمعت فلوس، محل الدراجات يبيع سكوتر يسهّل عليك الطريق."]],
		 "outro": [["صاحب المطعم", "يعطيك العافية! تنتظرك مشاوير أبعد وأجرتها أحسن."]]},
		{"title": "رسالة للمستشفى", "giver": "الحاج كاظم", "from": 5, "to": 7,
		 "intro": [["الحاج كاظم", "ابني، هاي رسالة مستعجلة للمستشفى. المسافة بعيدة بس أجرتها تستاهل."],
				   ["الحاج كاظم", "وبعدين شغل التكسي أحسن شغل بالمدينة، اشتري تكسي من المعرض إذا صارت عندك فلوس."]],
		 "outro": [["الحاج كاظم", "سلمت إيدك! هاي أجرتك. افتح التلفون إذا تحتاج تكسي."]]},
	]

func _blocks(a: int, b: int) -> int:
	var ga: Vector2i = landmarks[a]["grid"]
	var gb: Vector2i = landmarks[b]["grid"]
	return absi(ga.x - gb.x) + absi(ga.y - gb.y)

func _pair(i: int) -> Vector2i:
	if i < story.size():
		return Vector2i(int(story[i]["from"]), int(story[i]["to"]))
	var r := RandomNumberGenerator.new()
	r.seed = 7919 * (i + 1)
	var n := landmarks.size()
	var a := r.randi_range(0, n - 1)
	var want := mini(2 + (i - story.size()) / 4, 12)
	var best := (a + 1) % n
	var best_d := 999
	for k in n:
		if k == a:
			continue
		var diff := absi(_blocks(a, k) - want)
		if diff < best_d or (diff == best_d and r.randf() < 0.4):
			best_d = diff
			best = k
	return Vector2i(a, best)

func _reward(i: int, dist: float, vehicle: bool) -> int:
	var v := (1500.0 + dist * 28.0) * (1.25 if vehicle else 1.0) * (1.0 + float(i) * 0.03)
	return int(roundf(v / 250.0)) * 250

func make_mission(i: int) -> Dictionary:
	var pr := _pair(i)
	var a := pr.x
	var b := pr.y
	var travel := 0.0
	if i > 0:
		travel = float(_blocks(_pair(i - 1).y, a)) * Nav.B
	var dist := float(_blocks(a, b)) * Nav.B + travel
	if i < story.size():
		var m: Dictionary = story[i].duplicate()
		m["vehicle"] = false
		m["reward"] = _reward(i, dist, false)
		return m
	var r := RandomNumberGenerator.new()
	r.seed = 104729 * (i + 1)
	var has_v := owned_vehicles.size() > 0
	var giver: String = givers[r.randi() % givers.size()]
	var kind := r.randi() % 5
	if not has_v and (kind == 1 or kind == 2 or kind == 4):
		kind = 0 if r.randf() < 0.5 else 3
	var dest: String = landmarks[b]["name"]
	var title := ""
	var intro: Array = []
	var outro: Array = []
	var vehicle := false
	match kind:
		0:
			title = "توصيل طرد"
			intro = [[giver, "عندي طرد لازم يوصل %s اليوم. تگدر تلحگه؟" % dest], [giver, "دير بالك عليه، فيه أغراض مهمة."]]
			outro = [["المستلم", "الله يعافيك، وصل سليم! هاي الأجرة."]]
		1:
			title = "طلبية أكل"
			vehicle = true
			intro = [[giver, "الزبون ينتظر الأكل بـ %s. لازم بسيارة أو دراجة حتى ما يبرد." % dest], [giver, "يلا، كل دقيقة تفرق!"]]
			outro = [["الزبون", "حار وبوقته! تستاهل بخشيش."]]
		2:
			title = "راكب مستعجل"
			vehicle = true
			intro = [[giver, "أحتاج أوصل %s بأسرع وقت، عندي موعد." % dest], [giver, "سوق على كيفك بس لا تتأخر."]]
			outro = [[giver, "سلمت إيدك، لحگت الموعد. هاي أجرتك مع زيادة."]]
		3:
			title = "تسليم مستندات"
			intro = [[giver, "هاي ملفات الدائرة، سلمها لـ %s." % dest], [giver, "ولا تضيعها ابني."]]
			outro = [["الموظف", "تمام، استلمتها. تفضل أجرتك."]]
		_:
			title = "جلب أغراض"
			vehicle = true
			intro = [[giver, "كلمني صديقي بـ %s يريد أغراض من عندي. خذها له بسيارتك أو دراجتك." % dest]]
			outro = [["الصديق", "يا هلا بيك! شكراً على المشوار."]]
	return {"title": title, "giver": giver, "from": a, "to": b, "vehicle": vehicle,
		"reward": _reward(i, dist, vehicle), "intro": intro, "outro": outro}

# ---------------------------------------------------------------- save / load
func load_game_if_first() -> void:
	if not _loaded_once:
		_loaded_once = true
		load_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_progress() -> void:
	money = 5000
	owned_vehicles = ["mini"]
	owned_weapons = []
	owned_clothes = ["shirt_white", "pants_black"]
	outfit = {"shirt": "shirt_white", "pants": "pants_black", "head": ""}
	weapon_equipped = ""
	mission_index = 0
	hours = 8.0
	day = 0

func save_game() -> void:
	var d := {"money": money, "veh": owned_vehicles, "wep": owned_weapons, "clo": owned_clothes,
		"outfit": outfit, "weapon": weapon_equipped, "mission": mission_index, "hours": hours, "quality": quality, "day": day}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_game() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	money = int(d.get("money", money))
	owned_vehicles = d.get("veh", ["mini"])
	if not owned_vehicles.has("mini"):
		owned_vehicles.append("mini")
	owned_weapons = d.get("wep", [])
	owned_clothes = d.get("clo", owned_clothes)
	outfit = d.get("outfit", outfit)
	weapon_equipped = d.get("weapon", "")
	mission_index = int(d.get("mission", 0))
	hours = float(d.get("hours", 8.0))
	quality = int(d.get("quality", 3))
	day = int(d.get("day", 0))

func apply_quality() -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 1.0
