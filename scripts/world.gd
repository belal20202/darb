extends Node3D
## Main game scene: builds the city, spawns everything, runs day/night, shops and interaction.

const DAY_SECONDS := 1200.0   # one in-game day = 20 real minutes

var rng := RandomNumberGenerator.new()
var city: CityBuilder
var player: Player
var hud: HUD
var missions: MissionManager
var taxi: TaxiService
var lights: TrafficLights
var weather: Weather
var quality_mgr: QualityManager
var vehicles: Array = []
var cull_dist: float = 70.0
var _cull_t: float = 0.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var moon_mesh: MeshInstance3D
var owned_cars: Dictionary = {}
var interiors: Dictionary = {}
var in_shop: int = -1
var shop_return: Vector3 = Vector3.ZERO
var act: Callable = Callable()
var _cands: Array = []
var _prompt_t: float = 0.0
var _save_t: float = 0.0
var _peds: Array = []

func _ready() -> void:
	rng.randomize()
	Game.busy = false
	Game.apply_quality()
	_setup_environment()
	Game.season = (Game.day / 6) % 4
	city = CityBuilder.new()
	city.build(self)
	lights = TrafficLights.new()
	add_child(lights)
	lights.build(self, city.poles_body)
	Game.lights = lights
	player = Player.new()
	add_child(player)
	player.global_position = city.home_door + Vector3(0, 0.5, 2.0)
	hud = HUD.new()
	hud.world = self
	add_child(hud)
	quality_mgr = QualityManager.new()
	quality_mgr.world = self
	add_child(quality_mgr)
	weather = Weather.new()
	weather.world = self
	add_child(weather)
	missions = MissionManager.new()
	missions.world = self
	add_child(missions)
	taxi = TaxiService.new()
	taxi.world = self
	add_child(taxi)
	quality_mgr.apply()
	missions.begin()
	for id in Game.owned_vehicles:
		spawn_owned(id)
	_spawn_peds([10, 14, 18][Game.tier])
	_spawn_traffic([4, 6, 8][Game.tier])
	_update_sky()
	hud.set_time(Game.hours)
	hud.show_driving(false)
	hud.say([["أبو علي", "صباح الخير ابني! أهلاً بيك بدرب الرافدين. اتبع السهم الأخضر أعلى الشاشة لتبدأ أول مشوار."]])

# ---------------------------------------------------------------- environment / time
func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0012
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	add_child(moon)
	moon_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 14.0
	sm.height = 28.0
	sm.radial_segments = 16
	sm.rings = 8
	moon_mesh.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.95, 0.95, 0.85)
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mesh.material_override = mm
	add_child(moon_mesh)

