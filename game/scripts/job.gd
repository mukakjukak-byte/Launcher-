class_name DeliveryJob
extends Node3D
## Работа «Доставщик»: жёлтый маркер у склада -> фургон -> 5 красных чекпоинтов -> зарплата.

const POINTS := 5
const PAY_PER_POINT := 120
const BONUS := 300

var main: Node
var city: City
var start_marker: Checkpoint
var active := false
var van: Car = null
var current: Checkpoint = null
var done := 0
var _rng := RandomNumberGenerator.new()


func setup(m: Node, c: City) -> void:
	main = m
	city = c
	_rng.randomize()
	start_marker = Checkpoint.create(c.places["склад"], 1.6, Color(1.0, 0.85, 0.1, 0.5))
	add_child(start_marker)
	start_marker.reached.connect(_on_start_marker)


func _on_start_marker(body: Node3D) -> void:
	if body is Player and not active:
		call_deferred("start")


func start() -> void:
	if active:
		Game.msg("Вы уже работаете. /quitjob — уволиться.", Color(1, 0.6, 0.3))
		return
	active = true
	done = 0
	var pos: Vector3 = city.places["склад"] + Vector3(-6, 0.9, 6)
	van = Car.create("van", Color(0.95, 0.95, 0.95))
	main.add_car(van, Transform3D(Basis(Vector3.UP, PI / 2.0), pos))
	Game.msg("[Работа] Вы устроились доставщиком. Садитесь в белый фургон (F).", Color(1.0, 0.85, 0.3))
	Game.msg("[Работа] Развезите заказы по красным чекпоинтам. Оплата: $%d за точку." % PAY_PER_POINT, Color(1.0, 0.85, 0.3))
	_next_point()


func _next_point() -> void:
	if current:
		current.queue_free()
		current = null
	if done >= POINTS:
		_finish()
		return
	var p: Vector3 = city.road_points[_rng.randi() % city.road_points.size()]
	current = Checkpoint.create(p, 3.2)
	add_child(current)
	current.reached.connect(_on_point)
	main.hud.job_label.text = "Доставка: точка %d из %d" % [done + 1, POINTS]


func _on_point(body: Node3D) -> void:
	if body != van or van.driver == null:
		if body is Player:
			Game.msg("[Работа] Нужно приехать на рабочем фургоне.", Color(1, 0.6, 0.3))
		return
	done += 1
	Game.add_money(PAY_PER_POINT)
	main.hud.show_big("+$%d" % PAY_PER_POINT, 1.5)
	call_deferred("_next_point")


func _finish() -> void:
	Game.add_money(BONUS)
	Game.msg("[Работа] Все заказы доставлены! Премия $%d." % BONUS, Color(0.4, 1.0, 0.4))
	main.hud.show_big("Смена завершена!\n+$%d" % (POINTS * PAY_PER_POINT + BONUS), 4.0)
	stop(false)


func stop(announce := true) -> void:
	if not active:
		return
	active = false
	if current:
		current.queue_free()
		current = null
	main.hud.job_label.text = ""
	if van and is_instance_valid(van):
		if van.driver:
			main.player.exit_car()
		main.remove_car(van)
	van = null
	if announce:
		Game.msg("[Работа] Вы уволились.", Color(1, 0.6, 0.3))
