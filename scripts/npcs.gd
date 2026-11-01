class_name Npcs
extends RefCounted
## Traffic cars and dogs.


class Car extends AnimatableBody3D:
	var grid_n := 5
	var from := Vector2i.ZERO
	var dir := Vector2i(1, 0)
	var t := 0.0
	var speed := 8.0
	var cur_speed := 8.0
	var scooter: Scooter
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
		U.box(self, Vector3(2.0, 0.8, 4.0), c, Vector3(0, 0.7, 0))
		U.box(self, Vector3(1.8, 0.7, 2.2), c.lightened(0.2), Vector3(0, 1.45, 0.2))
		U.box(self, Vector3(1.82, 0.5, 2.0), Color("#a8dadc"), Vector3(0, 1.45, 0.2))
		for x in [-0.95, 0.95]:
			for z in [-1.3, 1.3]:
				var w := U.cyl(self, 0.38, 0.38, 0.3, Color("#111111"), Vector3(x, 0.38, z))
				w.rotation.z = PI / 2
		U.box(self, Vector3(0.4, 0.2, 0.05), Color("#fff3b0"), Vector3(-0.6, 0.8, -2.0))
		U.box(self, Vector3(0.4, 0.2, 0.05), Color("#fff3b0"), Vector3(0.6, 0.8, -2.0))
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
		if scooter and impatience < 2.0:
			var to_s := scooter.global_position - global_position
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
