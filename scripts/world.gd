class_name World
extends Node3D
## One shift: builds the city, spawns the scooter, runs orders/deliveries.

signal shift_ended(result: Dictionary)

const BUILDING_SHADER := """
shader_type spatial;
uniform vec3 base_color : source_color;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (abs(wnorm.y) > 0.5) {
		ALBEDO = base_color * 0.75;
		ROUGHNESS = 0.9;
	} else {
		vec2 c = abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy;
		vec2 g = fract(c / vec2(2.6, 3.0));
		float win = step(0.22, g.x) * step(g.x, 0.78) * step(0.3, g.y) * step(g.y, 0.82);
		win *= step(2.6, wpos.y);
		float band = step(0.95, fract(wpos.y / 3.0));
		vec3 col = mix(base_color, base_color * 0.82, band);
		ALBEDO = mix(col, vec3(0.62, 0.8, 0.95), win * 0.9);
		ROUGHNESS = mix(0.9, 0.15, win);
		METALLIC = win * 0.2;
	}
}
"""

var run: RunState
var city: Dictionary
var coop := false
var scooter: Scooter
var camera: ChaseCamera
var hud: Hud
var env: Environment
var rng := RandomNumberGenerator.new()
var time_left := 210.0
var running := false
var orders: Array = []
var next_order_id := 1
var offer_timer := 0.0
var loose: Array = []
var reviews: Array = []
var beacons := {}            # key -> Node3D
var combo := 0
var last_delivery_time := -100.0
var clock := 0.0
var still_time := 0.0
var gust_timer := 6.0
var pigeon_busy := false
var mods := {}
var request_pickup := false
var cars: Array = []
var dogs: Array = []
var _bmats := {}
var audio: Sfx
var arrow: Node3D
var rain: CPUParticles3D


func setup(r: RunState, coop_mode: bool) -> void:
	run = r
	coop = coop_mode
	mods = run.mods()
	rng.seed = run.seed_value * 1000 + run.day
	var bumps := 8 + (30 if "bumps" in run.chaos else 0)
	city = CityGen.generate(run.seed_value, 5, bumps)
	time_left = run.shift_length()


func _ready() -> void:
	audio = Sfx.new()
	add_child(audio)
	_build_environment()
	_build_city()
	scooter = Scooter.new()
	scooter.mods = mods
	scooter.coop = coop
	add_child(scooter)
	scooter.global_position = city.spawn
	scooter.rack.item_fell.connect(_on_item_fell)
	scooter.rack.spilled.connect(_on_spilled)
	scooter.crashed.connect(_on_crash)
	scooter.honked.connect(_on_honk)
	scooter.jolted.connect(_on_jolt)
	camera = ChaseCamera.new()
	camera.target = scooter
	add_child(camera)
	camera.current = true
	camera.snap()
	arrow = _make_arrow()
	add_child(arrow)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_spawn_npcs()
	for i in 2:
		_spawn_offer()
	running = true
	audio.music(true)


# ---------------------------------------------------------------- building

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#4ea8de")
	sm.sky_horizon_color = Color("#bde0fe")
	sm.ground_horizon_color = Color("#bde0fe")
	sm.ground_bottom_color = Color("#6c757d")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color("#fff1e0")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	if "fog" in run.chaos:
		env.fog_enabled = true
		env.fog_light_color = Color("#d8e2dc")
		env.fog_density = 0.035
		env.fog_sky_affect = 0.6
	if "rain" in run.chaos:
		sm.sky_top_color = Color("#5c677d")
		sm.sky_horizon_color = Color("#979dac")
		env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 0.6 if "rain" in run.chaos else 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	if "rain" in run.chaos:
		rain = CPUParticles3D.new()
		rain.amount = 600
		rain.lifetime = 0.8
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		rain.emission_box_extents = Vector3(18, 1, 18)
		rain.direction = Vector3(0.1, -1, 0)
		rain.spread = 2.0
		rain.initial_velocity_min = 25.0
		rain.initial_velocity_max = 30.0
		rain.gravity = Vector3.ZERO
		var dm := BoxMesh.new()
		dm.size = Vector3(0.02, 0.5, 0.02)
		dm.material = U.mat(Color(0.8, 0.85, 1.0, 0.5), true)
		rain.mesh = dm
		add_child(rain)


