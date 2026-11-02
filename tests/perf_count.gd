extends Node
## Counts render objects in a generated city (draw-call budget check).
func _ready() -> void:
	var run := RunState.new(3, 5)
	for th in CityGen.THEMES:
		run.theme = th
		var w := World.new()
		w.setup(run, false)
		add_child(w)
		await get_tree().process_frame
		var meshes := w.find_children("*", "MeshInstance3D", true, false).size()
		var lights := w.find_children("*", "Light3D", true, false).size()
		var bodies := w.find_children("*", "CollisionObject3D", true, false).size()
		print("PERF %s meshes=%d lights=%d bodies=%d" % [th, meshes, lights, bodies])
		w.queue_free()
		await get_tree().process_frame
	get_tree().quit()
