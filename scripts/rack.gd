class_name Rack
extends Node3D
## The food tower on the back of the scooter. Items are FoodItem models with
## visuals chained on pivots so tilts accumulate up the tower.

signal item_fell(item: FoodItem, xform: Transform3D, vel: Vector3)
signal spilled(item: FoodItem, amount: float)

var items: Array = []
var pivots: Array = []
var visuals: Array = []
var mods := {}
var balance := Vector2.ZERO
var body: RigidBody3D
var heat_mult := 1.0
var _rng := RandomNumberGenerator.new()


func capacity() -> int:
	return int(mods.get("capacity", 3))


func is_full() -> bool:
	return items.size() >= capacity()


func add_item(it: FoodItem) -> bool:
	if is_full():
		return false
	it.tilt = Vector2.ZERO
	it.tilt_vel = Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
	if it.tape == 0:
		it.tape = int(mods.get("tape", 0))
	items.append(it)
	_rebuild()
	return true


func top() -> FoodItem:
	return items.back() if items.size() > 0 else null


func top_tilt() -> Vector2:
	var cum := Vector2.ZERO
	for it in items:
		cum += it.tilt
	return cum


## Worst ratio of tilt to fall limit along the tower (0 = calm, 1 = falling).
func danger() -> float:
	var cum := Vector2.ZERO
	var d := 0.0
	for it in items:
		cum += it.tilt
		d = maxf(d, cum.length() / it.limit)
		if it.is_liquid():
			d = maxf(d, (it.slosh + it.tilt).length() / (it.spill_thr * mods.get("spill_thr_mult", 1.0)) * 0.8)
	return d


## Remove an item (delivery or theft). Items above get shaken like Jenga.
func remove_item(it: FoodItem) -> void:
	var i := items.find(it)
	if i < 0:
		return
	items.remove_at(i)
	for j in range(i, items.size()):
		var above: FoodItem = items[j]
		above.tilt_vel += Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * 2.2
	_rebuild()


func step(dt: float, accel: Vector2) -> void:
	var cum := Vector2.ZERO
	var i := 0
	while i < items.size():
		var it: FoodItem = items[i]
		var amount := it.step(dt, accel, i, balance, mods)
		if amount > 0.0:
			spilled.emit(it, amount)
		var hm: float = heat_mult
		if it.is_cold() and mods.get("heatwave", false):
			hm *= 2.0
		elif not it.is_cold() and mods.get("heatwave", false):
			hm *= 0.6
		it.step_heat(dt, hm * mods.get("heat_loss_mult", 1.0))
		cum += it.tilt
		if cum.length() > it.limit:
			if it.tape > 0:
				it.tape -= 1
				it.tilt *= 0.3
				it.tilt_vel = -it.tilt_vel * 0.3
				cum = Vector2.ZERO
				for k in i + 1:
					cum += items[k].tilt
			else:
				_fall(i, cum)
				continue
		i += 1
	_update_visuals()


func jolt(strength: float) -> void:
	for it in items:
		var dir := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		it.jolt(strength, dir, mods)


## Everything flies off (crash).
func scatter(extra_vel: Vector3) -> void:
	while items.size() > 0:
		var i := items.size() - 1
		var it: FoodItem = items[i]
		var xf: Transform3D = visuals[i].global_transform
		items.remove_at(i)
		it.on_fall()
		var v := extra_vel + Vector3(_rng.randf_range(-3, 3), _rng.randf_range(3, 6), _rng.randf_range(-3, 3))
		item_fell.emit(it, xf, v)
	_rebuild()


func _fall(i: int, cum: Vector2) -> void:
	var it: FoodItem = items[i]
	var xf: Transform3D = visuals[i].global_transform
	items.remove_at(i)
	it.on_fall()
	var dir := global_transform.basis * Vector3(cum.x, 0, -cum.y).normalized()
	var v := (body.linear_velocity if body else Vector3.ZERO) + dir * 2.5 + Vector3.UP * 1.5
	item_fell.emit(it, xf, v)
	for j in range(i, items.size()):
		var above: FoodItem = items[j]
		above.tilt_vel += Vector2(cum.x, cum.y).normalized() * 2.5
	_rebuild()


func _rebuild() -> void:
	for p in pivots:
		if is_instance_valid(p):
			p.queue_free()
	pivots.clear()
	visuals.clear()
	var parent: Node3D = self
	var y := 0.0
	for it in items:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, y, 0)
		parent.add_child(pivot)
		var v := FoodVisual.build(it.kind)
		pivot.add_child(v)
		pivots.append(pivot)
		visuals.append(v)
		parent = pivot
		y = it.height()
	_update_visuals()


func _update_visuals() -> void:
	for i in items.size():
		var it: FoodItem = items[i]
		var p: Node3D = pivots[i]
		p.rotation = Vector3(-it.tilt.y, 0, -it.tilt.x)
		var v: Node3D = visuals[i]
		if v.has_meta("liquid"):
			var s: MeshInstance3D = v.get_meta("liquid")
			s.rotation = Vector3(-it.slosh.y * 0.7, 0, -it.slosh.x * 0.7)
			s.visible = it.integrity > 3.0
			if it.kind == "soup":
				s.position.y = 0.06 + 0.13 * it.integrity / 100.0