func _bmat(hex: String) -> ShaderMaterial:
	if _bmats.has(hex):
		return _bmats[hex]
	var sh := Shader.new()
	sh.code = BUILDING_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base_color", Color(hex))
	_bmats[hex] = m
	return m


func _build_city() -> void:
	var size: float = city.size
	var half_road := CityGen.ROAD * 0.5
	# ground
	var g := U.static_box(self, Vector3(size + 60, 1, size + 60), Color("#4a4e57"), Vector3(size * 0.5, -0.5, size * 0.5))
	g.collision_layer = 1
	# grass outside city
	U.box(self, Vector3(size + 400, 0.9, size + 400), Color("#7cb518"), Vector3(size * 0.5, -0.52, size * 0.5))
	# boundary walls
	for w in [[Vector3(size * 0.5, 1, -half_road - 0.5), Vector3(size + 14, 2, 1)],
			[Vector3(size * 0.5, 1, size + half_road + 0.5), Vector3(size + 14, 2, 1)],
			[Vector3(-half_road - 0.5, 1, size * 0.5), Vector3(1, 2, size + 14)],
			[Vector3(size + half_road + 0.5, 1, size * 0.5), Vector3(1, 2, size + 14)]]:
		U.static_box(self, w[1], Color("#e9c46a"), w[0])
	# lane dashes
	var n: int = city.n
	for i in n + 1:
		for j in n:
			for k in 4:
				var t := (j + 0.5) * CityGen.PITCH + (k - 1.5) * 8.0
				U.box(self, Vector3(0.25, 0.02, 3.0), Color("#f1faee"), Vector3(i * CityGen.PITCH, 0.01, t))
				U.box(self, Vector3(3.0, 0.02, 0.25), Color("#f1faee"), Vector3(t, 0.01, i * CityGen.PITCH))
	# blocks
	for b in city.blocks:
		var c: Vector3 = b.center
		var col := Color("#74c69d") if b.park else Color("#b8b0a6")
		U.static_box(self, Vector3(CityGen.BLOCK, 0.15, CityGen.BLOCK), col, c + Vector3(0, 0.075, 0))
		if b.park:
			# a big jump ramp in the park
			_ramp(c + Vector3(0, 0.15, 6), 0.0, Color("#e76f51"), 1.4)
	for tpos in city.trees:
		var tr := StaticBody3D.new()
		tr.position = tpos + Vector3(0, 0.15, 0)
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.25
		cy.height = 3.0
		cs.shape = cy
		cs.position = Vector3(0, 1.5, 0)
		tr.add_child(cs)
		U.cyl(tr, 0.2, 0.25, 2.4, Color("#7f5539"), Vector3(0, 1.2, 0), 8)
		U.sphere(tr, 1.3, Color("#52b788"), Vector3(0, 3.0, 0))
		add_child(tr)
	# buildings
	for i in city.lots.size():
		_build_lot(city.lots[i])
	for r in city.ramps:
		_ramp(r.pos, r.yaw, Color("#f4a261"), 1.0)
	for bm in city.bumps:
		var sb := U.static_box(self, Vector3(CityGen.ROAD - 1.0, 0.14, 0.7), Color("#ffd60a"), bm.pos + Vector3(0, 0.07, 0), bm.yaw + PI / 2)
		for s in 3:
			U.box(sb, Vector3(1.2, 0.145, 0.71), Color("#222222"), Vector3(-3.0 + s * 3.0, 0, 0))
	for p in city.props:
		_prop(p.kind, p.pos + Vector3(0, 0.15, 0))


