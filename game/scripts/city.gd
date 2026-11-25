class_name City
extends Node3D
## Процедурный город в духе CRMP: панельки, дороги, тротуары, АЗС, мэрия, парк, склад.

const BLOCKS := 6
const BLOCK := 44.0
const ROAD := 12.0
const CELL := BLOCK + ROAD

var size := 0.0
var half := 0.0
var rng := RandomNumberGenerator.new()

## Точки на дорогах (для чекпоинтов работы)
var road_points: Array[Vector3] = []
## Именованные места для /tp
var places := {}
## Места для машин
var parking: Array[Transform3D] = []

var _mats := {}
var _window_mats: Array[StandardMaterial3D] = []
var _lamp_mat: StandardMaterial3D
var _box_meshes := {}


func build() -> void:
	rng.seed = 20261125
	size = BLOCKS * CELL + ROAD
	half = size / 2.0
	_make_materials()
	_ground()
	_roads()
	for bx in BLOCKS:
		for bz in BLOCKS:
			_block(bx, bz)
	_lamps()
	_collect_points()


## Ночью окна и фонари светятся
func set_night(amount: float) -> void:
	for m in _window_mats:
		m.emission_energy_multiplier = amount * 1.6
	_lamp_mat.emission_energy_multiplier = amount * 4.0


# ---------------------------------------------------------------- материалы

func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _make_materials() -> void:
	_mats.grass = _mat(Color(0.22, 0.36, 0.16))
	_mats.asphalt = _mat(Color(0.16, 0.16, 0.17))
	_mats.line = _mat(Color(0.9, 0.9, 0.85))
	_mats.sidewalk = _mat(Color(0.36, 0.36, 0.35))
	_mats.yard = _mat(Color(0.30, 0.29, 0.26))
	_mats.roof = _mat(Color(0.22, 0.22, 0.24))
	_mats.trunk = _mat(Color(0.35, 0.24, 0.15))
	_mats.leaves = _mat(Color(0.20, 0.42, 0.18))
	_mats.pole = _mat(Color(0.25, 0.27, 0.3), 0.5)
	_mats.fence = _mat(Color(0.3, 0.35, 0.3))
	_mats.water = _mat(Color(0.25, 0.45, 0.65), 0.1)
	_mats.red = _mat(Color(0.75, 0.12, 0.1))
	_mats.white = _mat(Color(0.92, 0.92, 0.9))
	_mats.yellow = _mat(Color(0.95, 0.75, 0.1))
	_mats.metal = _mat(Color(0.5, 0.52, 0.55), 0.4)
	_mats.brick = _mat(Color(0.55, 0.28, 0.2))
	_mats.wood = _mat(Color(0.45, 0.32, 0.2))
	_lamp_mat = _mat(Color(1.0, 0.92, 0.7), 0.3)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.85, 0.55)
	_lamp_mat.emission_energy_multiplier = 0.0

	# Панельки разных цветов (как в российских городах)
	var walls := [Color(0.82, 0.80, 0.74), Color(0.78, 0.74, 0.64), Color(0.70, 0.72, 0.74),
		Color(0.84, 0.76, 0.66), Color(0.72, 0.66, 0.60), Color(0.80, 0.82, 0.84)]
	for c in walls:
		_window_mats.append(_window_material(c))


func _window_material(wall: Color) -> StandardMaterial3D:
	# Текстура 4x4 окна на 12x12 м (этаж 3 м), часть окон горит ночью
	var px := 16
	var n := 4
	var img := Image.create(px * n, px * n, false, Image.FORMAT_RGB8)
	var glow := Image.create(px * n, px * n, false, Image.FORMAT_RGB8)
	img.fill(wall)
	glow.fill(Color.BLACK)
	var seam := wall.darkened(0.12)
	for i in px * n:
		for j in [0, px, px * 2, px * 3]:
			img.set_pixel(i, j, seam)
			img.set_pixel(j, i, seam)
	for wx in n:
		for wy in n:
			var x0 := wx * px + 4
			var y0 := wy * px + 4
			var lit := rng.randf() < 0.35
			var glass := Color(0.20, 0.26, 0.32)
			for x in range(x0, x0 + 8):
				for y in range(y0, y0 + 9):
					img.set_pixel(x, y, glass)
					if lit:
						glow.set_pixel(x, y, Color(1.0, 0.82, 0.5))
			# подоконник
			for x in range(x0 - 1, x0 + 9):
				img.set_pixel(x, y0 + 9, wall.lightened(0.15))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.85
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 12.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(glow)
	m.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	m.emission = Color.BLACK  # светятся только горящие окна из текстуры
	m.emission_energy_multiplier = 0.0
	return m


# ---------------------------------------------------------------- примитивы

