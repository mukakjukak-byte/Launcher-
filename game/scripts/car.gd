class_name Car
extends VehicleBody3D
## Машина: газ/тормоз W/S, руль A/D, ручник Space, сигнал H, R — перевернуть.
## Перед машины смотрит в +Z.

const TYPES := {
	"sedan": {"name": "Седан", "len": 4.3, "w": 1.8, "body_h": 0.6, "cabin": Vector3(1.6, 0.55, 2.2), "cabin_z": -0.2, "engine": 3000.0, "max": 44.0, "mass": 1100.0},
	"hatch": {"name": "Хэтчбек", "len": 3.8, "w": 1.7, "body_h": 0.6, "cabin": Vector3(1.55, 0.6, 2.2), "cabin_z": -0.5, "engine": 2700.0, "max": 40.0, "mass": 950.0},
	"van": {"name": "Фургон", "len": 4.8, "w": 1.95, "body_h": 0.7, "cabin": Vector3(1.9, 1.2, 3.6), "cabin_z": -0.5, "engine": 2900.0, "max": 34.0, "mass": 1600.0},
	"sport": {"name": "Спорткар", "len": 4.4, "w": 1.9, "body_h": 0.45, "cabin": Vector3(1.5, 0.45, 1.8), "cabin_z": -0.4, "engine": 3600.0, "max": 60.0, "mass": 1200.0},
}
const COLORS := [Color(0.75, 0.1, 0.1), Color(0.1, 0.2, 0.55), Color(0.9, 0.9, 0.88),
	Color(0.08, 0.08, 0.08), Color(0.2, 0.45, 0.2), Color(0.6, 0.6, 0.62), Color(0.85, 0.6, 0.1)]

var car_type := "sedan"
var car_name := "Седан"
var color := Color.RED
var driver: Node3D = null
var max_speed := 44.0
var engine_power := 2600.0
var touch_brake := false

var _steer := 0.0
var _horn: AudioStreamPlayer3D
var _brake_mat: StandardMaterial3D


static func create(type: String, col = null) -> Car:
	var c := Car.new()
	c.car_type = type if TYPES.has(type) else "sedan"
	c.color = col if col != null else COLORS[randi() % COLORS.size()]
	return c


func _ready() -> void:
	var t: Dictionary = TYPES[car_type]
	car_name = t.name
	max_speed = t.max
	engine_power = t.engine
	mass = t.mass
	collision_layer = Game.LAYER_CAR
	collision_mask = Game.LAYER_WORLD | Game.LAYER_CAR | Game.LAYER_PLAYER
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0)
	can_sleep = true
	_build(t)