func _ramp(pos: Vector3, yaw: float, c: Color, scale_h: float) -> void:
	var L := 6.0 * scale_h
	var T := 0.4
	var a := 0.24
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.0, T, L)
	cs.shape = sh
	cs.rotation.x = a
	cs.position = Vector3(0, L * 0.5 * sin(a) - T * 0.5 * cos(a), 0)
	sb.add_child(cs)
	var m := U.box(sb, Vector3(4.0, T, L), c)
	m.rotation.x = a
	m.position = cs.position
	for s in 3:
		var st := U.box(sb, Vector3(4.02, T + 0.01, 0.5), Color("#ffffff"), Vector3.ZERO)
		st.rotation.x = a
		st.position = cs.position + Vector3(0, 0, (s - 1) * L * 0.3).rotated(Vector3.RIGHT, a)
	add_child(sb)


func _build_lot(lot: Dictionary) -> void:
	var s: Vector3 = lot.size
	var c: Vector3 = lot.center
	var sb := StaticBody3D.new()
	sb.position = c + Vector3(0, 0.15 + s.y * 0.5, 0)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	cs.shape = sh
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = _bmat(lot.color)
	sb.add_child(mi)
	add_child(sb)
	var side: Vector3 = lot.side
	var yaw := atan2(side.x, side.z)
	# door
	var door := Node3D.new()
	door.position = lot.door + Vector3(0, 0.15, 0)
	door.rotation.y = yaw
	add_child(door)
	U.box(door, Vector3(1.4, 2.3, 0.2), Color("#6f4518"), Vector3(0, 1.15, -0.25))
	U.box(door, Vector3(1.8, 0.12, 0.9), Color("#adb5bd"), Vector3(0, 0.06, 0.1))
	# balcony
	var bal := StaticBody3D.new()
	bal.position = lot.balcony - side * 0.9 + Vector3(0, 0.15, 0)
	bal.rotation.y = yaw
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(3.0, 0.2, 1.8)
	bcs.shape = bsh
	bcs.position = Vector3(0, -0.1, 0.9)
	bal.add_child(bcs)
	U.box(bal, Vector3(3.0, 0.2, 1.8), Color("#f8f9fa"), Vector3(0, -0.1, 0.9))
	U.box(bal, Vector3(3.0, 0.7, 0.08), Color("#f8f9fa"), Vector3(0, 0.35, 1.78))
	U.box(bal, Vector3(0.08, 0.7, 1.8), Color("#f8f9fa"), Vector3(-1.46, 0.35, 0.9))
	U.box(bal, Vector3(0.08, 0.7, 1.8), Color("#f8f9fa"), Vector3(1.46, 0.35, 0.9))
	U.box(bal, Vector3(1.0, 2.0, 0.1), Color("#3d5a80"), Vector3(0, 1.0, 0.02))
	add_child(bal)
	if lot.rest != "":
		var aw := Node3D.new()
		aw.position = lot.door + Vector3(0, 0.15, 0)
		aw.rotation.y = yaw
		add_child(aw)
		var rc := _rest_color(lot.rest)
		var awning := U.box(aw, Vector3(s.x if absf(side.z) > 0.5 else s.z, 0.15, 2.2), rc, Vector3(0, 3.2, 0.7))
		awning.rotation.x = 0.25
		var l := U.label3d(aw, _rest_name(lot.rest), Vector3(0, 4.6, 0.3), 160, Color.WHITE)
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.outline_modulate = rc.darkened(0.5)
		l.outline_size = 24


func _rest_color(k: String) -> Color:
	return {"pizza": Color("#e63946"), "soup": Color("#f77f00"), "burger": Color("#8d5524"),
		"dessert": Color("#ff70a6"), "sushi": Color("#1d3557")}.get(k, Color.WHITE)


func _rest_name(k: String) -> String:
	return {"pizza": "PIZZA", "soup": "SOUP", "burger": "BURGER", "dessert": "DESSERT", "sushi": "SUSHI"}.get(k, k)


