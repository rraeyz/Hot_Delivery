extends Node
## Physics feel benchmark (headless):
##   godot --headless --path . --fixed-fps 60 res://tests/sim_drive.tscn
## Drives scripted maneuvers on a real World and prints what happened to the food.
## Also asserts basic sanity so CI catches a broken scooter.

var world: World
var fails := 0
const ARENA := Vector3(2000, 0, 2000)


func _ready() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame


func _phase(name: String, sec: float, inp: Dictionary, stack: Array) -> Dictionary:
	var s := world.scooter
	s.global_position = ARENA + Vector3(0, 0.5, 200)
	s.rotation = Vector3.ZERO
	s.recover()
	s.rack.items.clear()
	s.rack._rebuild()
	for l in world.loose:
		if is_instance_valid(l):
			l.queue_free()
	world.loose.clear()
	await _wait(0.6)
	for k in stack:
		s.rack.add_item(FoodItem.new(k))
	for it in s.rack.items:
		it.tilt_vel = Vector2.ZERO
	var pre: Dictionary = inp.get("pre", {})
	if pre.size() > 0:
		s.external_input = pre
		await _wait(inp.get("pre_t", 2.0))
	var max_d := 0.0
	var start_items := s.rack.items.size()
	s.external_input = inp.main
	var t := 0.0
	var vmax := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		max_d = maxf(max_d, s.rack.danger())
		vmax = maxf(vmax, absf(s.speed))
	var soup_left := -1.0
	for it in s.rack.items:
		if it.is_liquid():
			soup_left = it.integrity
	var r := {"name": name, "fell": start_items - s.rack.items.size(), "max_danger": snappedf(max_d, 0.01),
		"soup": soup_left, "vmax": snappedf(vmax, 0.1), "crashed": s.is_crashed}
	print(r)
	s.external_input = {"throttle": 0.0, "steer": 0.0}
	return r


func _run() -> void:
	var run := RunState.new(3, 0)
	world = World.new()
	world.setup(run, false)
	add_child(world)
	world.running = false   # no timer/orders, just physics
	U.static_box(world, Vector3(600, 1, 600), Color.GRAY, ARENA + Vector3(0, -0.5, 0))
	await _wait(1.5)
	var s := world.scooter
	s.global_position = ARENA + Vector3(0, 0.5, 200)
	await _wait(1.0)
	var y := s.global_position.y
	if absf(y) > 0.3:
		printerr("FAIL: scooter not resting on ground, y=", y)
		fails += 1
	var r := await _phase("full throttle 2-stack", 3.0, {"main": {"throttle": 1.0}}, ["pizza", "soup"])
	if r.fell > 0 or r.soup < 90.0:
		printerr("FAIL: plain acceleration should not ruin a 2-stack")
		fails += 1
	if r.vmax < 10.0:
		printerr("FAIL: scooter too slow")
		fails += 1
	r = await _phase("full throttle 3-stack", 3.0, {"main": {"throttle": 1.0}}, ["pizza", "soup", "burger"])
	r = await _phase("hard brake from speed", 1.5, {"pre": {"throttle": 1.0}, "pre_t": 2.5, "main": {"throttle": -1.0}}, ["pizza", "soup"])
	if r.soup > 98.0:
		printerr("FAIL: slamming the brakes should spill some soup")
		fails += 1
	r = await _phase("gentle brake", 3.0, {"pre": {"throttle": 1.0}, "pre_t": 2.5, "main": {"throttle": -0.35}}, ["pizza", "soup"])
	if r.soup < 99.0:
		printerr("FAIL: gentle braking should keep the soup")
		fails += 1
	r = await _phase("full speed hard turn 3-stack", 1.5, {"pre": {"throttle": 1.0}, "pre_t": 2.5, "main": {"throttle": 1.0, "steer": 1.0}}, ["pizza", "soup", "burger"])
	var no_bal: Dictionary = r
	r = await _phase("turn + counter-balance", 1.5, {"pre": {"throttle": 1.0}, "pre_t": 2.5, "main": {"throttle": 1.0, "steer": 1.0, "balance": Vector2(1, 0)}}, ["pizza", "soup", "burger"])
	if r.max_danger >= no_bal.max_danger:
		printerr("FAIL: balancing against the lean should help")
		fails += 1
	print("SIM DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
