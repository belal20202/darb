class_name Pedestrian
extends CharacterBody3D
## Sidewalk walker that loops around a city block.

var model: HumanModel
var corners: Array = []
var idx: int = 0
var speed: float = 1.3
var chat_lines: Array = ["السلام عليكم!", "الجو اليوم حلو، مو؟", "دير بالك من السواقين بهالشارع.", "تدري؟ مول الرافدين فيه ملابس حلوة.", "أني أنتظر صديقي من ساعة..."]

func setup(c: Array, start_i: int, shirt: Color, pants: Color) -> void:
	corners = c
	idx = start_i % c.size()
	collision_layer = 4
	collision_mask = 1
	add_to_group("ped")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	model = HumanModel.new()
	add_child(model)
	model.build(shirt, pants, Color(0.72 + randf() * 0.1, 0.55, 0.42), randf() < 0.3)
	position = corners[idx]
	speed = 1.0 + randf() * 0.7

func _physics_process(delta: float) -> void:
	var target: Vector3 = corners[idx]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		idx = (idx + 1) % corners.size()
		return
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 20.0 * delta
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	model.animate(speed, delta)