func _mat(c: Color, rough := 0.4, metal := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _part(sz: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.position = pos
	mi.material_override = m
	add_child(mi)


func _build(t: Dictionary) -> void:
	var L: float = t.len
	var W: float = t.w
	var H: float = t.body_h
	var body_y := 0.55
	var paint := _mat(color)
	var glass := _mat(Color(0.12, 0.16, 0.22), 0.1, 0.5)
	var dark := _mat(Color(0.06, 0.06, 0.06), 0.8, 0.0)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var cab: Vector3 = t.cabin
	shape.size = Vector3(W, H + cab.y, L)
	cs.shape = shape
	cs.position = Vector3(0, body_y + (H + cab.y) / 2.0 - H / 2.0, 0)
	add_child(cs)

	_part(Vector3(W, H, L), Vector3(0, body_y, 0), paint)
	_part(cab, Vector3(0, body_y + H / 2.0 + cab.y / 2.0, t.cabin_z), glass)
	_part(Vector3(cab.x + 0.02, 0.06, cab.z - 0.1), Vector3(0, body_y + H / 2.0 + cab.y, t.cabin_z), paint)
	# бамперы
	_part(Vector3(W + 0.04, 0.18, 0.15), Vector3(0, body_y - H / 2.0 + 0.1, L / 2.0), dark)
	_part(Vector3(W + 0.04, 0.18, 0.15), Vector3(0, body_y - H / 2.0 + 0.1, -L / 2.0), dark)
	# фары и стопы
	var head := _mat(Color(1, 1, 0.9), 0.2, 0.0)
	head.emission_enabled = true
	head.emission = Color(1, 0.95, 0.8)
	head.emission_energy_multiplier = 1.5
	_brake_mat = _mat(Color(0.5, 0.0, 0.0), 0.3, 0.0)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1, 0.05, 0.02)
	_brake_mat.emission_energy_multiplier = 0.3
	for s in [-1, 1]:
		_part(Vector3(0.35, 0.14, 0.04), Vector3(s * (W / 2.0 - 0.3), body_y + 0.08, L / 2.0 + 0.01), head)
		_part(Vector3(0.35, 0.12, 0.04), Vector3(s * (W / 2.0 - 0.3), body_y + 0.08, -L / 2.0 - 0.01), _brake_mat)
	# номер
	_part(Vector3(0.5, 0.12, 0.02), Vector3(0, body_y - 0.1, -L / 2.0 - 0.09), _mat(Color.WHITE, 0.5, 0.0))

	# колёса
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.36
	wheel_mesh.bottom_radius = 0.36
	wheel_mesh.height = 0.24
	wheel_mesh.radial_segments = 14
	var rim := _mat(Color(0.7, 0.7, 0.72), 0.3, 0.8)
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.2
	rim_mesh.bottom_radius = 0.2
	rim_mesh.height = 0.26
	rim_mesh.radial_segments = 10
	var wx := W / 2.0 - 0.15
	var wz := L / 2.0 - 0.75
	for p in [Vector3(wx, 0.4, wz), Vector3(-wx, 0.4, wz), Vector3(wx, 0.4, -wz), Vector3(-wx, 0.4, -wz)]:
		var w := VehicleWheel3D.new()
		w.position = p
		var front: bool = p.z > 0
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.15
		w.suspension_travel = 0.2
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 12000.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.2
		w.wheel_friction_slip = 2.6
		w.wheel_roll_influence = 0.15
		var mi := MeshInstance3D.new()
		mi.mesh = wheel_mesh
		mi.material_override = dark
		mi.rotation.z = PI / 2.0
		w.add_child(mi)
		var ri := MeshInstance3D.new()
		ri.mesh = rim_mesh
		ri.material_override = rim
		ri.rotation.z = PI / 2.0
		w.add_child(ri)
		add_child(w)

	_horn = AudioStreamPlayer3D.new()
	_horn.stream = _make_horn()
	add_child(_horn)


func _make_horn() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := (sin(TAU * 420.0 * t) + sin(TAU * 525.0 * t)) * 0.35
		v *= clampf(minf(t * 40.0, (0.5 - t) * 40.0), 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


## скорость вдоль направления машины, м/с (минус — назад)
func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func kmh() -> int:
	return int(absf(forward_speed()) * 3.6)


func _physics_process(delta: float) -> void:
	if driver == null:
		engine_force = 0.0
		brake = 2.0
		steering = 0.0
		_brake_mat.emission_energy_multiplier = 0.3
		return

	var throttle := Input.get_axis("move_back", "move_forward")
	var turn := Input.get_axis("move_left", "move_right")
	if Game.touch_move.length() > 0.05:
		throttle = clampf(Game.touch_move.y * 1.4, -1.0, 1.0)
		turn = clampf(Game.touch_move.x * 1.4, -1.0, 1.0)
	var handbrake := Input.is_action_pressed("jump") or touch_brake

	var v := forward_speed()
	# руль: на скорости поворачивает меньше
	var max_steer := lerpf(0.55, 0.18, clampf(absf(v) / max_speed, 0.0, 1.0))
	_steer = move_toward(_steer, -turn * max_steer, delta * 2.5)
	steering = _steer

	var braking := false
	if throttle > 0.0:
		if v < -1.0:
			engine_force = 0.0
			brake = 25.0
			braking = true
		else:
			engine_force = throttle * engine_power if v < max_speed else 0.0
			brake = 0.0
	elif throttle < 0.0:
		if v > 1.0:
			engine_force = 0.0
			brake = 25.0
			braking = true
		else:
			engine_force = throttle * engine_power * 0.6 if v > -10.0 else 0.0
			brake = 0.0
	else:
		engine_force = 0.0
		brake = 1.5

	if handbrake:
		brake = 40.0
		engine_force = 0.0
		braking = true
	_brake_mat.emission_energy_multiplier = 3.0 if braking else 0.3

	if Input.is_action_just_pressed("horn"):
		_horn.play()
	if Input.is_action_just_pressed("flip_car"):
		flip()


func flip() -> void:
	var y := global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, y), global_position + Vector3.UP * 1.5)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func is_flipped() -> bool:
	return global_basis.y.y < 0.3