func _prop(kind: String, pos: Vector3) -> void:
	if kind == "hydrant":
		var sb := StaticBody3D.new()
		sb.position = pos
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.2
		cy.height = 0.8
		cs.shape = cy
		cs.position = Vector3(0, 0.4, 0)
		sb.add_child(cs)
		U.cyl(sb, 0.16, 0.2, 0.7, Color("#d00000"), Vector3(0, 0.35, 0), 8)
		U.sphere(sb, 0.17, Color("#d00000"), Vector3(0, 0.7, 0))
		add_child(sb)
		return
	var rb := RigidBody3D.new()
	rb.position = pos
	rb.collision_layer = 8
	rb.collision_mask = 1 | 2 | 4 | 8
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	match kind:
		"cone":
			rb.mass = 2.0
			sh.size = Vector3(0.4, 0.7, 0.4)
			U.cyl(rb, 0.03, 0.22, 0.7, Color("#ff7b00"), Vector3(0, 0.35, 0), 10)
			U.cyl(rb, 0.12, 0.15, 0.12, Color("#ffffff"), Vector3(0, 0.4, 0), 10)
			U.box(rb, Vector3(0.5, 0.05, 0.5), Color("#ff7b00"), Vector3(0, 0.025, 0))
		"bin":
			rb.mass = 6.0
			sh.size = Vector3(0.6, 1.0, 0.6)
			U.cyl(rb, 0.3, 0.27, 1.0, Color("#2d6a4f"), Vector3(0, 0.5, 0), 10)
			U.cyl(rb, 0.32, 0.32, 0.06, Color("#1b4332"), Vector3(0, 1.02, 0), 10)
		_:
			rb.mass = 5.0
			sh.size = Vector3(0.8, 0.8, 0.8)
			U.box(rb, Vector3(0.8, 0.8, 0.8), Color("#bc8a5f"), Vector3(0, 0.4, 0))
			U.box(rb, Vector3(0.82, 0.12, 0.82), Color("#8b5e34"), Vector3(0, 0.4, 0))
	cs.shape = sh
	cs.position = Vector3(0, sh.size.y * 0.5, 0)
	rb.add_child(cs)
	add_child(rb)


func _make_arrow() -> Node3D:
	var a := Node3D.new()
	var body := U.box(a, Vector3(0.18, 0.06, 0.7), Color("#06d6a0"), Vector3(0, 0, 0.1))
	body.material_override = U.mat(Color("#06d6a0"), true)
	var head := U.cyl(a, 0.0, 0.3, 0.45, Color("#06d6a0"), Vector3(0, 0, -0.45), 3)
	head.rotation.x = -PI / 2
	head.material_override = U.mat(Color("#06d6a0"), true)
	return a


func _spawn_npcs() -> void:
	var ncars := 6 if not "traffic" in run.chaos else 14
	var n: int = city.n
	for i in ncars:
		var car := Npcs.Car.new()
		var col := Color.from_hsv(rng.randf(), 0.6, 0.9)
		car.setup(n, Vector2i(rng.randi_range(0, n), rng.randi_range(0, n)), col, rng.randi())
		car.scooter = scooter
		car.honk.connect(func(_c): audio.play("horn", 0.3))
		add_child(car)
		cars.append(car)
	if "dogs" in run.chaos:
		for i in 3:
			var d := Npcs.Dog.new()
			var lot: Dictionary = city.lots[rng.randi() % city.lots.size()]
			d.setup(lot.curb + Vector3(0, 0.3, 0))
			d.scooter = scooter
			d.bit.connect(_on_dog_bite)
			add_child(d)
			dogs.append(d)


# ---------------------------------------------------------------- orders

func _spawn_offer() -> void:
	var food := run.pick_food()
	var rest := CityGen.rest_for(city, food)
	var cust := rest
	var tries := 0
	while (cust == rest or city.lots[cust].rest != "" or _customer_busy(cust)) and tries < 50:
		cust = rng.randi() % city.lots.size()
		tries += 1
	var quirk := run.pick_quirk()
	var dist: float = city.lots[rest].curb.distance_to(city.lots[cust].curb)
	var total := dist / 9.0 + 22.0
	if food == "cake":
		total += 15.0
	if quirk == "impatient":
		total *= 0.6
	orders.append({"id": next_order_id, "food": food, "rest": rest, "cust": cust, "quirk": quirk,
		"state": "offer", "t_total": total, "t_left": total, "crashed": false})
	next_order_id += 1
	_refresh_beacons()


func _customer_busy(cust: int) -> bool:
	for o in orders:
		if o.cust == cust and o.state in ["offer", "carry"]:
			return true
	return false