func _update_sky() -> void:
	var h := Game.hours
	var rise: float = [6.0, 5.0, 6.0, 7.0][Game.season]
	var set_h: float = [18.0, 19.0, 18.0, 17.0][Game.season]
	var day_len := set_h - rise
	var hh := fposmod(h - rise, 24.0)
	var ang := PI + (hh - day_len) / (24.0 - day_len) * PI
	if hh < day_len:
		ang = hh / day_len * PI
	var s := sin(ang)
	var cl := weather.cloud
	var dust := weather.dust
	var mist := weather.mist
	var rain := weather.rain
	var night := clampf(1.0 - clampf(s * 3.0 + 0.25, 0.0, 1.0), 0.0, 1.0)
	Game.night = night
	sun.rotation = Vector3(-ang, deg_to_rad(40.0), 0.0)
	sun.light_energy = clampf(s * 1.3, 0.0, 1.2) * (1.0 - 0.65 * cl)
	sun.light_color = Color(1.0, 0.75 + 0.2 * clampf(s * 2.0, 0.0, 1.0), 0.55 + 0.4 * clampf(s * 2.0, 0.0, 1.0))
	moon.rotation = Vector3(-(ang + PI), deg_to_rad(40.0), 0.0)
	moon.light_energy = 0.25 * night * (1.0 - 0.5 * cl)
	var day_top := Color(0.25, 0.5, 0.92)
	var night_top := Color(0.01, 0.015, 0.05)
	var day_hz := Color(0.7, 0.8, 0.9)
	var dusk_hz := Color(0.95, 0.55, 0.3)
	var night_hz := Color(0.03, 0.04, 0.09)
	var grey := Color(0.5, 0.52, 0.55).lerp(Color(0.02, 0.02, 0.04), night)
	var dust_c := Color(0.78, 0.58, 0.32).lerp(Color(0.08, 0.06, 0.04), night)
	var dusk := 1.0 - clampf(absf(s) * 4.0, 0.0, 1.0)
	var top := day_top.lerp(night_top, night)
	top = top.lerp(grey, clampf(cl * 0.85 + mist * 0.5, 0.0, 1.0))
	top = top.lerp(dust_c, dust * 0.9)
	sky_mat.sky_top_color = top
	var hz := day_hz.lerp(dusk_hz, dusk * 0.7 * (1.0 - cl))
	hz = hz.lerp(night_hz, night)
	hz = hz.lerp(grey, clampf(cl * 0.8 + mist * 0.7, 0.0, 1.0))
	hz = hz.lerp(dust_c, dust * 0.95)
	sky_mat.sky_horizon_color = hz
	sky_mat.ground_horizon_color = hz
	sky_mat.ground_bottom_color = Color(0.1, 0.09, 0.08).lerp(Color(0, 0, 0), night)
	var amb := Color(0.62, 0.66, 0.74).lerp(Color(0.1, 0.12, 0.2), night)
	amb = amb.lerp(Color(0.5, 0.52, 0.55) * (1.0 - night * 0.8), cl * 0.5)
	env.ambient_light_color = amb
	env.ambient_light_energy = lerpf(1.0, 0.8, night) + weather.flash * 3.0
	env.fog_density = 0.0012 + mist * 0.012 + rain * 0.004 + dust * 0.014
	env.fog_light_color = hz
	city.set_night(night)
	var cp := player.global_position if player else Vector3.ZERO
	moon_mesh.global_position = cp + moon.global_transform.basis.z * 380.0
	moon_mesh.visible = night > 0.2 and cl < 0.8

func _apply_season() -> void:
	city.set_season(Game.season)

func _process(delta: float) -> void:
	var prev_h := Game.hours
	Game.hours = fposmod(Game.hours + delta * 24.0 / DAY_SECONDS, 24.0)
	if Game.hours < prev_h:
		Game.day += 1
		var ns := (Game.day / 6) % 4
		if ns != Game.season:
			Game.season = ns
			_apply_season()
	_prompt_t += delta
	if _prompt_t > 0.1:
		_prompt_t = 0.0
		_update_sky_slow()
		_update_prompt()
	if Input.is_action_just_pressed("interact") and not Game.busy:
		do_interact()
	if Input.is_action_just_pressed("phone"):
		hud.open_phone()
	_cull_t += delta
	if _cull_t > 0.5:
		_cull_t = 0.0
		_cull()
	_save_t += delta
	if _save_t > 60.0:
		_save_t = 0.0
		Game.save_game()

var _sky_t: float = 0.0
var _hud_t: float = 0.0
func _update_sky_slow() -> void:
	_sky_t += 0.1
	if _sky_t >= 0.5:
		_sky_t = 0.0
		_update_sky()
	_hud_t += 0.1
	if _hud_t >= 1.0:
		_hud_t = 0.0
		hud.set_time(Game.hours)
		hud.set_weather("%s   %d°   %s" % [Weather.SEASON_NAMES[Game.season], int(weather.temp(Game.hours)), Weather.NAMES[weather.kind]])

