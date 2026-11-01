extends Node
## Two co-op scooters: scooter 0 throws its top food to scooter 1 parked ahead.
##   godot --headless --path . --fixed-fps 60 res://tests/pass_test.tscn

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var run := RunState.new(3, 0)
	var w := World.new()
	w.setup(run, false, true)
	add_child(w)
	w.running = false
	U.static_box(w, Vector3(400, 1, 400), Color.GRAY, Vector3(3000, -0.5, 3000))
	for i in 60:
		await get_tree().physics_frame
	var a: Scooter = w.scooters[0]
	var b: Scooter = w.scooters[1]
	a.global_transform = Transform3D(Basis.IDENTITY, Vector3(3000, 0.5, 3010))
	b.global_transform = Transform3D(Basis.IDENTITY, Vector3(3000, 0.5, 3000))
	for i in 60:
		await get_tree().physics_frame
	a.rack.add_item(FoodItem.new("pizza"))
	w.scooter = a
	w.throw_top()
	var caught := false
	for i in 150:
		await get_tree().physics_frame
		w._check_loose()
		if b.rack.items.size() > 0:
			caught = true
			break
	print("PASS TEST caught=", caught, " carrier=", b.rack.items[0].carrier if caught else -1)
	get_tree().quit(0 if caught and b.rack.items[0].carrier == 1 else 1)