func order_by_id(id: int) -> Dictionary:
	for o in orders:
		if o.id == id:
			return o
	return {}


func active_orders() -> Array:
	return orders.filter(func(o): return o.state in ["offer", "carry"])


func _target_point(o: Dictionary) -> Vector3:
	var lot: Dictionary = city.lots[o.cust]
	return lot.roof if o.quirk == "rooftop" else lot.balcony


func _refresh_beacons() -> void:
	var want := {}
	for o in active_orders():
		if o.state == "offer":
			want["r%d" % o.rest] = {"pos": city.lots[o.rest].curb, "color": Color("#ff9f1c"), "text": _rest_name(city.lots[o.rest].rest)}
		else:
			var lot: Dictionary = city.lots[o.cust]
			var txt := Game.food_name(o.food).to_upper()
			if o.quirk != "":
				txt += "\n" + Game.t("quirk_" + o.quirk)
			want["c%d" % o.id] = {"pos": lot.curb, "color": Color("#06d6a0"), "text": txt, "target": _target_point(o)}
	for k in beacons.keys():
		if not want.has(k):
			beacons[k].queue_free()
			beacons.erase(k)
	for k in want:
		if beacons.has(k):
			continue
		var w: Dictionary = want[k]
		var b := Node3D.new()
		b.position = w.pos
		var col: Color = w.color
		var beam := U.cyl(b, 1.6, 1.6, 40.0, col, Vector3(0, 20, 0), 20)
		beam.material_override = U.mat(Color(col.r, col.g, col.b, 0.22), true)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 3.0
		tm.outer_radius = 3.4
		ring.mesh = tm
		ring.material_override = U.mat(col, true)
		ring.position = Vector3(0, 0.25, 0)
		b.add_child(ring)
		U.label3d(b, w.text, Vector3(0, 4.5, 0), 96, col.lightened(0.3))
		if w.has("target"):
			var tr := MeshInstance3D.new()
			var tt := TorusMesh.new()
			tt.inner_radius = 1.0
			tt.outer_radius = 1.3
			tr.mesh = tt
			tr.material_override = U.mat(Color("#ffd60a"), true)
			tr.position = (w.target as Vector3) - b.position + Vector3(0, 0.2, 0)
			b.add_child(tr)
		add_child(b)
		beacons[k] = b


# ---------------------------------------------------------------- loop

func _physics_process(dt: float) -> void:
	if not running:
		return
	clock += dt
	time_left -= dt
	if time_left <= 0.0:
		_end_shift()
		return
	offer_timer -= dt
	var n_offers := orders.filter(func(o): return o.state == "offer").size()
	if (offer_timer <= 0.0 and n_offers < 3) or n_offers == 0:
		offer_timer = rng.randf_range(7.0, 12.0)
		_spawn_offer()
	for o in orders:
		if o.state == "carry":
			o.t_left -= dt
	var sp := absf(scooter.speed)
	var pos := scooter.global_position
	if not scooter.is_crashed:
		_check_pickups(pos, sp)
		_check_hand_delivery(pos, sp)
		_check_loose_pickup(pos, sp)
	_check_loose()
	_chaos_tick(dt, sp)
	if scooter.controls_enabled and not scooter.is_crashed:
		if Input.is_action_just_pressed("solo_throw") and not coop or Input.is_action_just_pressed("p2_throw"):
			throw_top()
	_update_arrow()
	if rain:
		rain.global_position = camera.global_position + Vector3(0, 8, 0) - camera.global_basis.z * 8.0
	audio.engine(scooter.speed, scooter.throttle)


func _check_pickups(pos: Vector3, sp: float) -> void:
	if sp > 4.5:
		return
	for o in orders:
		if o.state != "offer":
			continue
		var curb: Vector3 = city.lots[o.rest].curb
		if pos.distance_to(curb) < 5.0:
			if scooter.rack.is_full():
				hud.popup(Game.t("capacity"), Color("#ffd166"))
				continue
			var it := FoodItem.new(o.food)
			it.order_id = o.id
			scooter.rack.add_item(it)
			o.state = "carry"
			audio.play("pickup")
			_refresh_beacons()


