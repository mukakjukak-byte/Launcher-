class_name Checkpoint
extends Area3D
## Красный чекпоинт как в SAMP.

signal reached(body: Node3D)

var radius := 3.0
var color := Color(0.9, 0.05, 0.05, 0.45)


static func create(pos: Vector3, r := 3.0, col := Color(0.9, 0.05, 0.05, 0.45)) -> Checkpoint:
	var c := Checkpoint.new()
	c.radius = r
	c.color = col
	c.position = pos
	return c


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.LAYER_PLAYER | Game.LAYER_CAR
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	cs.shape = shape
	cs.position.y = 2.0
	add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 1.2
	cm.radial_segments = 24
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position.y = 0.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# метка на радаре: большой диск сверху
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 5.0
	dm.bottom_radius = 5.0
	dm.height = 0.1
	disc.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(color.r, color.g, color.b, 1.0)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dmat
	disc.position.y = 60.0
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	body_entered.connect(func(b): reached.emit(b))


func _process(delta: float) -> void:
	rotation.y += delta * 0.8
