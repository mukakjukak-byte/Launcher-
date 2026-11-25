extends Node3D
## Главная сцена: собирает мир, игрока, машины, худ, работу и команды чата.

var city: City
var player: Player
var rig: CameraRig
var hud: Hud
var job: DeliveryJob
var touch: TouchControls
var cars: Array[Car] = []

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var pause_menu: Control
var _save_timer := 0.0


func _ready() -> void:
	_setup_environment()

	city = City.new()
	add_child(city)
	city.build()

	rig = CameraRig.new()
	add_child(rig)

	player = Player.new()
	player.rig = rig
	add_child(player)
	player.global_position = Game.saved_position if Game.saved_position != null else spawn_point()
	rig.set_target(player, false)
	rig.global_position = player.global_position

	var types := ["sedan", "hatch", "sedan", "sport", "hatch", "sedan", "van", "sedan", "hatch"]
	for i in city.parking.size():
		add_car(Car.create(types[i % types.size()]), city.parking[i])

	hud = Hud.new()
	add_child(hud)
	hud.command_entered.connect(_on_chat)

	job = DeliveryJob.new()
	add_child(job)
	job.setup(self, city)

	if Game.is_mobile:
		touch = TouchControls.new()
		touch.rig = rig
		touch.player = player
		add_child(touch)

	_build_pause_menu()

	Game.msg("Добро пожаловать, %s!" % Game.nick, Color(0.4, 0.8, 1.0))
	Game.msg("Это одиночный режим. /help — список команд.", Color(0.9, 0.9, 0.9))
	Game.msg("Работа доставщика — жёлтый маркер у СКЛАДА (/tp склад).", Color(1.0, 0.85, 0.3))
	if not Game.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func spawn_point() -> Vector3:
	return city.places["спавн"]


func add_car(c: Car, xform: Transform3D) -> void:
	add_child(c)
	c.global_transform = xform
	cars.append(c)


func remove_car(c: Car) -> void:
	cars.erase(c)
	c.queue_free()


# ---------------------------------------------------------------- окружение

func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.ambient_light_sky_contribution = 0.7
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = not Game.is_mobile
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)


func _update_daylight() -> void:
	var t := Game.game_minutes / 1440.0
	var elev := sin((t - 0.25) * TAU)  # 1 — полдень, -1 — полночь
	var day := clampf(elev * 3.0 + 0.3, 0.0, 1.0)
	sun.rotation = Vector3(-(t - 0.25) * TAU, deg_to_rad(-35), 0)
	sun.visible = elev > -0.05
	sun.light_energy = day * 0.95
	sun.light_color = Color(1.0, 0.75, 0.55).lerp(Color(1.0, 0.97, 0.92), clampf(elev * 2.0, 0.0, 1.0))
	var night_sky := Color(0.02, 0.03, 0.08)
	sky_mat.sky_top_color = night_sky.lerp(Color(0.25, 0.45, 0.8), day)
	sky_mat.sky_horizon_color = Color(0.05, 0.05, 0.1).lerp(Color(0.7, 0.75, 0.85), day)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.03).lerp(Color(0.3, 0.3, 0.3), day)
	env.ambient_light_energy = lerpf(0.12, 0.4, day)
	env.fog_light_color = sky_mat.sky_horizon_color
	city.set_night(1.0 - day)


# ---------------------------------------------------------------- игровой цикл