# ---------------------------------------------------------------- spawning
func make_marker(c: Color) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.0
	cm.bottom_radius = 2.0
	cm.height = 40.0
	cm.radial_segments = 16
	cm.rings = 1
	mi.mesh = cm
	mi.position = Vector3(0, 20, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	mi.material_override = m
	n.add_child(mi)
	add_child(n)
	return n

func current_target() -> Variant:
	if missions and missions.marker and missions.marker.visible:
		return missions.marker.global_position
	if taxi and taxi.marker and taxi.marker.visible:
		return taxi.marker.global_position
	return null

func _make_vehicle(spec: Dictionary) -> Vehicle:
	var v := Vehicle.new()
	add_child(v)
	v.setup(spec)
	vehicles.append(v)
	return v

func spawn_owned(id: String) -> void:
	if owned_cars.has(id) and is_instance_valid(owned_cars[id]):
		return
	var spec := Game.item(id)
	if spec.is_empty():
		return
	var spots: Array = city.parking
	var k: int = owned_cars.size() % spots.size()
	var v := _make_vehicle(spec)
	v.owned = true
	v.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), spots[k])
	owned_cars[id] = v

func spawn_ai_vehicle(spec: Dictionary, g: Vector2i, route: Array, speed: float = 11.0) -> Vehicle:
	var v := _make_vehicle(spec)
	var pos := Nav.grid_to_pos(g)
	var yaw := 0.0
	if not route.is_empty():
		var first: Vector3 = route[0]
		var d := first - pos
		d.y = 0.0
		yaw = Nav.yaw_for_dir(d.normalized())
		pos = Vector3(first.x, 0.9, first.z) - d.normalized() * 16.0
	pos.y = 0.9
	v.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	var drv := HumanModel.new()
	drv.build(Color(rng.randf(), rng.randf(), rng.randf()), Color(0.1, 0.1, 0.12), Color(0.75, 0.58, 0.45))
	v.set_driver(drv)
	v.start_ai(route, speed)
	return v

func _spawn_traffic(n: int) -> void:
	var specs := [Game.item("sedan"), Game.item("taxi"), Game.item("suv"), Game.item("pickup")]
	for i in n:
		var g := Vector2i(rng.randi_range(-Nav.N, Nav.N), rng.randi_range(-Nav.N, Nav.N))
		var r := Nav.random_route(g, 40, rng)
		if r.is_empty():
			continue
		var v := spawn_ai_vehicle(specs[i % specs.size()], g, r, rng.randf_range(9.0, 14.0))
		v.route_done = func(car: Vehicle):
			car.route = Nav.random_route(Nav.nearest_grid(car.global_position), 40, rng)

func _spawn_peds(n: int) -> void:
	for i in n:
		var b: Dictionary = city.blocks[rng.randi() % city.blocks.size()]
		var inset := 1.5
		var y := 0.2
		var cs := [Vector3(b["x0"] + inset, y, b["z0"] + inset), Vector3(b["x1"] - inset, y, b["z0"] + inset),
			Vector3(b["x1"] - inset, y, b["z1"] - inset), Vector3(b["x0"] + inset, y, b["z1"] - inset)]
		if rng.randf() < 0.5:
			cs.reverse()
		var p := Pedestrian.new()
		add_child(p)
		p.setup(cs, rng.randi() % 4, Color(rng.randf(), rng.randf(), rng.randf()), Color(0.12, 0.12, 0.16) if rng.randf() < 0.6 else Color(0.2, 0.3, 0.5))
		_peds.append(p)

func _cull() -> void:
	var pp := player.global_position
	for p in _peds:
		if is_instance_valid(p):
			var vis: bool = pp.distance_to(p.global_position) < cull_dist and in_shop < 0
			p.visible = vis
			p.set_physics_process(vis)
	for v in vehicles:
		if is_instance_valid(v):
			v.visible = in_shop < 0 and pp.distance_to(v.global_position) < cull_dist * 1.6

func despawn_later(node: Node, secs: float) -> void:
	get_tree().create_timer(secs).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())

