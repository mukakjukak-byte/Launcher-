extends SceneTree
## Скриншоты: xvfb-run godot --path game -s res://tests/shots.gd
var main
var frame := 0
var out := OS.get_environment("SHOTS_DIR")

func _initialize() -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f: f.store_string("{}")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("[SHOT] ", name)

func _process(_d: float) -> bool:
	frame += 1
	var pl = main.player
	match frame:
		5:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			main.rig.yaw = 0.6
			main.rig.pitch = -0.15
		60:
			shot("1_spawn_day")
		61:
			main.rig.yaw = PI
		120:
			shot("2_cars")
		121:
			var c = main.cars[1]
			pl.enter_car(c)
			main.rig.yaw = c.global_rotation.y + PI
			Input.action_press("move_forward")
		300:
			shot("3_driving")
			Input.action_release("move_forward")
		301:
			pl.exit_car()
			main._command("tp склад")
			main.rig.yaw = -2.4
			main.rig.pitch = -0.3
		380:
			shot("4_warehouse")
		381:
			main._command("tp мэрия")
			main.rig.yaw = PI - 0.2
			main.rig.pitch = -0.1
		450:
			shot("5_city_hall")
		451:
			main._command("time 22")
			main._command("tp парк")
			main.rig.yaw = 0.3
		530:
			shot("6_night")
		540:
			return true
	return false
