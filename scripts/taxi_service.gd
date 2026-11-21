class_name TaxiService
extends Node
## (1) Hail an AI taxi and ride to a landmark. (2) Work as a taxi driver in your own taxi.

var world: Node3D
var marker: Node3D
var hail_car: Vehicle = null
var ride_state: int = 0   # 0 none, 1 coming, 2 arrived, 3 riding
var ride_dest: int = -1
var ride_fare: int = 0
var job_on: bool = false
var job_stage: int = 0    # 1 go to passenger, 2 drive to destination
var pickup: int = -1
var dest: int = -1
var _wait: bool = false
var _t: float = 0.0
var _timeout: float = 0.0

func _ready() -> void:
	marker = world.make_marker(Color(1.0, 0.85, 0.1))
	marker.visible = false

# ------------------------------------------------------------ hailing
func hail() -> void:
	if ride_state != 0:
		world.hud.toast("التكسي بالطريق إلك")
		return
	var pl: Player = world.player
	if pl.in_vehicle() or world.in_shop >= 0:
		world.hud.toast("اطلب التكسي وأنت واقف بالشارع")
		return
	var g := Nav.nearest_grid(pl.global_position)
	var opts := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var sg := g
	for d in opts:
		var c: Vector2i = g + d
		if absi(c.x) <= Nav.N and absi(c.y) <= Nav.N:
			sg = c
			break
	if sg == g:
		return
	var spec := Game.item("taxi")
	hail_car = world.spawn_ai_vehicle(spec, sg, Nav.route_between(sg, g), 12.0)
	hail_car.route_done = _on_arrived
	ride_state = 1
	_timeout = 90.0
	world.hud.toast("التكسي جاي إلك، انتظر قرب الشارع")

func _on_arrived(_car: Vehicle) -> void:
	if ride_state == 1:
		ride_state = 2
		hail_car.route_done = Callable()
		world.hud.toast("وصل التكسي! اضغط للركوب")

func can_board() -> bool:
	return ride_state == 2 and hail_car != null and is_instance_valid(hail_car)

func board() -> void:
	world.player.board_passenger(hail_car)
	ride_state = 3
	world.hud.say([["السائق", "السلام عليكم أستاذ، وين أوصلك؟"]], func():
		world.hud.open_destinations(_dest_chosen))

func _dest_chosen(idx: int) -> void:
	ride_dest = idx
	var from_g := Nav.nearest_grid(hail_car.global_position)
	var to_g: Vector2i = Game.landmarks[idx]["grid"]
	var dist := Vector2(from_g - to_g).length() * Nav.B
	ride_fare = 1000 + int(dist * 12.0)
	if from_g == to_g:
		_on_dest(hail_car)
		return
	hail_car.route = Nav.route_between(from_g, to_g)
	hail_car.route_done = _on_dest
	hail_car.cruise = 14.0
	world.hud.toast("الأجرة التقريبية: " + Game.fmt(ride_fare))

func _on_dest(car: Vehicle) -> void:
	car.route_done = Callable()
	world.hud.say([["السائق", "وصلنا أستاذ. الأجرة %s." % Game.fmt(ride_fare)]], func():
		var pay := mini(ride_fare, Game.money)
		Game.money -= pay
		world.hud.set_money()
		world.player.leave_passenger()
		car.start_ai(Nav.random_route(Nav.nearest_grid(car.global_position), 3, world.rng), 12.0)
		world.despawn_later(car, 25.0)
		hail_car = null
		ride_state = 0)

# ------------------------------------------------------------ own taxi job
func toggle_job() -> void:
	var pl: Player = world.player
	if job_on:
		job_on = false
		job_stage = 0
		marker.visible = false
		world.hud.toast("أوقفت شغل التكسي")
		return
	if pl.vehicle == null or not pl.vehicle.is_taxi or not pl.vehicle.owned:
		world.hud.toast("اركب تكسيك الخاص أولاً")
		return
	job_on = true
	_new_fare()

func _new_fare() -> void:
	var n := Game.landmarks.size()
	pickup = world.rng.randi_range(0, n - 1)
	dest = (pickup + world.rng.randi_range(3, n - 3)) % n
	job_stage = 1
	_wait = false
	marker.global_position = Nav.grid_to_pos(Game.landmarks[pickup]["grid"])
	marker.visible = true
	world.hud.toast("راكب ينتظرك عند " + Game.landmarks[pickup]["name"])

func _process(delta: float) -> void:
	if ride_state == 1 or ride_state == 2:
		_timeout -= delta
		if _timeout <= 0.0:
			if hail_car != null and is_instance_valid(hail_car):
				hail_car.queue_free()
			hail_car = null
			ride_state = 0
	if not job_on or _wait or Game.busy:
		return
	var pl: Player = world.player
	if pl.vehicle == null or not pl.vehicle.is_taxi:
		return
	_t += delta
	if _t < 0.3:
		return
	_t = 0.0
	var idx := pickup if job_stage == 1 else dest
	var tp := Nav.grid_to_pos(Game.landmarks[idx]["grid"])
	var d := Vector2(pl.global_position.x - tp.x, pl.global_position.z - tp.z).length()
	if d < 7.0 and pl.vehicle.linear_velocity.length() < 8.0:
		_wait = true
		if job_stage == 1:
			var dn: String = Game.landmarks[dest]["name"]
			world.hud.say([["الراكب", "السلام عليكم أستاذ، أريد أروح إلى %s." % dn]], func():
				job_stage = 2
				_wait = false
				marker.global_position = Nav.grid_to_pos(Game.landmarks[dest]["grid"]))
		else:
			var dist := Game.lm_dist(pickup, dest)
			var fare := 1500 + int(dist * 28.0)
			world.hud.say([["الراكب", "سلمت إيدك! تفضل الأجرة."]], func():
				Game.money += fare
				world.hud.set_money()
				Game.play_ui("coin")
				world.hud.toast("أجرة الراكب: " + Game.fmt(fare))
				_new_fare())