# ---------------------------------------------------------------- inventory hooks
func on_inventory_changed(id: String) -> void:
	var it := Game.item(id)
	if it.is_empty():
		return
	if it["cat"] == "car" or it["cat"] == "bike":
		spawn_owned(id)
		hud.toast("سيارتك/دراجتك صارت أمام البيت")
	player.refresh_model()

# ---------------------------------------------------------------- interaction
func _add_cand(d: float, text: String, cb: Callable) -> void:
	_cands.append([d, text, cb])

func _update_prompt() -> void:
	act = Callable()
	_cands = []
	if Game.busy or player.ride_car != null:
		hud.set_prompt("")
		return
	var pp := player.global_position
	if player.vehicle != null:
		if player.vehicle.linear_velocity.length() < 3.0:
			_add_cand(0.0, "نزول", _exit_vehicle)
		hud.show_driving(true)
	else:
		hud.show_driving(false)
		if in_shop >= 0:
			var info: Dictionary = interiors[in_shop]
			var kd: float = pp.distance_to(info["keeper"])
			if kd < 3.5:
				_add_cand(kd, "كلّم البائع", _talk_keeper)
			var ed: float = pp.distance_to(info["exit"])
			if ed < 2.5:
				_add_cand(ed, "خروج", _exit_shop)
		else:
			for d in city.doors:
				var dd := pp.distance_to(d["pos"])
				if dd < 3.0:
					_add_cand(dd, "دخول: " + city.shops[d["shop"]]["name"], _enter_shop.bind(int(d["shop"])))
			for cv in vehicles:
				if is_instance_valid(cv):
					var vd := pp.distance_to(cv.global_position)
					if vd < 4.5:
						if cv.owned:
							_add_cand(vd, "ركوب", _enter_vehicle.bind(cv))
						elif taxi.can_board() and cv == taxi.hail_car:
							_add_cand(vd, "ركوب التكسي", taxi.board)
						else:
							_add_cand(vd + 1.0, "سيارة غير مملوكة", _no_steal)
			for p in _peds:
				if is_instance_valid(p):
					var pd := pp.distance_to(p.global_position)
					if pd < 2.5:
						_add_cand(pd + 0.5, "تحدّث", _chat.bind(p))
	if _cands.is_empty():
		hud.set_prompt("")
		return
	_cands.sort_custom(func(a, b): return a[0] < b[0])
	var best: Array = _cands[0]
	act = best[2]
	hud.set_prompt(best[1])

func do_interact() -> void:
	if act.is_valid() and not Game.busy:
		act.call()

func _enter_vehicle(v: Vehicle) -> void:
	player.enter_vehicle(v)
	hud.show_driving(true)

func _exit_vehicle() -> void:
	player.exit_vehicle()
	hud.show_driving(false)

func _no_steal() -> void:
	hud.toast("ما تگدر تسرق السيارات! اشتغل واشتري سيارتك.")

func _chat(p: Pedestrian) -> void:
	hud.say([["مارّ", p.chat_lines[rng.randi() % p.chat_lines.size()]]])

