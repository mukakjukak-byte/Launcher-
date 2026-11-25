class_name Humanoid
extends Node3D
## Персонаж из простых частей + процедурные анимации: стойка, ходьба, бег, прыжок.
## Лицо смотрит в +Z.

const SKINS := [
	{"shirt": Color(0.20, 0.30, 0.70), "pants": Color(0.15, 0.15, 0.20), "skin": Color(0.87, 0.70, 0.55), "hair": Color(0.20, 0.13, 0.08)},
	{"shirt": Color(0.10, 0.10, 0.10), "pants": Color(0.10, 0.10, 0.12), "skin": Color(0.85, 0.68, 0.52), "hair": Color(0.05, 0.05, 0.05)},
	{"shirt": Color(0.75, 0.15, 0.12), "pants": Color(0.25, 0.30, 0.45), "skin": Color(0.80, 0.62, 0.48), "hair": Color(0.45, 0.30, 0.15)},
	{"shirt": Color(0.15, 0.45, 0.20), "pants": Color(0.35, 0.30, 0.22), "skin": Color(0.90, 0.75, 0.62), "hair": Color(0.85, 0.75, 0.45)},
	{"shirt": Color(0.90, 0.90, 0.88), "pants": Color(0.20, 0.20, 0.25), "skin": Color(0.60, 0.42, 0.30), "hair": Color(0.08, 0.06, 0.05)},
	{"shirt": Color(0.20, 0.25, 0.20), "pants": Color(0.20, 0.25, 0.20), "skin": Color(0.86, 0.70, 0.56), "hair": Color(0.15, 0.12, 0.10)},
]

var hips: Node3D
var torso: Node3D
var head: Node3D
var l_leg: Node3D
var r_leg: Node3D
var l_knee: Node3D
var r_knee: Node3D
var l_arm: Node3D
var r_arm: Node3D

var _parts := {}  # имя материала -> Array[MeshInstance3D]
var _phase := 0.0


func _ready() -> void:
	_build()
	set_skin(Game.skin)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, part: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	if not _parts.has(part):
		_parts[part] = []
	_parts[part].append(mi)
	return mi


func _bx(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _build() -> void:
	hips = _pivot(self, Vector3(0, 0.92, 0))
	# ноги: бедро + голень (колено)
	l_leg = _pivot(hips, Vector3(0.11, 0, 0))
	r_leg = _pivot(hips, Vector3(-0.11, 0, 0))
	for leg in [l_leg, r_leg]:
		_mesh(leg, _bx(Vector3(0.17, 0.46, 0.19)), Vector3(0, -0.23, 0), "pants")
		var knee := _pivot(leg, Vector3(0, -0.46, 0))
		_mesh(knee, _bx(Vector3(0.15, 0.42, 0.17)), Vector3(0, -0.21, 0), "pants")
		_mesh(knee, _bx(Vector3(0.16, 0.08, 0.27)), Vector3(0, -0.42, 0.04), "shoes")
		if leg == l_leg:
			l_knee = knee
		else:
			r_knee = knee
	torso = _pivot(hips, Vector3(0, 0.02, 0))
	_mesh(torso, _bx(Vector3(0.44, 0.62, 0.24)), Vector3(0, 0.31, 0), "shirt")
	head = _pivot(torso, Vector3(0, 0.66, 0))
	_mesh(head, _bx(Vector3(0.1, 0.08, 0.1)), Vector3(0, 0.02, 0), "skin")  # шея
	_mesh(head, _bx(Vector3(0.24, 0.27, 0.25)), Vector3(0, 0.19, 0), "skin")
	_mesh(head, _bx(Vector3(0.26, 0.08, 0.27)), Vector3(0, 0.34, -0.01), "hair")
	_mesh(head, _bx(Vector3(0.05, 0.04, 0.02)), Vector3(0.06, 0.22, 0.13), "eyes")
	_mesh(head, _bx(Vector3(0.05, 0.04, 0.02)), Vector3(-0.06, 0.22, 0.13), "eyes")
	l_arm = _pivot(torso, Vector3(0.28, 0.58, 0))
	r_arm = _pivot(torso, Vector3(-0.28, 0.58, 0))
	for arm in [l_arm, r_arm]:
		_mesh(arm, _bx(Vector3(0.13, 0.34, 0.14)), Vector3(0, -0.15, 0), "shirt")
		_mesh(arm, _bx(Vector3(0.11, 0.3, 0.12)), Vector3(0, -0.46, 0), "skin")


func set_skin(index: int) -> void:
	var s: Dictionary = SKINS[clampi(index, 0, SKINS.size() - 1)]
	var colors := {
		"shirt": s.shirt, "pants": s.pants, "skin": s.skin, "hair": s.hair,
		"shoes": Color(0.08, 0.08, 0.08), "eyes": Color(0.05, 0.05, 0.08),
	}
	for part in _parts:
		var m := StandardMaterial3D.new()
		m.albedo_color = colors.get(part, Color.WHITE)
		m.roughness = 0.9
		for mi in _parts[part]:
			mi.material_override = m


## speed — горизонтальная скорость, grounded — на земле ли
func animate(delta: float, speed: float, grounded: bool) -> void:
	var k := minf(1.0, delta * 12.0)
	var leg_l := 0.0
	var leg_r := 0.0
	var knee_l := 0.0
	var knee_r := 0.0
	var arm_l := 0.0
	var arm_r := 0.0
	var lean := 0.0
	var bob := 0.0
	var spread := 0.06

	if not grounded:
		leg_l = -0.6
		leg_r = 0.25
		knee_l = 0.9
		knee_r = 0.3
		arm_l = -0.5
		arm_r = 0.4
		spread = 0.35
	elif speed > 0.3:
		var running := speed > 4.0
		_phase += delta * (5.0 + speed * 1.25)
		var amp := clampf(speed / 7.0, 0.3, 0.85)
		var s := sin(_phase)
		leg_l = s * amp
		leg_r = -s * amp
		# колено сгибается, когда нога идёт назад
		knee_l = maxf(0.0, -cos(_phase)) * amp * (1.6 if running else 0.9)
		knee_r = maxf(0.0, cos(_phase)) * amp * (1.6 if running else 0.9)
		arm_l = -s * amp * 0.9
		arm_r = s * amp * 0.9
		lean = 0.25 if running else 0.06
		bob = absf(sin(_phase)) * 0.05 * amp
	else:
		# дыхание
		_phase += delta * 2.0
		arm_l = sin(_phase) * 0.03
		arm_r = -sin(_phase) * 0.03
		bob = sin(_phase) * 0.006

	l_leg.rotation.x = lerpf(l_leg.rotation.x, -leg_l, k)
	r_leg.rotation.x = lerpf(r_leg.rotation.x, -leg_r, k)
	l_knee.rotation.x = lerpf(l_knee.rotation.x, knee_l, k)
	r_knee.rotation.x = lerpf(r_knee.rotation.x, knee_r, k)
	l_arm.rotation.x = lerpf(l_arm.rotation.x, -arm_l, k)
	r_arm.rotation.x = lerpf(r_arm.rotation.x, -arm_r, k)
	l_arm.rotation.z = lerpf(l_arm.rotation.z, spread, k)
	r_arm.rotation.z = lerpf(r_arm.rotation.z, -spread, k)
	torso.rotation.x = lerpf(torso.rotation.x, lean, k)
	hips.position.y = lerpf(hips.position.y, 0.92 + bob, k)
