class_name Autopilot
extends RefCounted
## A simple bot that plays a shift: follows the road grid to restaurants and customers.
## Used by automated tests (balance + crash detection) and the menu attract mode.

var world: World
var path: Array = []
var goal := Vector3.INF
var replan := 0.0
var rng := RandomNumberGenerator.new()
var throws := true
var stuck_t := 0.0
var reverse_t := 0.0


func _init(w: World) -> void:
	world = w
	rng.seed = 11


func _pick_goal() -> Vector3:
	var s := world.scooter
	var pos := s.global_position
	var best := Vector3.INF
	var bd := 1e9
	for lf in world.loose:
		if is_instance_valid(lf) and not s.rack.is_full():
			var d: float = lf.global_position.distance_to(pos)
			if d < bd and d < 40.0:
				bd = d
				best = lf.global_position
	if best != Vector3.INF:
		return best
	for it in s.rack.items:
		var o := world.order_by_id(it.order_id)
		if not o.is_empty():
			var p: Vector3 = world.city.lots[o.cust].curb
			if p.distance_to(pos) < bd:
				bd = p.distance_to(pos)
				best = p
	if best != Vector3.INF and (s.rack.is_full() or s.rack.items.size() >= 2):
		return best
	for o in world.orders:
		if o.state == "offer" and not s.rack.is_full():
			var p: Vector3 = world.city.lots[o.rest].curb
			if p.distance_to(pos) < bd:
				bd = p.distance_to(pos)
				best = p
	return best


static func _road_nodes(p: Vector3, n: int) -> Array:
	var P := CityGen.PITCH
	var gx := p.x / P
	var gz := p.z / P
	var out := []
	if absf(gx - round(gx)) * P < 7.0:
		var i := clampi(int(round(gx)), 0, n)
		out.append(Vector2i(i, clampi(int(floor(gz)), 0, n)))
		out.append(Vector2i(i, clampi(int(ceil(gz)), 0, n)))
	if absf(gz - round(gz)) * P < 7.0:
		var j := clampi(int(round(gz)), 0, n)
		out.append(Vector2i(clampi(int(floor(gx)), 0, n), j))
		out.append(Vector2i(clampi(int(ceil(gx)), 0, n), j))
	if out.is_empty():
		out.append(Vector2i(clampi(int(round(gx)), 0, n), clampi(int(round(gz)), 0, n)))
	return out


static func _np(v: Vector2i) -> Vector3:
	return Vector3(v.x * CityGen.PITCH, 0, v.y * CityGen.PITCH)


## Waypoints from a to b along the road grid (L-shaped between intersections).
static func plan(a: Vector3, b: Vector3, n: int) -> Array:
	var best: Array = []
	var best_len := 1e9
	for na in _road_nodes(a, n):
		for nb in _road_nodes(b, n):
			for order in [0, 1]:
				var corner := Vector2i(nb.x, na.y) if order == 0 else Vector2i(na.x, nb.y)
				var pts := [_np(na), _np(corner), _np(nb), b]
				var L := a.distance_to(pts[0])
				for k in 3:
					L += pts[k].distance_to(pts[k + 1])
				if L < best_len:
					best_len = L
					best = pts
	# same road segment and close: go straight
	if a.distance_to(b) < 30.0:
		var d := b - a
		if absf(d.x) < 4.0 or absf(d.z) < 4.0:
			return [b]
	return best


func drive(dt: float) -> Dictionary:
	var s := world.scooter
	if s.is_crashed:
		return {"throttle": 0.0, "steer": 0.0}
	replan -= dt
	var g := _pick_goal()
	if g == Vector3.INF:
		return {"throttle": 0.0, "steer": 0.0}
	if replan <= 0.0 or g.distance_to(goal) > 1.0:
		goal = g
		path = plan(s.global_position, g, world.city.n)
		replan = 4.0
	var pos := s.global_position
	while path.size() > 1 and Vector2(pos.x, pos.z).distance_to(Vector2(path[0].x, path[0].z)) < 5.0:
		path.pop_front()
	if path.is_empty():
		return {"throttle": 0.0, "steer": 0.0}
	var wp: Vector3 = path[0]
	var to := wp - pos
	to.y = 0.0
	var local := s.global_basis.inverse() * to.normalized()
	var ang := atan2(local.x, -local.z)
	var steer := clampf(ang * 2.2, -1.0, 1.0)
	var dist := to.length()
	var target_speed := 12.0
	if path.size() > 1:
		var nxt: Vector3 = path[1] - wp
		var turn := absf(to.normalized().angle_to(Vector3(nxt.x, 0, nxt.z).normalized()))
		if turn > 0.5 and dist < 22.0:
			target_speed = lerpf(4.5, 12.0, clampf((dist - 4.0) / 18.0, 0.0, 1.0))
	else:
		target_speed = clampf(dist * 0.55, 0.0, 12.0)
	if absf(ang) > 1.2:
		target_speed = minf(target_speed, 3.5)
	var spd := s.speed
	var thr := clampf((target_speed - spd) * 0.4, -0.45, 1.0)
	if absf(spd) < 0.5 and target_speed > 1.0:
		stuck_t += dt
	else:
		stuck_t = 0.0
	if stuck_t > 2.0:
		stuck_t = 0.0
		reverse_t = 1.6
		replan = 0.0
	if reverse_t > 0.0:
		# back up, steering so the nose swings toward the target
		reverse_t -= dt
		thr = -1.0
		steer = -signf(ang) if absf(ang) > 0.1 else 1.0
	for lf in world.loose:
		if is_instance_valid(lf) and lf.global_position.distance_to(pos) < 3.2:
			world.request_pickup = true
	# counter-balance: push against the lean
	var bal := -s.rack.top_tilt() * 3.0
	# throw if close to a balcony target
	if throws and s.rack.items.size() > 0:
		var top: FoodItem = s.rack.top()
		var o := world.order_by_id(top.order_id)
		if not o.is_empty() and o.state == "carry":
			var tp := world._target_point(o)
			if Vector2(tp.x, tp.z).distance_to(Vector2(pos.x, pos.z)) < 14.0 and absf(spd) < 5.0 and rng.randf() < 0.02:
				world.throw_top()
	return {"throttle": thr, "steer": steer, "balance": bal.limit_length(1.0)}