# ---------------------------------------------------------------- shop interiors
func _build_interior(idx: int) -> void:
	var shop: Dictionary = city.shops[idx]
	var o := Vector3(2000.0 + idx * 60.0, 0.0, 2000.0)
	var w := 18.0
	var d := 14.0
	var wallm := Vehicle.mat(Color(0.88, 0.84, 0.76), 1.0, 0.9)
	var floorm := Vehicle.mat(Color(0.55, 0.5, 0.45), 1.0, 0.8)
	_box(o + Vector3(0, -0.15, 0), Vector3(w, 0.3, d), floorm)
	_box(o + Vector3(0, 4.15, 0), Vector3(w, 0.3, d), wallm)
	_box(o + Vector3(0, 2, -d * 0.5), Vector3(w, 4, 0.3), wallm)
	_box(o + Vector3(0, 2, d * 0.5), Vector3(w, 4, 0.3), wallm)
	_box(o + Vector3(-w * 0.5, 2, 0), Vector3(0.3, 4, d), wallm)
	_box(o + Vector3(w * 0.5, 2, 0), Vector3(0.3, 4, d), wallm)
	_box(o + Vector3(0, 0.55, -2.5), Vector3(5, 1.1, 1.2), Vehicle.mat(Color(0.4, 0.25, 0.15)))
	var light := OmniLight3D.new()
	light.position = o + Vector3(0, 3.5, 0)
	light.omni_range = 22.0
	light.light_energy = 1.6
	add_child(light)
	var keeper := HumanModel.new()
	keeper.build(Color(0.2, 0.3, 0.5), Color(0.1, 0.1, 0.12), Color(0.75, 0.58, 0.45))
	keeper.position = o + Vector3(0, 0, -3.5)
	add_child(keeper)
	var stype: String = shop["type"]
	match stype:
		"car":
			var pos := -4.0
			for id in ["sedan", "sport", "suv", "taxi"]:
				var m := Vehicle.build_mesh(Game.item(id))
				m.position = o + Vector3(pos * 1.0 - 1.0, 0.2, -5.2)
				m.rotation.y = PI
				m.scale = Vector3.ONE * 0.8
				add_child(m)
				pos += 4.0
		"bike":
			for k in 3:
				var m2 := Vehicle.build_mesh(Game.item("scooter" if k != 1 else "moto"))
				m2.position = o + Vector3(-5.0 + k * 5.0, 0.2, -5.5)
				add_child(m2)
		"weapons":
			for k in 5:
				_box(o + Vector3(-6.0 + k * 3.0, 1.6, -d * 0.5 + 0.4), Vector3(0.1, 0.12, 1.1), Vehicle.mat(Color(0.1, 0.1, 0.1)))
		_:
			for k in 6:
				_box(o + Vector3(-7.5 + k * 3.0, 1.2, -d * 0.5 + 0.5), Vector3(1.2, 2.2, 0.5),
					Vehicle.mat(Color.from_hsv(rng.randf(), 0.6, 0.8)))
	var lab := Label3D.new()
	lab.text = shop["name"]
	lab.font = Game.font
	lab.font_size = 96
	lab.pixel_size = 0.012
	lab.position = o + Vector3(0, 3.2, -d * 0.5 + 0.3)
	add_child(lab)
	interiors[idx] = {"origin": o, "keeper": o + Vector3(0, 0, -3.5), "exit": o + Vector3(0, 0, d * 0.5 - 1.5)}

func _box(pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	mi.add_child(sb)

func _enter_shop(idx: int) -> void:
	if not interiors.has(idx):
		_build_interior(idx)
	shop_return = player.global_position
	in_shop = idx
	var info: Dictionary = interiors[idx]
	player.global_position = info["exit"] + Vector3(0, 0.3, -1.0)
	player.yaw = 0.0
	player.velocity = Vector3.ZERO
	missions.marker.visible = false

func _exit_shop() -> void:
	in_shop = -1
	player.global_position = shop_return + Vector3(0, 0.3, 1.2)
	player.velocity = Vector3.ZERO
	player.yaw = PI
	missions.marker.visible = true

func _talk_keeper() -> void:
	var shop: Dictionary = city.shops[in_shop]
	var greet := "هلا والله! تفضل، شتحب تشوف؟"
	match shop["type"]:
		"car": greet = "أهلاً أستاذ! عندنا سيارات عائلية ورياضية وتكسي. بيعنا مضمون."
		"bike": greet = "هلا بيك! دراجاتنا خفيفة وسريعة، ومناسبة للزحمة."
		"weapons": greet = "تفضل. كل شي عندنا مرخّص، بس دير بالك."
		"clothes": greet = "أهلاً! أحلى الملابس والغترة العراقية عندنا."
		"mall": greet = "أهلاً بمول الرافدين! ملابس وأزياء لكل الأذواق."
	var cats: Array = shop["cats"]
	var title: String = shop["name"]
	hud.say([["البائع", greet]], func(): hud.open_shop(title, cats))