func _check_hand_delivery(pos: Vector3, sp: float) -> void:
	if sp > 4.0:
		return
	for it in scooter.rack.items.duplicate():
		var o := order_by_id(it.order_id)
		if o.is_empty() or o.state != "carry":
			continue
		if pos.distance_to(city.lots[o.cust].curb) < 5.0:
			scooter.rack.remove_item(it)
			_deliver(o, it, false)


func _check_loose_pickup(pos: Vector3, sp: float) -> void:
	var r: float = mods.get("pickup_radius", 2.5)
	var pressed := request_pickup or Input.is_action_just_pressed("p2_pickup") or (not coop and Input.is_action_just_pressed("solo_pickup"))
	request_pickup = false
	for lf in loose.duplicate():
		if not is_instance_valid(lf) or lf.age < 0.8:
			continue
		var d: float = lf.global_position.distance_to(pos)
		if (d < 2.6 and sp < 6.0) or (pressed and d < r + 1.0):
			if scooter.rack.is_full():
				continue
			loose.erase(lf)
			scooter.rack.add_item(lf.item)
			lf.queue_free()
			audio.play("pickup")


func _check_loose() -> void:
	for lf in loose.duplicate():
		if not is_instance_valid(lf):
			loose.erase(lf)
			continue
		var it: FoodItem = lf.item
		var o := order_by_id(it.order_id)
		if lf.global_position.y < -5.0:
			loose.erase(lf)
			lf.queue_free()
			if not o.is_empty():
				o.state = "lost"
			_refresh_beacons()
			continue
		if o.is_empty() or o.state != "carry":
			continue
		var tgt := _target_point(o)
		if lf.thrown and lf.global_position.distance_to(tgt) < 2.0:
			loose.erase(lf)
			_deliver(o, it, true, lf.global_position)
			lf.queue_free()
		elif lf.global_position.distance_to(city.lots[o.cust].door) < 3.0 and lf.linear_velocity.length() < 1.0 and lf.age > 1.0:
			loose.erase(lf)
			_deliver(o, it, false, lf.global_position)
			lf.queue_free()


func _deliver(o: Dictionary, it: FoodItem, thrown: bool, at := Vector3.INF) -> void:
	o.state = "done"
	if clock - last_delivery_time < 25.0:
		combo += 1
	else:
		combo = 0
	last_delivery_time = clock
	var ctx := {"time_left": o.t_left, "time_total": o.t_total, "thrown": thrown, "crashed": o.crashed,
		"combo": combo, "quirk": o.quirk, "mods": mods}
	var res := Tips.compute(it, ctx)
	var rv := Reviews.make(it.kind, res.tags, Game.lang(), rng)
	rv.stars = res.stars
	rv.tip = res.tip
	rv.food = it.kind
	rv.heat = it.heat
	rv.integrity = it.integrity
	rv.day = run.day
	reviews.append(rv)
	run.add_tip(res.tip)
	if thrown:
		run.stats.throws += 1
	if it.spilled:
		run.stats.spilled += 1
	hud.review(rv)
	var txt := "+$%d" % res.tip
	if combo > 0:
		txt += "  x%d COMBO" % (combo + 1)
	hud.popup(txt, Color("#06d6a0"), true)
	audio.play("cash")
	if thrown:
		audio.play("cheer")
		camera.add_trauma(0.3)
	_confetti(at if at != Vector3.INF else scooter.global_position + Vector3.UP)
	_refresh_beacons()


func throw_top() -> void:
	var it := scooter.rack.top()
	if it == null:
		return
	var vis: Node3D = scooter.rack.visuals.back()
	var start := vis.global_position + Vector3.UP * 0.3
	var o := order_by_id(it.order_id)
	var vel: Vector3
	var aimed := false
	if not o.is_empty() and o.state == "carry":
		var tgt := _target_point(o) + Vector3.UP * 0.4
		var flat := Vector3(tgt.x - start.x, 0, tgt.z - start.z)
		if flat.length() < 32.0:
			var T := clampf(flat.length() / 11.0, 0.6, 1.5)
			var err: float = (0.35 + absf(scooter.speed) * 0.07 + scooter.rack.top_tilt().length() * 2.0) / mods.get("throw_accuracy", 1.0)
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)).normalized() * rng.randf() * err
			vel = (tgt + off - start) / T + Vector3(0, 4.9 * T, 0)
			aimed = true
	if not aimed:
		vel = scooter.linear_velocity - scooter.global_basis.z * 7.0 + Vector3.UP * 6.0
	scooter.rack.remove_item(it)
	var lf := _spawn_loose(it, vis.global_transform, vel)
	lf.global_position = start
	lf.thrown = aimed
	lf.angular_velocity = Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), rng.randf_range(-3, 3))
	audio.play("throw")


