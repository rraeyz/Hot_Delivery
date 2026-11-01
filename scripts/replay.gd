class_name Replay
extends Node3D
## Records the last seconds of the scooter, courier and food, and plays the
## biggest crash of the shift back in slow motion with an orbiting camera.

signal finished

const KEEP := 75            # frames kept before a crash (recorded at 30 Hz = 2.5 s)
const AFTER := 75           # frames recorded after the crash (2.5 s)

var frames: Array = []      # [{sc: [[visual xf, rider visible, ragdoll xf or null], ...], food: [[id, kind, xf]]}]
var who := 0                # the scooter whose crash this is (camera follows it)
var _i := 0.0
var speed := 0.35
var ghost_s: Array = []
var ghost_r: Array = []
var ghost_rag: Array = []
var ghosts := {}
var cam: Camera3D
var label: Label
var _orbit := 0.0


## Snapshot of one moment of the world: every scooter + all food.
# shortcut: whole clip goes in one reliable RPC (~100-350 KB with 4 players); trim or compress if Steam P2P (512 KB cap) complains.
static func capture(w: World) -> Dictionary:
	var f := {"sc": [], "food": []}
	for sc in w.scooters:
		f.sc.append([sc.visual.global_transform, sc.rider.visible,
			sc.ragdoll.global_transform if sc.is_crashed and is_instance_valid(sc.ragdoll) else null])
		for i in sc.rack.items.size():
			var it: FoodItem = sc.rack.items[i]
			f.food.append([it.get_instance_id(), it.kind, sc.rack.visuals[i].global_transform])
	for lf in w.loose:
		if is_instance_valid(lf):
			f.food.append([lf.item.get_instance_id(), lf.item.kind, lf.global_transform])
	return f


## scooters: the live ones, only read for their colour and look.
func play(data: Array, parent_cam: Camera3D, scooters: Array, crashed := 0) -> void:
	frames = data
	who = crashed
	var n: int = (frames[0].sc as Array).size()
	for k in n:
		var src: Scooter = scooters[k] if k < scooters.size() else null
		var g := Node3D.new()
		add_child(g)
		var tmp := Scooter.new()   # borrow its visual builder, then drop the physics body
		if src:
			tmp.color = src.color
			tmp.look = src.look
		tmp.set_physics_process(false)
		tmp.freeze = true
		tmp.collision_layer = 0
		tmp.collision_mask = 0
		add_child(tmp)
		tmp.rack.visible = false
		ghost_r.append(tmp.rider)
		var vis := tmp.visual
		tmp.remove_child(vis)
		g.add_child(vis)
		tmp.queue_free()
		vis.transform = Transform3D.IDENTITY
		ghost_s.append(g)
		var rag := Node3D.new()
		Courier.build(rag, src.look if src else Game.settings.look)
		add_child(rag)
		ghost_rag.append(rag)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.global_transform = parent_cam.global_transform
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	label = UiKit.label(Game.t("replay"), 34, UiKit.BAD)
	label.position = Vector2(30, 90)
	layer.add_child(label)
	var hint := UiKit.label(Game.t("replay_skip"), 16, Color(1, 1, 1, 0.7))
	hint.position = Vector2(30, 134)
	layer.add_child(hint)
	_apply(0)


func _apply(i: int) -> void:
	var f: Dictionary = frames[clampi(i, 0, frames.size() - 1)]
	for k in ghost_s.size():
		var e: Array = f.sc[k]
		ghost_s[k].global_transform = e[0]
		ghost_r[k].visible = e[1]
		ghost_rag[k].visible = e[2] != null
		if e[2] != null:
			ghost_rag[k].global_transform = e[2]
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
	var w := clampi(who, 0, ghost_s.size() - 1)
	var focus: Vector3 = ghost_rag[w].global_position if ghost_rag[w].visible else ghost_s[w].global_position
	var want := focus + Vector3(cos(_orbit) * 6.0, 3.0, sin(_orbit) * 6.0)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-3.0 * dt))
	cam.look_at(focus + Vector3.UP * 0.8)
	label.modulate.a = 0.85 + 0.15 * sin(_orbit * 8.0)
