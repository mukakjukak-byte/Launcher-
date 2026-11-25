class_name Player
extends CharacterBody3D
## Игрок: ходьба (Alt), бег, спринт (Shift), прыжок, посадка в машину (F).

const WALK := 1.8
const RUN := 4.6
const SPRINT := 7.5
const JUMP := 4.6
const ACCEL := 10.0

var model: Humanoid
var rig: CameraRig
var car: Car = null
var sprint_touch := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fall_start := 0.0


func _ready() -> void:
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_CAR
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = Humanoid.new()
	add_child(model)
	var tag := Label3D.new()
	tag.text = Game.nick
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 48
	tag.outline_size = 10
	tag.pixel_size = 0.005
	tag.position.y = 2.25
	tag.modulate = Color(1, 1, 1, 0.9)
	tag.no_depth_test = false
	add_child(tag)


func _physics_process(delta: float) -> void:
	if car != null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if Game.touch_move.length() > 0.05:
		input = Game.touch_move
	var yaw := rig.yaw if rig else 0.0
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := (right * input.x + forward * input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var speed := RUN
	if Input.is_action_pressed("walk"):
		speed = WALK
	elif Input.is_action_pressed("sprint") or sprint_touch:
		speed = SPRINT

	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, minf(1.0, ACCEL * delta))
	velocity.z = lerpf(velocity.z, target.z, minf(1.0, ACCEL * delta))

	if is_on_floor():
		if _fall_start - global_position.y > 6.0:
			var dmg := (_fall_start - global_position.y - 6.0) * 8.0
			Game.set_health(Game.health - dmg)
		_fall_start = global_position.y
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= _gravity * delta
		_fall_start = maxf(_fall_start, global_position.y)

	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if dir.length() > 0.1:
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, delta * 12.0))
	model.animate(delta, hspeed, is_on_floor())

	# упал под карту — вернуть
	if global_position.y < -20:
		global_position = Game.get_node("/root/Main").spawn_point()
		velocity = Vector3.ZERO


func enter_car(c: Car) -> void:
	car = c
	c.driver = self
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	collision_layer = 0
	collision_mask = 0
	rig.set_target(c, true)
	Game.msg("Вы сели в " + c.car_name + ". F — выйти, R — перевернуть.", Color(0.7, 0.85, 1.0))


func exit_car() -> void:
	if car == null:
		return
	var c := car
	c.driver = null
	car = null
	var exit_pos := c.global_transform * Vector3(1.8, 0.2, 0)
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_CAR
	global_position = exit_pos
	velocity = Vector3.ZERO
	visible = true
	model.rotation.y = c.global_rotation.y
	rig.set_target(self, false)
