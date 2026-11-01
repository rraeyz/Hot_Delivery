class_name Npcs
extends RefCounted
## Traffic cars and dogs.


## Rounded little car: body, tapered cabin, glass, bumpers, lights, wheels with hubs.
static func car_body(p: Node3D, c: Color) -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.55
	cm.height = 4.1
	body.mesh = cm
	body.rotation.x = PI / 2
	body.scale = Vector3(1.8, 1.0, 0.75)
	body.position = Vector3(0, 0.75, 0)
	body.material_override = U.mat(c, false, 0.35)
	p.add_child(body)
	var glass := Color("#9ec9e3")
	U.box(p, Vector3(1.62, 0.55, 2.0), glass, Vector3(0, 1.38, 0.2)).material_override = U.mat(glass, false, 0.08)
	for z in [-0.75, 0.1, 0.95]:
		U.box(p, Vector3(1.66, 0.55, 0.1), c.darkened(0.1), Vector3(0, 1.38, z + 0.2))  # pillars
	U.box(p, Vector3(1.7, 0.1, 2.1), c, Vector3(0, 1.7, 0.2))  # roof
	U.box(p, Vector3(1.9, 0.18, 0.2), Color("#dee2e6"), Vector3(0, 0.55, -2.05))
	U.box(p, Vector3(1.9, 0.18, 0.2), Color("#dee2e6"), Vector3(0, 0.55, 2.05))
	for x in [-0.6, 0.6]:
		var hl := U.box(p, Vector3(0.35, 0.16, 0.05), Color("#fff3b0"), Vector3(x, 0.82, -2.06))
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#fff3b0")
		m.emission_enabled = true
		m.emission = Color("#fff3b0")
		hl.material_override = m
		U.box(p, Vector3(0.3, 0.14, 0.05), Color("#d00000"), Vector3(x, 0.82, 2.06))
	for x in [-0.92, 0.92]:
		for z in [-1.3, 1.3]:
			var w := U.cyl(p, 0.36, 0.36, 0.28, Color("#151515"), Vector3(x, 0.36, z))
			w.rotation.z = PI / 2
			var hub := U.cyl(p, 0.18, 0.18, 0.3, Color("#adb5bd"), Vector3(x, 0.36, z))
			hub.rotation.z = PI / 2


class Car extends AnimatableBody3D:
	var grid_n := 5
	var from := Vector2i.ZERO
	var dir := Vector2i(1, 0)
	var t := 0.0
	var speed := 8.0
	var cur_speed := 8.0
	var scooter: Scooter
	var world_ref: Node   # World; untyped to avoid a class cycle
	var rng := RandomNumberGenerator.new()
	var impatience := 0.0
	signal honk(car: Node3D)

	func setup(n: int, start: Vector2i, c: Color, s: int) -> void:
		grid_n = n
		from = start
		rng.seed = s
		speed = rng.randf_range(6.5, 10.0)
		sync_to_physics = true
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.0, 1.5, 4.0)
		cs.shape = sh
		cs.position = Vector3(0, 0.95, 0)
		add_child(cs)
		Npcs.car_body(self, c)
		_pick_dir(true)

	func _node_pos(p: Vector2i) -> Vector3:
		return Vector3(p.x * CityGen.PITCH, 0, p.y * CityGen.PITCH)

	func _pick_dir(any: bool) -> void:
		var opts := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = from + d
			if nx.x < 0 or nx.y < 0 or nx.x > grid_n or nx.y > grid_n:
				continue
			if not any and d == -dir:
				continue
			opts.append(d)
		if opts.is_empty():
			dir = -dir
		else:
			dir = opts[rng.randi() % opts.size()]

	func _physics_process(dt: float) -> void:
		var a := _node_pos(from)
		var b := _node_pos(from + dir)
		var fwd := (b - a).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		var target_speed := speed
		impatience = maxf(0.0, impatience - dt * 0.5)
		if world_ref and impatience < 2.0:
			var near_s: Node3D = world_ref.nearest_scooter(global_position)
			var to_s := near_s.global_position - global_position
			if to_s.dot(fwd) > 0.0 and to_s.dot(fwd) < 8.0 and absf(to_s.dot(right)) < 2.2:
				target_speed = 0.0
				impatience += dt * 1.5   # after ~2 s of waiting they lose patience and push through
				if impatience >= 2.0:
					honk.emit(self)
					impatience = 5.0
		cur_speed = move_toward(cur_speed, target_speed, dt * 12.0)
		t += cur_speed * dt / CityGen.PITCH
		if t >= 1.0:
			t = 0.0
			from = from + dir
			_pick_dir(false)
			return
		var p := a.lerp(b, t) + right * 3.0
		global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p)


