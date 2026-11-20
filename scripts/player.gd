class_name Player
extends CharacterBody3D
## On-foot controller + third-person camera. Uses the animated .glb character
## (falls back to the procedural HumanModel if the .glb is missing).

const WALK := 3.4
const RUN := 6.8
const ACCEL := 20.0
const GRAVITY := 24.0
const JUMP_SPEED := 7.0

var yaw: float = 0.0
var pitch: float = -0.22
var chara: PlayerCharacter = null
var model: HumanModel = null
var body: Node3D
var vehicle: Vehicle = null
var ride_car: Vehicle = null
var pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D
var _col: CollisionShape3D
var _idle_look: float = 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	_col.shape = cap
	_col.position = Vector3(0, 0.88, 0)
	add_child(_col)
	chara = PlayerCharacter.new()
	add_child(chara)
	if chara.ok:
		body = chara
	else:
		chara.queue_free()
		chara = null
		model = HumanModel.new()
		add_child(model)
		body = model
		refresh_model()
	pivot = Node3D.new()
	pivot.top_level = true
	add_child(pivot)
	arm = SpringArm3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	arm.shape = sph
	arm.collision_mask = 1
	arm.spring_length = 4.8
	pivot.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 450.0
	cam.current = true
	arm.add_child(cam)
	pivot.global_position = global_position + Vector3(0, 1.5, 0)

func refresh_model() -> void:
	if model != null:
		Game.apply_outfit(model)

func heading() -> float:
	if vehicle != null:
		return vehicle.global_transform.basis.get_euler().y
	if ride_car != null:
		return ride_car.global_transform.basis.get_euler().y
	return body.rotation.y

func in_vehicle() -> bool:
	return vehicle != null or ride_car != null

func enter_vehicle(v: Vehicle) -> void:
	vehicle = v
	v.driver_is_player = true
	var m: Node3D
	if chara != null:
		m = PlayerCharacter.new()
	else:
		var hm := HumanModel.new()
		Game.apply_outfit(hm)
		m = hm
	v.set_driver(m)
	body.visible = false
	_col.disabled = true
	velocity = Vector3.ZERO

func exit_vehicle() -> void:
	if vehicle == null:
		return
	var v := vehicle
	v.driver_is_player = false
	v.remove_driver()
	vehicle = null
	global_position = v.global_position - v.global_transform.basis.x * 2.0 + Vector3(0, 0.6, 0)
	body.visible = true
	_col.disabled = false

func board_passenger(v: Vehicle) -> void:
	ride_car = v
	body.visible = false
	_col.disabled = true

func leave_passenger() -> void:
	if ride_car == null:
		return
	var v := ride_car
	ride_car = null
	global_position = v.global_position - v.global_transform.basis.x * 2.4 + Vector3(0, 0.6, 0)
	body.visible = true
	_col.disabled = false

func _unhandled_input(e: InputEvent) -> void:
	var w := get_viewport().get_visible_rect().size.x
	if e is InputEventScreenDrag and e.position.x > w * 0.4:
		yaw -= e.relative.x * 0.005
		pitch = clampf(pitch - e.relative.y * 0.004, -1.1, 0.3)
		_idle_look = 0.0
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		yaw -= e.relative.x * 0.004
		pitch = clampf(pitch - e.relative.y * 0.003, -1.1, 0.3)
		_idle_look = 0.0

func _physics_process(delta: float) -> void:
	var follow := global_position
	if vehicle != null:
		follow = vehicle.global_position
		global_position = follow
		velocity = Vector3.ZERO
	elif ride_car != null:
		follow = ride_car.global_position
		global_position = follow
		velocity = Vector3.ZERO
	else:
		_walk(delta)
		follow = global_position
	_update_camera(follow, delta)

func _walk(delta: float) -> void:
	var mv := Vector2.ZERO
	if not Game.busy:
		mv = Game.move_vec()
	var b := Basis(Vector3.UP, yaw)
	var dir := b * Vector3(mv.x, 0.0, mv.y)
	var top := WALK
	if mv.length() > 0.85:
		top = RUN
	var want := dir * top * minf(mv.length(), 1.0)
	velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	if is_on_floor():
		velocity.y = -1.0
		if not Game.busy and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-velocity.x, -velocity.z), 10.0 * delta)
	if chara != null:
		chara.update_motion(hs, is_on_floor(), delta)
	elif model != null:
		model.animate(hs, delta)

func _update_camera(follow: Vector3, delta: float) -> void:
	_idle_look += delta
	var dist := 4.8
	var height := 1.5
	if in_vehicle():
		dist = 7.5
		height = 1.8
		if _idle_look > 1.2 and Input.get_last_mouse_velocity().length() < 5.0:
			yaw = lerp_angle(yaw, heading(), 1.8 * delta)
			pitch = lerpf(pitch, -0.2, 2.0 * delta)
	arm.spring_length = lerpf(arm.spring_length, dist, 4.0 * delta)
	var target := follow + Vector3(0, height, 0)
	pivot.global_position = pivot.global_position.lerp(target, clampf(12.0 * delta, 0.0, 1.0))
	pivot.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
