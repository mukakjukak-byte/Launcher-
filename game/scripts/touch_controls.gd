class_name TouchControls
extends CanvasLayer
## Управление с телефона: джойстик слева, обзор свайпом справа, кнопки действий.

var rig: CameraRig
var player: Player

var _joy_center := Vector2.ZERO
var _joy_index := -1
var _look_index := -1
var _base: Control
var _knob: Control
const RADIUS := 90.0


func _ready() -> void:
	layer = 10
	_base = _circle(RADIUS * 2.0, Color(1, 1, 1, 0.15))
	_knob = _circle(70.0, Color(1, 1, 1, 0.35))
	add_child(_base)
	add_child(_knob)
	_layout()
	get_viewport().size_changed.connect(_layout)

	var vs := get_viewport().get_visible_rect().size
	_button("F", "enter_car", Vector2(-120, -330))
	_button("Прыжок\nТормоз", "jump", Vector2(-120, -210))
	_button("Бег", "sprint", Vector2(-240, -150))
	_button("Сигнал", "horn", Vector2(-240, -270))
	_button("Чат", "chat", Vector2(-120, -450))
	_button("II", "pause", Vector2(-90, 0), true)


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_joy_center = Vector2(170, vs.y - 170)
	_base.position = _joy_center - Vector2(RADIUS, RADIUS)
	_knob.position = _joy_center - Vector2(35, 35)


func _circle(d: float, color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(d / 2.0))
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _circle_texture(d: int) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for x in d:
		for y in d:
			var dist := Vector2(x - r, y - r).length()
			var a := 0.0
			if dist < r - 2:
				a = 0.28
			elif dist < r:
				a = 0.6
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _button(text: String, action: String, offset: Vector2, top := false) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle_texture(100)
	b.action = action
	b.passby_press = false
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT if top else Control.PRESET_BOTTOM_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.position = offset + Vector2(-50, 20 if top else -50)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.add_child(anchor)
	anchor.add_child(b)
	var l := Label.new()
	l.text = text
	l.size = Vector2(100, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(l)


func _input(event: InputEvent) -> void:
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(_joy_center) < RADIUS * 1.6 and _joy_index == -1:
				_joy_index = event.index
				_update_joy(event.position)
			elif event.position.x > vs.x * 0.35 and event.position.y < vs.y * 0.6 and _look_index == -1:
				_look_index = event.index
		else:
			if event.index == _joy_index:
				_joy_index = -1
				Game.touch_move = Vector2.ZERO
				_knob.position = _joy_center - Vector2(35, 35)
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_index:
			_update_joy(event.position)
		elif event.index == _look_index and rig:
			rig.look(event.relative * 1.4)


func _update_joy(pos: Vector2) -> void:
	var d := (pos - _joy_center).limit_length(RADIUS)
	_knob.position = _joy_center + d - Vector2(35, 35)
	Game.touch_move = Vector2(d.x, -d.y) / RADIUS


func _process(_delta: float) -> void:
	if player:
		player.sprint_touch = Input.is_action_pressed("sprint")
		if player.car:
			player.car.touch_brake = Input.is_action_pressed("jump")