class Dog extends CharacterBody3D:
	var scooter: Scooter
	var world_ref: Node
	var home := Vector3.ZERO
	var bark_cd := 0.0
	var legs: Array = []
	var _t := 0.0
	signal bit(dog: Node3D)

	func setup(pos: Vector3) -> void:
		home = pos
		position = pos
		collision_layer = 0
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.35
		cs.shape = sh
		cs.position = Vector3(0, 0.4, 0)
		add_child(cs)
		var c := Color("#a0522d")
		U.box(self, Vector3(0.35, 0.35, 0.8), c, Vector3(0, 0.55, 0))
		U.box(self, Vector3(0.3, 0.3, 0.35), c, Vector3(0, 0.8, -0.5))
		U.box(self, Vector3(0.18, 0.12, 0.2), Color("#3b2416"), Vector3(0, 0.74, -0.75))
		U.box(self, Vector3(0.08, 0.15, 0.06), Color("#3b2416"), Vector3(-0.12, 1.0, -0.45))
		U.box(self, Vector3(0.08, 0.15, 0.06), Color("#3b2416"), Vector3(0.12, 1.0, -0.45))
		U.box(self, Vector3(0.06, 0.06, 0.35), c, Vector3(0, 0.75, 0.5)).rotation.x = -0.6
		for x in [-0.12, 0.12]:
			for z in [-0.3, 0.3]:
				legs.append(U.box(self, Vector3(0.08, 0.38, 0.08), c, Vector3(x, 0.19, z)))

	func _physics_process(dt: float) -> void:
		_t += dt
		bark_cd -= dt
		var target := home
		var chasing := false
		if world_ref:
			scooter = world_ref.nearest_scooter(global_position)
		if scooter and scooter.global_position.distance_to(global_position) < 35.0 and not scooter.is_crashed:
			target = scooter.global_position
			chasing = true
		var to := target - global_position
		to.y = 0.0
		var spd := 12.5 if chasing else 4.0
		if to.length() < 1.0:
			velocity = Vector3(0, velocity.y, 0)
		else:
			var d := to.normalized()
			velocity = Vector3(d.x * spd, velocity.y, d.z * spd)
			look_at(global_position + d, Vector3.UP)
		velocity.y -= 20.0 * dt
		move_and_slide()
		if is_on_floor():
			velocity.y = 0.0
		for i in legs.size():
			legs[i].rotation.x = sin(_t * 18.0 + i * PI) * 0.6 * minf(1.0, velocity.length() / 4.0)
		if chasing and to.length() < 1.6 and bark_cd <= 0.0:
			bark_cd = 1.5
			bit.emit(self)


## Wedding convoy: a honking line of white cars crawls straight across town, blocking the road.
class Convoy extends Node3D:
	var cars: Array = []
	var dir := Vector3.FORWARD
	var speed := 6.0
	var length := 300.0
	var travelled := 0.0
	var honk_t := 0.0
	signal honk

	func setup(start: Vector3, d: Vector3, total: float) -> void:
		dir = d.normalized()
		length = total
		for i in 5:
			var car := AnimatableBody3D.new()
			car.sync_to_physics = true
			car.collision_layer = 1
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(2.0, 1.5, 4.0)
			cs.shape = sh
			cs.position = Vector3(0, 0.95, 0)
			car.add_child(cs)
			Npcs.car_body(car, Color("#f8f9fa"))
			# ribbons and a heart on the lead car
			U.box(car, Vector3(0.12, 0.02, 4.0), Color("#ff70a6"), Vector3(0.5, 1.76, 0.2))
			U.box(car, Vector3(0.12, 0.02, 4.0), Color("#ff70a6"), Vector3(-0.5, 1.76, 0.2))
			if i == 0:
				U.sphere(car, 0.3, Color("#e63946"), Vector3(0, 2.0, -0.6))
			add_child(car)
			car.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), start - dir * (i * 5.5))
			cars.append(car)

	func _physics_process(dt: float) -> void:
		travelled += speed * dt
		for c in cars:
			c.global_position += dir * speed * dt
		honk_t -= dt
		if honk_t <= 0.0:
			honk_t = randf_range(1.5, 3.0)
			honk.emit()
		if travelled > length + 30.0:
			queue_free()


## Pedestrian walking around a block on the sidewalk. Bump into one and they cartwheel away.
class Walker extends Node3D:
	var center := Vector3.ZERO
	var half := 15.5
	var t := 0.0
	var speed := 1.3
	var knocked := 0.0
	var body: Node3D
	var world_ref: Node
	var _phase := 0.0
	const BASE_Y := 0.68
	signal bumped(w: Node3D)

	func setup(c: Vector3, look: Dictionary, start: float, dir_sign: float) -> void:
		center = c
		t = start
		speed = randf_range(1.0, 1.7) * dir_sign
		body = Node3D.new()
		Courier.build(body, look, true)
		body.scale = Vector3.ONE * 1.15   # ~1.75 m tall: feet at -0.59, head top ~1.1
		body.position.y = BASE_Y
		add_child(body)

	func _perimeter(u: float) -> Vector3:
		var L := half * 8.0
		u = fposmod(u, L)
		var side := int(u / (half * 2.0))
		var k := fmod(u, half * 2.0) - half
		match side:
			0: return center + Vector3(k, 0.15, -half)
			1: return center + Vector3(half, 0.15, k)
			2: return center + Vector3(-k, 0.15, half)
			_: return center + Vector3(-half, 0.15, -k)

	func _physics_process(dt: float) -> void:
		if knocked > 0.0:
			knocked -= dt
			if knocked <= 0.0:
				body.rotation = Vector3.ZERO
				body.position = Vector3(0, BASE_Y, 0)
			return
		t += speed * dt
		_phase += dt * 8.0
		var p := _perimeter(t)
		var ahead := _perimeter(t + signf(speed) * 0.5)
		global_position = p
		if ahead.distance_to(p) > 0.01:
			look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)
		body.position.y = BASE_Y + absf(sin(_phase)) * 0.05
		if world_ref:
			var s: Node3D = world_ref.nearest_scooter(global_position)
			if s.global_position.distance_to(global_position) < 1.1 and absf(s.get("speed")) > 2.5:
				knock(s.get("linear_velocity"))

	func knock(v: Vector3) -> void:
		knocked = 3.0
		bumped.emit(self)
		var away := Vector3(v.x, 0, v.z).normalized()
		var tw := body.create_tween()
		tw.tween_property(body, "position", away * 3.0 + Vector3.UP * 1.8, 0.4).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(body, "rotation", Vector3(PI * 3.0, 0, PI), 0.8)
		tw.tween_property(body, "position", away * 4.0, 0.4).set_ease(Tween.EASE_IN)