func _box_mesh(sz: Vector3) -> BoxMesh:
	var key := "%.2f_%.2f_%.2f" % [sz.x, sz.y, sz.z]
	if not _box_meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = sz
		_box_meshes[key] = bm
	return _box_meshes[key]


## Коробка: center — центр, sz — размер. collide — добавить коллизию.
func box(center: Vector3, sz: Vector3, mat: Material, collide := true, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(sz)
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Game.LAYER_WORLD
		body.collision_mask = 0
		body.position = center
		body.rotation.y = rot_y
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sz
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		add_child(body)
	else:
		mi.position = center
		mi.rotation.y = rot_y
		add_child(mi)
	return mi


func cylinder(center: Vector3, radius: float, height: float, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Game.LAYER_WORLD
		body.collision_mask = 0
		body.position = center
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		add_child(body)
	else:
		mi.position = center
		add_child(mi)


func tree(pos: Vector3) -> void:
	var h := rng.randf_range(2.0, 3.2)
	cylinder(pos + Vector3(0, h / 2.0, 0), 0.18, h, _mats.trunk)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := rng.randf_range(1.4, 2.2)
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mats.leaves
	mi.position = pos + Vector3(0, h + r * 0.6, 0)
	add_child(mi)


# ---------------------------------------------------------------- город

func _to_world(x: float, z: float) -> Vector3:
	return Vector3(x - half, 0, z - half)


func _ground() -> void:
	box(Vector3(0, -0.5, 0), Vector3(size + 600, 1, size + 600), _mats.grass)
	# невидимые стены по краям, чтобы не уехать в пустоту
	var e := size / 2.0 + 120
	for s in [-1, 1]:
		var wall := box(Vector3(e * s, 10, 0), Vector3(2, 20, e * 2), _mats.grass)
		wall.visible = false
		wall = box(Vector3(0, 10, e * s), Vector3(e * 2, 20, 2), _mats.grass)
		wall.visible = false


func _roads() -> void:
	for i in BLOCKS + 1:
		var c := i * CELL + ROAD / 2.0
		# дорога вдоль X и вдоль Z
		box(_to_world(size / 2.0, c) + Vector3(0, 0.02, 0), Vector3(size, 0.04, ROAD), _mats.asphalt, false)
		box(_to_world(c, size / 2.0) + Vector3(0, 0.021, 0), Vector3(ROAD, 0.04, size), _mats.asphalt, false)
		# прерывистая разметка между перекрёстками
		for b in BLOCKS:
			var start := b * CELL + ROAD + 2.0
			var t := 0.0
			while t < BLOCK - 4.0:
				box(_to_world(start + t + 1.5, c) + Vector3(0, 0.05, 0), Vector3(3, 0.01, 0.18), _mats.line, false)
				box(_to_world(c, start + t + 1.5) + Vector3(0, 0.05, 0), Vector3(0.18, 0.01, 3), _mats.line, false)
				t += 6.0


func _block(bx: int, bz: int) -> void:
	var x0 := bx * CELL + ROAD
	var z0 := bz * CELL + ROAD
	var center := _to_world(x0 + BLOCK / 2.0, z0 + BLOCK / 2.0)
	# тротуар с бордюром
	box(center + Vector3(0, 0.06, 0), Vector3(BLOCK, 0.12, BLOCK), _mats.sidewalk)

	var key := Vector2i(bx, bz)
	match key:
		Vector2i(2, 2):
			_city_hall(center)
		Vector2i(3, 2):
			_park(center)
		Vector2i(4, 1):
			_gas_station(center)
		Vector2i(1, 4):
			_warehouse(center)
		Vector2i(3, 3):
			_shop(center)
		Vector2i(2, 3):
			_square(center)
		_:
			var edge := bx == 0 or bz == 0 or bx == BLOCKS - 1 or bz == BLOCKS - 1
			if edge and rng.randf() < 0.55:
				_private_houses(center)
			elif rng.randf() < 0.5:
				_khrushchevki(center)
			else:
				_towers(center)


func _yard(center: Vector3, mat: Material = null) -> void:
	box(center + Vector3(0, 0.125, 0), Vector3(BLOCK - 6, 0.01, BLOCK - 6), mat if mat else _mats.yard, false)


func _building(center: Vector3, w: float, d: float, floors: int, rot_y := 0.0) -> void:
	var h := floors * 3.0
	var wm: StandardMaterial3D = _window_mats[rng.randi() % _window_mats.size()]
	box(center + Vector3(0, h / 2.0 + 0.12, 0), Vector3(w, h, d), wm, true, rot_y)
	box(center + Vector3(0, h + 0.3, 0), Vector3(w + 0.4, 0.4, d + 0.4), _mats.roof, false, rot_y)
	# подъезды-козырьки
	var entries := int(w / 12.0)
	for i in entries:
		var off := -w / 2.0 + 6.0 + i * 12.0
		var local := Vector3(off, 2.6, d / 2.0 + 0.6)
		box(center + local.rotated(Vector3.UP, rot_y), Vector3(2.4, 0.15, 1.2), _mats.roof, false, rot_y)


func _khrushchevki(center: Vector3) -> void:
	_yard(center)
	_building(center + Vector3(0, 0, -10), 36, 11, 5)
	_building(center + Vector3(0, 0, 10), 36, 11, 5)
	# детская площадка и деревья во дворе
	box(center + Vector3(-12, 0.6, 0), Vector3(3, 1.2, 0.2), _mats.red)
	box(center + Vector3(12, 0.3, 0), Vector3(4, 0.6, 4), _mats.yellow)
	tree(center + Vector3(-4, 0.12, 0))
	tree(center + Vector3(5, 0.12, 1))


func _towers(center: Vector3) -> void:
	_yard(center)
	var floors := 9 if rng.randf() < 0.6 else 12
	_building(center + Vector3(-9, 0, -9), 14, 14, floors)
	_building(center + Vector3(9, 0, 9), 14, 14, floors)
	tree(center + Vector3(10, 0.12, -10))
	tree(center + Vector3(-10, 0.12, 10))


func _private_houses(center: Vector3) -> void:
	_yard(center, _mats.grass)
	for ix in 2:
		for iz in 2:
			var p := center + Vector3(-10 + ix * 20, 0, -10 + iz * 20)
			var wall_m: StandardMaterial3D = [_mats.brick, _mats.wood, _mats.white][rng.randi() % 3]
			box(p + Vector3(0, 1.6, 0), Vector3(7, 3, 6), wall_m)
			var roof := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(7.6, 2.2, 6.6)
			roof.mesh = pm
			roof.material_override = _mats.roof
			roof.position = p + Vector3(0, 4.2, 0)
			add_child(roof)
			# забор
			box(p + Vector3(0, 0.7, 4.8), Vector3(9, 1.2, 0.1), _mats.fence)
			tree(p + Vector3(3.5, 0.12, -4))


func _city_hall(center: Vector3) -> void:
	_yard(center, _mats.sidewalk)
	box(center + Vector3(0, 6.1, -6), Vector3(30, 12, 14), _mats.white)
	box(center + Vector3(0, 12.4, -6), Vector3(31, 0.6, 15), _mats.roof)
	for i in 6:
		cylinder(center + Vector3(-10 + i * 4, 4, 2), 0.5, 8, _mats.white)
	box(center + Vector3(0, 8.3, 2.5), Vector3(26, 0.6, 2), _mats.white, false)
	# флаг
	cylinder(center + Vector3(0, 17, -6), 0.08, 9, _mats.pole)
	box(center + Vector3(1.2, 20.5, -6), Vector3(2.4, 0.5, 0.05), _mats.white, false)
	box(center + Vector3(1.2, 20.0, -6), Vector3(2.4, 0.5, 0.05), _mats.water, false)
	box(center + Vector3(1.2, 19.5, -6), Vector3(2.4, 0.5, 0.05), _mats.red, false)
	_label3d("МЭРИЯ", center + Vector3(0, 10, 1.05))
	places["мэрия"] = center + Vector3(0, 1, 14)


func _park(center: Vector3) -> void:
	_yard(center, _mats.grass)
	cylinder(center + Vector3(0, 0.4, 0), 4.0, 0.8, _mats.sidewalk)
	cylinder(center + Vector3(0, 0.85, 0), 3.4, 0.1, _mats.water, false)
	cylinder(center + Vector3(0, 1.6, 0), 0.4, 1.6, _mats.sidewalk)
	for i in 14:
		var a := i * TAU / 14.0
		tree(center + Vector3(cos(a) * 15, 0.12, sin(a) * 15))
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		box(center + Vector3(cos(a) * 8, 0.45, sin(a) * 8), Vector3(2, 0.15, 0.6), _mats.wood, true, -a)
	places["парк"] = center + Vector3(0, 1, 8)


func _gas_station(center: Vector3) -> void:
	_yard(center, _mats.asphalt)
	box(center + Vector3(0, 5.2, 4), Vector3(20, 0.5, 12), _mats.white, false)
	box(center + Vector3(0, 5.0, 4), Vector3(20.2, 0.3, 12.2), _mats.red, false)
	for x in [-8, 8]:
		for z in [0, 8]:
			box(center + Vector3(x, 2.5, z), Vector3(0.5, 5, 0.5), _mats.white)
	for x in [-4, 4]:
		box(center + Vector3(x, 0.8, 4), Vector3(1, 1.6, 0.6), _mats.red)
	box(center + Vector3(0, 2, -12), Vector3(14, 4, 8), _mats.white)
	_label3d("АЗС", center + Vector3(0, 6.2, 10.2))
	places["азс"] = center + Vector3(0, 1, 16)


func _warehouse(center: Vector3) -> void:
	_yard(center, _mats.asphalt)
	box(center + Vector3(-6, 4, -8), Vector3(26, 8, 18), _mats.metal)
	box(center + Vector3(-6, 8.3, -8), Vector3(27, 0.6, 19), _mats.roof)
	box(center + Vector3(-6, 2.5, 1.05), Vector3(8, 5, 0.1), _mats.yellow, false)
	for i in 3:
		box(center + Vector3(10, 0.7 + i * 1.4, -12 + i), Vector3(2.4, 1.4, 2.4), _mats.wood)
	_label3d("СКЛАД", center + Vector3(-6, 6.5, 1.1))
	places["склад"] = center + Vector3(4, 0.12, 8)


func _shop(center: Vector3) -> void:
	_yard(center)
	box(center + Vector3(0, 2.6, -8), Vector3(22, 5, 12), _mats.brick)
	box(center + Vector3(0, 5.3, -8), Vector3(23, 0.4, 13), _mats.roof)
	box(center + Vector3(0, 1.5, -1.95), Vector3(10, 2.6, 0.1), _mats.water, false)
	_label3d("МАГАЗИН 24/7", center + Vector3(0, 4.2, -1.9))
	_khrushchevki_half(center)
	places["магазин"] = center + Vector3(0, 1, 6)


func _khrushchevki_half(center: Vector3) -> void:
	_building(center + Vector3(0, 0, 14), 36, 10, 5)


func _square(center: Vector3) -> void:
	_yard(center, _mats.sidewalk)
	box(center + Vector3(0, 0.6, 0), Vector3(3, 1.2, 3), _mats.sidewalk)
	box(center + Vector3(0, 3.2, 0), Vector3(1.2, 4, 1.2), _mats.metal)
	for i in 8:
		var a := i * TAU / 8.0
		tree(center + Vector3(cos(a) * 16, 0.12, sin(a) * 16))
	places["площадь"] = center + Vector3(0, 1, 8)


func _label3d(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 140
	l.outline_size = 24
	l.pixel_size = 0.01
	l.modulate = Color(0.95, 0.95, 0.95)
	l.outline_modulate = Color(0.1, 0.1, 0.15)
	l.position = pos
	add_child(l)


func _lamps() -> void:
	var step := 28.0
	for i in BLOCKS + 1:
		var c := i * CELL + ROAD / 2.0
		var t := ROAD + 6.0
		while t < size - ROAD:
			for side in [-1, 1]:
				_lamp(_to_world(t, c + side * (ROAD / 2.0 + 1.0)), side)
			t += step
	for i in BLOCKS + 1:
		var c := i * CELL + ROAD / 2.0
		var t := ROAD + 20.0
		while t < size - ROAD:
			for side in [-1, 1]:
				_lamp(_to_world(c + side * (ROAD / 2.0 + 1.0), t), side)
			t += step


func _lamp(base: Vector3, _side: int) -> void:
	box(base + Vector3(0, 2.6, 0), Vector3(0.14, 5.0, 0.14), _mats.pole, false)
	box(base + Vector3(0, 5.15, 0), Vector3(0.5, 0.2, 0.5), _lamp_mat, false)


func _collect_points() -> void:
	# середины участков дорог — правая полоса
	for i in BLOCKS + 1:
		var c := i * CELL + ROAD / 2.0
		for b in BLOCKS:
			var m := b * CELL + ROAD + BLOCK / 2.0
			road_points.append(_to_world(m, c + 3.0) + Vector3(0, 0.1, 0))
			road_points.append(_to_world(c - 3.0, m) + Vector3(0, 0.1, 0))
	# парковка у обочины в центре
	var spawn_road := 3 * CELL + ROAD / 2.0
	places["спавн"] = _to_world(2 * CELL + ROAD + 10, spawn_road - ROAD / 2.0 - 2.0) + Vector3(0, 1, 0)
	for k in 5:
		var p := _to_world(2 * CELL + ROAD + 6 + k * 7.0, spawn_road - 4.0) + Vector3(0, 0.8, 0)
		parking.append(Transform3D(Basis(Vector3.UP, PI / 2.0), p))
	for k in 4:
		var p := _to_world(3 * CELL + ROAD / 2.0 + 4.0, 1 * CELL + ROAD + 8 + k * 8.0) + Vector3(0, 0.8, 0)
		parking.append(Transform3D(Basis.IDENTITY, p))
