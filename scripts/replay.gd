class_name Replay
extends Node3D
## Records the last seconds of the scooter, courier and food, and plays the
## biggest crash of the shift back in slow motion with an orbiting camera.

signal finished

const KEEP := 75            # frames kept before a crash (recorded at 30 Hz = 2.5 s)
const AFTER := 75           # frames recorded after the crash (2.5 s)

var frames: Array = []      # used by the player: [{s, r, rag, food: [[id, kind, xf]]}]
var _i := 0.0
var speed := 0.35
var ghost_s: Node3D
var ghost_r: Node3D
var ghost_rag: Node3D
var ghosts := {}
var cam: Camera3D
var label: Label
var _orbit := 0.0


## Snapshot of one moment of the world.
static func capture(w: World) -> Dictionary:
	var sc := w.scooter
	var f := {"s": sc.visual.global_transform, "r": sc.rider.visible,
		"rag": sc.ragdoll.global_transform if sc.is_crashed and is_instance_valid(sc.ragdoll) else null, "food": []}
	for i in sc.rack.items.size():
		var it: FoodItem = sc.rack.items[i]
		f.food.append([it.get_instance_id(), it.kind, sc.rack.visuals[i].global_transform])
	for lf in w.loose:
		if is_instance_valid(lf):
			f.food.append([lf.item.get_instance_id(), lf.item.kind, lf.global_transform])
	return f


func play(data: Array, parent_cam: Camera3D) -> void:
	frames = data
	ghost_s = Node3D.new()
	add_child(ghost_s)
	var tmp := Scooter.new()   # borrow its visual builder, then drop the physics body
	tmp.set_physics_process(false)
	tmp.freeze = true
	tmp.collision_layer = 0
	tmp.collision_mask = 0
	add_child(tmp)
	tmp.rack.visible = false
	ghost_r = tmp.rider
	var vis := tmp.visual
	tmp.remove_child(vis)
	ghost_s.add_child(vis)
	tmp.queue_free()
	vis.transform = Transform3D.IDENTITY
	ghost_rag = Node3D.new()
	Courier.build(ghost_rag, Game.settings.look)
	add_child(ghost_rag)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.global_transform = parent_cam.global_transform
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	label = UiKit.label("REPLAY · " + ("DISASTER OF THE DAY" if Game.lang() == "en" else "GÜNÜN FELAKETİ"), 40, UiKit.BAD)
	label.position = Vector2(30, 90)
	layer.add_child(label)
	var hint := UiKit.label("SPACE / A: skip", 18, Color(1, 1, 1, 0.7))
	hint.position = Vector2(30, 140)
	layer.add_child(hint)
	var bars := ColorRect.new()
	bars.color = Color(0, 0, 0, 0.0)
	layer.add_child(bars)
	_apply(0)


func _apply(i: int) -> void:
	var f: Dictionary = frames[clampi(i, 0, frames.size() - 1)]
	ghost_s.global_transform = f.s
	ghost_r.visible = f.r
	ghost_rag.visible = f.rag != null
	if f.rag != null:
		ghost_rag.global_transform = f.rag
	var seen := {}
	for e in f.food:
		var id: int = e[0]
		seen[id] = true
		if not ghosts.has(id):
			var g := FoodVisual.build(e[1])
			add_child(g)
			ghosts[id] = g
		ghosts[id].global_transform = e[2]
		ghosts[id].visible = true
	for id in ghosts:
		if not seen.has(id):
			ghosts[id].visible = false


func _process(dt: float) -> void:
	if frames.is_empty():
		return
	# real time until just before the crash, then slow motion
	speed = 1.0 if _i < frames.size() - AFTER - 12 else 0.3
	_i += dt * 30.0 * speed
	_orbit += dt * 0.5
	var i := int(_i)
	if i >= frames.size() or Input.is_action_just_pressed("solo_throw") or Input.is_action_just_pressed("p2_throw"):
		frames = []
		finished.emit()
		return
	_apply(i)
	var focus: Vector3 = ghost_rag.global_position if ghost_rag.visible else ghost_s.global_position
	var want := focus + Vector3(cos(_orbit) * 6.0, 3.0, sin(_orbit) * 6.0)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-3.0 * dt))
	cam.look_at(focus + Vector3.UP * 0.8)
	label.modulate.a = 0.6 + 0.4 * sin(_orbit * 8.0)
