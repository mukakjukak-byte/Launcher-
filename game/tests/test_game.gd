extends SceneTree
## Автотест: godot --headless --path game -s res://tests/test_game.gd

var main
var frame := 0
var step := 0
var t0 := 0
var log_lines := []
var car_ref

func _initialize() -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f: f.store_string("{}")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func p(s): print("[TEST] ", s)

func _physics_process(_d: float) -> bool:
	frame += 1
	var pl = main.player
	match step:
		0:
			if frame == 90:
				p("player on floor=%s y=%.2f" % [pl.is_on_floor(), pl.global_position.y])
				t0 = frame
				car_ref = pl.global_position
				Input.action_press("move_forward")
				step = 1
		1:
			if frame - t0 == 120:
				Input.action_release("move_forward")
				p("walked %.2f m in 2s (speed %.2f)" % [pl.global_position.distance_to(car_ref), Vector2(pl.velocity.x, pl.velocity.z).length()])
				Input.action_press("jump")
				step = 2
				t0 = frame
		2:
			if frame - t0 == 2:
				Input.action_release("jump")
			if frame - t0 == 15:
				p("jump y-vel=%.2f height=%.2f" % [pl.velocity.y, pl.global_position.y])
			if frame - t0 == 90:
				# сесть в первую машину
				var c = main.cars[0]
				pl.global_position = c.global_position + c.global_basis.x * 2.0
				step = 3
				t0 = frame
		3:
			if frame - t0 == 5:
				var near = main._nearest_car()
				p("nearest car: %s" % (near.car_name if near else "none"))
				if near: pl.enter_car(near)
				var cc = main.city
				near.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), cc._to_world(cc.ROAD + 3.0, 3 * cc.CELL + cc.ROAD / 2.0 + 3.0) + Vector3(0, 0.8, 0))
				car_ref = pl.car.global_position if pl.car else Vector3.ZERO
				Input.action_press("move_forward")
				t0 = frame
				step = 4
		4:
			var c = pl.car
			if (frame - t0) % 60 == 0:
				p("t=%ds speed=%d km/h flipped=%s y=%.2f" % [(frame - t0) / 60, c.kmh(), c.is_flipped(), c.global_position.y])
			if frame - t0 == 600:
				Input.action_release("move_forward")
				Input.action_press("move_back")
				t0 = frame
				step = 5
		5:
			var c = pl.car
			if c.kmh() < 2 and frame - t0 > 5:
				p("brake stop in %.2fs" % ((frame - t0) / 60.0))
				Input.action_release("move_back")
				Input.action_press("move_forward")
				Input.action_press("move_right")
				car_ref = c.global_rotation.y
				t0 = frame
				step = 6
			elif frame - t0 > 600:
				p("brake FAILED speed=%d" % c.kmh())
				step = 99
		6:
			var c = pl.car
			if frame - t0 == 180:
				Input.action_release("move_forward")
				Input.action_release("move_right")
				p("turn right: yaw change %.2f rad, flipped=%s, speed=%d" % [angle_difference(car_ref, c.global_rotation.y), c.is_flipped(), c.kmh()])
				pl.exit_car()
				p("exited car: player visible=%s pos y=%.2f" % [pl.visible, pl.global_position.y])
				main._command("job")
				t0 = frame
				step = 7
		7:
			if frame - t0 == 30:
				var j = main.job
				p("job active=%s van=%s point=%s" % [j.active, j.van != null, j.current != null])
				pl.enter_car(j.van)
				# телепорт фургона в чекпоинт 5 раз
				step = 8
				t0 = frame
		8:
			var j = main.job
			if j.active and j.current and (frame - t0) % 40 == 0:
				var v = j.van
				v.global_transform = Transform3D(v.global_basis, j.current.global_position + Vector3(0, 1.0, 0))
				v.linear_velocity = Vector3.ZERO
			if not j.active:
				p("job finished, money=%d" % root.get_node("Game").money)
				step = 9
				t0 = frame
			elif frame - t0 > 1200:
				p("job FAILED done=%d" % j.done)
				step = 99
		9:
			main._command("time 23")
			main._command("car sport")
			main._command("tp парк")
			main._command("stats")
			for l in main.hud._lines:
				if l.text != "": p("chat: " + l.text)
			step = 99
		99:
			return true
	return false