func _spawn_loose(it: FoodItem, xf: Transform3D, vel: Vector3) -> LooseFood:
	var lf := LooseFood.new()
	lf.setup(it)
	add_child(lf)
	lf.global_transform = xf
	lf.linear_velocity = vel
	lf.landed.connect(_on_landed)
	loose.append(lf)
	return lf


func _on_item_fell(it: FoodItem, xf: Transform3D, vel: Vector3) -> void:
	debug_log.falls += 1
	_spawn_loose(it, xf, vel)
	hud.popup(Game.t("fell"), Color("#ef476f"))
	audio.play("fall")
	camera.add_trauma(0.25)


func _on_landed(lf: LooseFood, speed: float) -> void:
	if speed > 3.0:
		audio.play("splat" if lf.item.is_liquid() else "thud")
		if lf.item.is_liquid():
			_splat(lf.global_position, FoodVisual.COLORS.get(lf.item.kind, Color.ORANGE))


var _spill_acc := 0.0
var _last_spill_popup := -10.0


func _on_spilled(it: FoodItem, amount: float) -> void:
	_spill_acc += amount
	if _spill_acc > 4.0:
		_spill_acc = 0.0
		if clock - _last_spill_popup > 1.5:
			_last_spill_popup = clock
			hud.popup(Game.t("spill"), Color("#f77f00"))
			audio.play("splash")
		_drip(scooter.rack.global_position + Vector3.UP * 0.3, FoodVisual.COLORS.get(it.kind, Color.ORANGE))


func _on_crash(_s: Scooter) -> void:
	debug_log.crash_speeds.append(snappedf(_s._prev_vel.length(), 0.1))
	run.stats.crashes += 1
	for o in orders:
		if o.state == "carry":
			o.crashed = true
	hud.popup(Game.t("crash"), Color("#ef476f"), true)
	audio.play("crash")
	camera.add_trauma(0.9)


var debug_log := {"jolts": [], "falls": 0, "crash_speeds": []}


func _on_jolt(s: float) -> void:
	debug_log.jolts.append(snappedf(s, 0.1))
	if s > 2.5:
		camera.add_trauma(minf(0.4, s * 0.05))
		audio.play("bump")


func _on_honk(_s: Scooter) -> void:
	audio.play("horn")
	var power: float = mods.get("horn_power", 0.0)
	if power <= 0.0:
		return
	for c in get_children():
		if c is RigidBody3D and c != scooter and c.global_position.distance_to(scooter.global_position) < 12.0:
			(c as RigidBody3D).apply_central_impulse((c.global_position - scooter.global_position).normalized() * 30.0 * (c as RigidBody3D).mass * 0.2 + Vector3.UP * 3.0)


func _on_dog_bite(_d: Node3D) -> void:
	audio.play("bark")
	scooter.rack.jolt(4.5)
	for it in scooter.rack.items:
		it.tilt_vel += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 2.0
	hud.popup("WOOF!", Color("#ffd166"))


func _chaos_tick(dt: float, sp: float) -> void:
	if "wind" in run.chaos:
		gust_timer -= dt
		if gust_timer <= 0.0:
			gust_timer = rng.randf_range(5.0, 9.0)
			var g := Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3)) * 2.4
			for it in scooter.rack.items:
				it.tilt_vel += g
			if scooter.rack.items.size() > 0:
				hud.popup("WHOOSH!", Color("#a8dadc"))
				audio.play("wind")
	if "pigeons" in run.chaos and not pigeon_busy:
		if sp < 2.0 and scooter.rack.items.size() > 0:
			still_time += dt
			if still_time > 2.5:
				still_time = 0.0
				_pigeon_attack()
		else:
			still_time = 0.0


