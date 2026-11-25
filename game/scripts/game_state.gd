extends Node
## Глобальное состояние игры (автозагрузка "Game"): деньги, здоровье, время, чат, сохранение.

signal money_changed(value: int)
signal health_changed(value: float)
signal chat_message(text: String, color: Color)

const SAVE_PATH := "user://save.json"

# Слои физики
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_CAR := 4

var nick := "Ivan_Ivanov"
var money := 500
var health := 100.0
var armor := 0.0
var skin := 0
## Время суток в игровых минутах (0..1440). 1 реальная секунда = 1 игровая минута.
var game_minutes := 12.0 * 60.0
var time_scale := 1.0

## Управление с телефона: x — вправо, y — вперёд
var touch_move := Vector2.ZERO
var is_mobile := false

var saved_position = null


func _ready() -> void:
	is_mobile = OS.has_feature("mobile")
	_setup_input()
	load_game()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nick="):
			nick = arg.substr(7)


func _process(delta: float) -> void:
	game_minutes = fmod(game_minutes + delta * time_scale, 1440.0)


func clock_text() -> String:
	var m := int(game_minutes)
	return "%02d:%02d" % [m / 60, m % 60]


func add_money(amount: int) -> void:
	money = max(money + amount, 0)
	money_changed.emit(money)
	save_game()


func set_health(value: float) -> void:
	health = clampf(value, 0.0, 100.0)
	health_changed.emit(health)


func msg(text: String, color: Color = Color.WHITE) -> void:
	chat_message.emit(text, color)


func save_game(player_pos = null) -> void:
	var data := {
		"nick": nick, "money": money, "health": health, "skin": skin,
		"minutes": game_minutes,
	}
	if player_pos != null:
		data["pos"] = [player_pos.x, player_pos.y, player_pos.z]
	elif saved_position != null:
		data["pos"] = [saved_position.x, saved_position.y, saved_position.z]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	nick = str(data.get("nick", nick))
	money = int(data.get("money", money))
	health = float(data.get("health", health))
	skin = int(data.get("skin", skin))
	game_minutes = float(data.get("minutes", game_minutes))
	var p = data.get("pos")
	if typeof(p) == TYPE_ARRAY and p.size() == 3:
		saved_position = Vector3(p[0], p[1], p[2])


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"walk": [KEY_ALT],
		"enter_car": [KEY_F],
		"horn": [KEY_H],
		"flip_car": [KEY_R],
		"chat": [KEY_T, KEY_F6],
		"command": [KEY_SLASH],
		"pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
