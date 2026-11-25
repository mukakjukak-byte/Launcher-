class_name CameraRig
extends Node3D
## Камера от третьего лица (как в SAMP): мышь/свайп вращают, за машиной камера сама встаёт сзади.

var target: Node3D
var yaw := 0.0
var pitch := -0.25
var in_car := false
var sensitivity := 0.003
var spring: SpringArm3D
var camera: Camera3D
var _idle := 0.0


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.spring_length = 4.2
	spring.margin = 0.2
	spring.collision_mask = Game.LAYER_WORLD
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	spring.shape = sphere
	add_child(spring)
	camera = Camera3D.new()
	camera.far = 700.0
	camera.fov = 70.0
	spring.add_child(camera)
	camera.current = true


func set_target(t: Node3D, car_mode: bool) -> void:
	target = t
	in_car = car_mode
	spring.spring_length = 7.5 if car_mode else 4.2


func look(rel: Vector2) -> void:
	yaw -= rel.x * sensitivity
	pitch = clampf(pitch - rel.y * sensitivity, -1.2, 0.45)
	_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)


func _process(delta: float) -> void:
	if target == null:
		return
	var h := 1.9 if in_car else 1.6
	global_position = global_position.lerp(target.global_position + Vector3.UP * h, minf(1.0, delta * 14.0))
	if in_car:
		_idle += delta
		var car_speed := (target as RigidBody3D).linear_velocity.length() if target is RigidBody3D else 0.0
		if _idle > 1.2 and car_speed > 2.0:
			yaw = lerp_angle(yaw, target.global_rotation.y + PI, minf(1.0, delta * 2.5))
			pitch = lerpf(pitch, -0.22, minf(1.0, delta * 2.0))
	rotation = Vector3(pitch, yaw, 0)