func _pigeon_attack() -> void:
	pigeon_busy = true
	var bird := Node3D.new()
	U.sphere(bird, 0.18, Color("#8d99ae"), Vector3.ZERO).scale = Vector3(1, 0.8, 1.4)
	U.sphere(bird, 0.1, Color("#5c677d"), Vector3(0, 0.12, -0.2))
	U.box(bird, Vector3(0.6, 0.03, 0.2), Color("#8d99ae"), Vector3(0, 0.05, 0))
	add_child(bird)
	var top: Vector3 = scooter.rack.global_position + Vector3.UP * 0.6
	bird.global_position = top + Vector3(8, 10, 6)
	audio.play("coo")
	var tw := create_tween()
	tw.tween_property(bird, "global_position", top, 1.0)
	tw.tween_callback(func():
		var it := scooter.rack.top()
		if it:
			it.integrity = maxf(0.0, it.integrity - 18.0)
			it.dropped = true
			it.tilt_vel += Vector2(1.5, 0.5)
			hud.popup("PIGEON!", Color("#8d99ae"))
	)
	tw.tween_property(bird, "global_position", top + Vector3(-10, 12, -8), 1.2)
	tw.tween_callback(func():
		bird.queue_free()
		pigeon_busy = false
	)


func _update_arrow() -> void:
	var pos := scooter.global_position
	arrow.global_position = pos + Vector3.UP * 2.6
	var best := Vector3.INF
	var bd := 1e9
	for it in scooter.rack.items:
		var o := order_by_id(it.order_id)
		if not o.is_empty():
			var p: Vector3 = city.lots[o.cust].curb
			if p.distance_to(pos) < bd:
				bd = p.distance_to(pos)
				best = p
	if best == Vector3.INF:
		for lf in loose:
			if is_instance_valid(lf) and lf.global_position.distance_to(pos) < bd:
				bd = lf.global_position.distance_to(pos)
				best = lf.global_position
	if best == Vector3.INF and not scooter.rack.is_full():
		for o in orders:
			if o.state == "offer":
				var p: Vector3 = city.lots[o.rest].curb
				if p.distance_to(pos) < bd:
					bd = p.distance_to(pos)
					best = p
	arrow.visible = best != Vector3.INF and bd > 6.0
	if arrow.visible:
		var flat := Vector3(best.x, arrow.global_position.y, best.z)
		if flat.distance_to(arrow.global_position) > 0.1:
			arrow.look_at(flat, Vector3.UP)


# ---------------------------------------------------------------- fx

func _burst(pos: Vector3, c: Color, amount: int, speed: float, size: float, life: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	m.material = U.mat(c)
	p.mesh = m
	add_child(p)
	p.global_position = pos
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func _confetti(pos: Vector3) -> void:
	for c in [Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"), Color("#118ab2")]:
		_burst(pos, c, 12, 8.0, 0.12, 1.4)


func _drip(pos: Vector3, c: Color) -> void:
	_burst(pos, c, 10, 3.0, 0.08, 0.8)


func _splat(pos: Vector3, c: Color) -> void:
	_burst(pos, c, 24, 5.0, 0.1, 0.9)
	var decal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rng.randf_range(0.6, 1.0)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.01
	decal.mesh = cm
	decal.material_override = U.mat(c.darkened(0.1))
	add_child(decal)
	decal.global_position = Vector3(pos.x, 0.02 if pos.y < 0.3 else pos.y - 0.1, pos.z)


# ---------------------------------------------------------------- end

func _end_shift() -> void:
	running = false
	scooter.controls_enabled = false
	audio.music(false)
	audio.play("whistle")
	var top := reviews.duplicate()
	top.sort_custom(func(a, b): return Reviews.funny_score(a.tag, a.stars) > Reviews.funny_score(b.tag, b.stars))
	shift_ended.emit({"reviews": reviews, "top": top.slice(0, 3), "earned": run.earned_today})


func pause(p: bool) -> void:
	get_tree().paused = p