func _process(delta: float) -> void:
	_update_daylight()

	var near := _nearest_car()
	if player.car:
		hud.hint.text = ""
	elif near:
		hud.hint.text = "Нажми F, чтобы сесть в " + near.car_name
	else:
		hud.hint.text = ""

	hud.set_speed(player.car)
	var focus: Node3D = player.car if player.car else player
	var body_yaw: float = player.car.global_rotation.y if player.car else player.model.rotation.y
	hud.update_radar(focus.global_position, rig.yaw, body_yaw)

	if Game.health <= 0.0:
		_die()

	_save_timer += delta
	if _save_timer > 30.0:
		_save_timer = 0.0
		Game.save_game(player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_chat_open():
		if event.is_action_pressed("pause"):
			hud.close_chat()
			_capture()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if get_tree().paused:
		return

	if event.is_action_pressed("chat"):
		_open_chat("")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("command"):
		_open_chat("/")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("enter_car"):
		if player.car:
			player.exit_car()
		else:
			var c := _nearest_car()
			if c:
				player.enter_car(c)
	elif event is InputEventMouseButton and event.pressed and not Game.is_mobile:
		_capture()


func _open_chat(prefix: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.open_chat(prefix)


func _capture() -> void:
	if not Game.is_mobile and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _nearest_car() -> Car:
	if player.car:
		return null
	var best: Car = null
	var best_d := 3.5
	for c in cars:
		var d := c.global_position.distance_to(player.global_position)
		if d < best_d and c.driver == null:
			best = c
			best_d = d
	return best


func _die() -> void:
	if player.car:
		player.exit_car()
	Game.msg("Вы потеряли сознание и очнулись в больнице. Лечение: -$100", Color(1, 0.4, 0.4))
	Game.add_money(-100)
	Game.set_health(100.0)
	player.global_position = spawn_point()
	player.velocity = Vector3.ZERO


# ---------------------------------------------------------------- чат и команды

func _on_chat(text: String) -> void:
	_capture()
	if text.begins_with("/"):
		_command(text.substr(1))
	else:
		Game.msg("%s: %s" % [Game.nick, text], Color(1, 1, 1))


func _command(line: String) -> void:
	var parts := line.split(" ", false)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	var arg := " ".join(parts.slice(1)) if parts.size() > 1 else ""
	var yellow := Color(1.0, 0.85, 0.3)
	var grey := Color(0.8, 0.8, 0.8)
	match cmd:
		"help", "помощь":
			Game.msg("Команды: /car [sedan|hatch|van|sport]  /tp [место]  /time [час]", yellow)
			Game.msg("/skin [0-5]  /heal  /job  /quitjob  /stats  /fix  /radar  /fps  /save", yellow)
			Game.msg("Управление: WASD, Shift — бег, Alt — шаг, Space — прыжок/ручник, F — машина, T — чат", grey)
		"car", "veh":
			var type := arg if Car.TYPES.has(arg) else "sedan"
			var base: Node3D = player.car if player.car else player
			var pos := base.global_position + Vector3(-sin(rig.yaw), 0, -cos(rig.yaw)) * 6.0 + Vector3.UP * 1.0
			var c := Car.create(type)
			add_car(c, Transform3D(Basis(Vector3.UP, rig.yaw + PI), pos))
			Game.msg("Создан транспорт: " + c.car_name, grey)
		"tp":
			if city.places.has(arg):
				if player.car:
					player.exit_car()
				player.global_position = city.places[arg]
				player.velocity = Vector3.ZERO
				Game.msg("Телепорт: " + arg, grey)
			else:
				Game.msg("Места: " + ", ".join(city.places.keys()), grey)
		"time":
			if arg.is_valid_int():
				Game.game_minutes = clampi(int(arg), 0, 23) * 60.0
				Game.msg("Время установлено: " + Game.clock_text(), grey)
			else:
				Game.msg("Использование: /time [0-23]", grey)
		"skin":
			if arg.is_valid_int():
				Game.skin = clampi(int(arg), 0, Humanoid.SKINS.size() - 1)
				player.model.set_skin(Game.skin)
				Game.msg("Скин изменён на %d" % Game.skin, grey)
			else:
				Game.msg("Использование: /skin [0-%d]" % (Humanoid.SKINS.size() - 1), grey)
		"heal":
			if Game.health >= 100.0:
				Game.msg("Вы и так здоровы.", grey)
			elif Game.money < 50:
				Game.msg("Лечение стоит $50.", Color(1, 0.4, 0.4))
			else:
				Game.add_money(-50)
				Game.set_health(100.0)
				Game.msg("Вы вылечились за $50.", Color(0.4, 1, 0.4))
		"job":
			job.start()
		"quitjob":
			job.stop()
		"stats":
			Game.msg("Ник: %s | Деньги: $%d | Здоровье: %d | Скин: %d" % [Game.nick, Game.money, int(Game.health), Game.skin], yellow)
		"fix", "flip":
			if player.car:
				player.car.flip()
				Game.msg("Машина поставлена на колёса.", grey)
			else:
				Game.msg("Вы не в машине.", grey)
		"radar":
			hud.radar.visible = not hud.radar.visible
		"fps":
			hud.fps_label.visible = not hud.fps_label.visible
		"save":
			Game.save_game(player.global_position)
			Game.msg("Игра сохранена.", Color(0.4, 1, 0.4))
		_:
			Game.msg("Неизвестная команда. /help — список команд.", Color(1, 0.4, 0.4))


# ---------------------------------------------------------------- пауза

func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	pause_menu = ColorRect.new()
	(pause_menu as ColorRect).color = Color(0, 0, 0, 0.6)
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	layer.add_child(pause_menu)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-160, -130)
	box.custom_minimum_size = Vector2(320, 260)
	box.add_theme_constant_override("separation", 14)
	pause_menu.add_child(box)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	for item in [["Продолжить", _toggle_pause], ["Сохранить", func(): Game.save_game(player.global_position); Game.msg("Игра сохранена.", Color(0.4, 1, 0.4))], ["Выйти", _quit]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(320, 56)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(item[1])
		box.add_child(b)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_menu.visible = p
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture()


func _quit() -> void:
	Game.save_game(player.global_position)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if player:
			Game.save_game(player.global_position)
