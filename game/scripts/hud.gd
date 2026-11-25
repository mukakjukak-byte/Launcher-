class_name Hud
extends CanvasLayer
## Худ в стиле SAMP: часы, деньги, здоровье/броня, чат, спидометр, радар, подсказки.

signal command_entered(text: String)

const CHAT_LINES := 10

var root: Control
var clock: Label
var money: Label
var hp_fill: ColorRect
var armor_fill: ColorRect
var chat_box: VBoxContainer
var chat_input: LineEdit
var speedo: Label
var hint: Label
var job_label: Label
var fps_label: Label
var radar: SubViewportContainer
var radar_cam: Camera3D
var radar_arrow: Polygon2D
var big_text: Label

var _lines: Array[Label] = []
var _big_timer := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- правый верхний угол: часы, HP, броня, деньги
	clock = _label(Game.clock_text(), 38, Color(0.95, 0.95, 0.95))
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.position = Vector2(-150, 12)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.size = Vector2(130, 44)
	root.add_child(clock)

	var bars := Control.new()
	bars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bars.position = Vector2(-180, 62)
	root.add_child(bars)
	armor_fill = _bar(bars, Vector2(0, 0), Color(0.85, 0.85, 0.85))
	hp_fill = _bar(bars, Vector2(0, 20), Color(0.70, 0.10, 0.10))

	money = _label("", 30, Color(0.22, 0.55, 0.22))
	money.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money.position = Vector2(-240, 100)
	money.size = Vector2(220, 40)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(money)

	# --- чат слева сверху
	chat_box = VBoxContainer.new()
	chat_box.position = Vector2(16, 12)
	chat_box.add_theme_constant_override("separation", 0)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chat_box)
	for i in CHAT_LINES:
		var l := _label("", 17, Color.WHITE, 3)
		l.custom_minimum_size = Vector2(700, 0)
		chat_box.add_child(l)
		_lines.append(l)

	chat_input = LineEdit.new()
	chat_input.position = Vector2(16, 12 + CHAT_LINES * 24 + 6)
	chat_input.size = Vector2(520, 34)
	chat_input.placeholder_text = "Сообщение или /команда (Enter — отправить, Esc — отмена)"
	chat_input.visible = false
	chat_input.max_length = 120
	chat_input.text_submitted.connect(_on_chat_submit)
	root.add_child(chat_input)

	# --- спидометр справа снизу
	speedo = _label("", 34, Color(0.95, 0.95, 0.95))
	speedo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speedo.position = Vector2(-300, -110)
	speedo.size = Vector2(280, 90)
	speedo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speedo.visible = false
	root.add_child(speedo)

	# --- подсказка снизу по центру
	hint = _label("", 20, Color(1, 1, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-300, -70)
	hint.size = Vector2(600, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	job_label = _label("", 20, Color(1.0, 0.85, 0.3))
	job_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	job_label.position = Vector2(-300, 14)
	job_label.size = Vector2(600, 30)
	job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(job_label)

	big_text = _label("", 44, Color(0.95, 0.8, 0.3), 6)
	big_text.set_anchors_preset(Control.PRESET_CENTER)
	big_text.position = Vector2(-400, -140)
	big_text.size = Vector2(800, 60)
	big_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(big_text)

	fps_label = _label("", 14, Color(0.7, 1, 0.7), 2)
	fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.position = Vector2(200, -24)
	fps_label.visible = false
	root.add_child(fps_label)

	_build_radar()

	Game.money_changed.connect(func(_v): _update_money())
	Game.health_changed.connect(func(_v): _update_bars())
	Game.chat_message.connect(add_chat)
	_update_money()
	_update_bars()


func _label(text: String, size: int, color: Color, outline := 5) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0, 0, 0)
	ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(parent: Control, pos: Vector2, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.position = pos
	bg.size = Vector2(160, 14)
	parent.add_child(bg)
	var back := ColorRect.new()
	back.color = color.darkened(0.6)
	back.position = Vector2(2, 2)
	back.size = Vector2(156, 10)
	bg.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(156, 10)
	bg.add_child(fill)
	return fill


func _build_radar() -> void:
	radar = SubViewportContainer.new()
	radar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	radar.position = Vector2(20, -200)
	radar.size = Vector2(170, 170)
	radar.stretch = true
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar)
	var vp := SubViewport.new()
	vp.size = Vector2i(170, 170)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	radar.add_child(vp)
	radar_cam = Camera3D.new()
	radar_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	radar_cam.size = 130.0
	radar_cam.far = 300.0
	radar_cam.rotation = Vector3(-PI / 2.0, 0, 0)
	vp.add_child(radar_cam)
	var frame := ReferenceRect.new()
	frame.border_color = Color(0, 0, 0)
	frame.border_width = 4
	frame.editor_only = false
	frame.size = Vector2(170, 170)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar.add_child(frame)
	radar_arrow = Polygon2D.new()
	radar_arrow.polygon = PackedVector2Array([Vector2(0, -9), Vector2(7, 7), Vector2(0, 3), Vector2(-7, 7)])
	radar_arrow.color = Color(1, 1, 1)
	radar_arrow.position = Vector2(85, 85)
	radar.add_child(radar_arrow)


func update_radar(pos: Vector3, cam_yaw: float, body_yaw: float) -> void:
	if not radar.visible:
		return
	radar_cam.global_position = pos + Vector3(0, 150, 0)
	radar_cam.rotation = Vector3(-PI / 2.0, cam_yaw, 0)
	# стрелка игрока: направление тела относительно камеры
	radar_arrow.rotation = -(body_yaw - cam_yaw) + PI


func _process(delta: float) -> void:
	clock.text = Game.clock_text()
	if fps_label.visible:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _big_timer > 0.0:
		_big_timer -= delta
		if _big_timer <= 0.0:
			big_text.text = ""


func show_big(text: String, seconds := 3.0) -> void:
	big_text.text = text
	_big_timer = seconds


func _update_money() -> void:
	money.text = "$%08d" % Game.money


func _update_bars() -> void:
	hp_fill.size.x = 156.0 * Game.health / 100.0
	armor_fill.get_parent().visible = Game.armor > 0.0
	armor_fill.size.x = 156.0 * Game.armor / 100.0


func add_chat(text: String, color: Color = Color.WHITE) -> void:
	for i in CHAT_LINES - 1:
		_lines[i].text = _lines[i + 1].text
		_lines[i].label_settings.font_color = _lines[i + 1].label_settings.font_color
	_lines[CHAT_LINES - 1].text = text
	_lines[CHAT_LINES - 1].label_settings.font_color = color


func open_chat(prefix := "") -> void:
	chat_input.visible = true
	chat_input.text = prefix
	chat_input.grab_focus()
	chat_input.caret_column = prefix.length()


func close_chat() -> void:
	chat_input.visible = false
	chat_input.release_focus()


func is_chat_open() -> bool:
	return chat_input.visible


func _on_chat_submit(text: String) -> void:
	close_chat()
	text = text.strip_edges()
	if text != "":
		command_entered.emit(text)


func set_speed(car: Car) -> void:
	if car == null:
		speedo.visible = false
		return
	speedo.visible = true
	speedo.text = "%s\n%d км/ч" % [car.car_name, car.kmh()]
