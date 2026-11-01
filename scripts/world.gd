class_name World
extends Node3D
## One shift: builds the city, spawns the scooter, runs orders/deliveries.

signal shift_ended(result: Dictionary)



var run: RunState
var city: Dictionary
var coop := false
var split := false        # two scooters, split screen
var client := false       # online client: draws host snapshots, simulates nothing
var local_index := 0
var netsync: NetSync
var has_cook := false
var tutorial := false     # first run: guided hints
var _tut_step := 0     # an online player cooks: orders must be prepared before pickup
var scooters: Array = []
var cameras: Array = []
var arrows: Array = []
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
var walkers: Array = []
var _bmats := {}
var audio: Sfx
var arrow: Node3D
var rain: CPUParticles3D


func setup(r: RunState, coop_mode: bool, split_mode := false) -> void:
	run = r
	coop = coop_mode
	split = split_mode
	mods = run.mods()
	rng.seed = run.seed_value * 1000 + run.day
	var bumps := 8 + (30 if "bumps" in run.chaos else 0)
	city = CityGen.generate(run.seed_value, 5, bumps, run.theme)
	time_left = run.shift_length()


func _ready() -> void:
	audio = Sfx.new()
	add_child(audio)
	_build_environment()
	_build_city()
	_merge_static()
	var ids: Array = Net.drivers() if Net.online else []
	var count := ids.size() if Net.online else (2 if split else 1)
	local_index = Net.my_index() if Net.online else 0
	has_cook = Net.online and Net.cooks().size() > 0
	client = Net.online and not Net.is_host()
	for i in count:
		var s := Scooter.new()
		s.index = i
		s.team = (Net.team_of(ids[i]) if Net.online else i % 2) if run.competitive() else 0
		s.mods = run.mods(s.team) if run.competitive() else mods
		s.coop = coop
		s.split = split
		s.player = i
		if i == 1:
			s.color = Color("#4361ee")
		if Net.online:
			var info: Dictionary = Net.players[ids[i]]
			s.player = 0
			s.look = info.get("look", Courier.default_look(i))
			s.color = Color(Game.SCOOTER_COLORS[int(info.get("color", i)) % Game.SCOOTER_COLORS.size()])
			s.remote = ids[i] != Net.my_id() and not client
			s.passenger_ids = Net.order().filter(func(p): return Net.is_passenger(p) and Net.ride_target(p) == i)
			s.name = "Scooter%d" % i
		add_child(s)
		_name_tag(s, Game.player_name(i) if not Net.online else str(Net.players[ids[i]].get("name", "?")))
		for pid in s.passenger_ids:
			s.add_passenger_visual(Net.players[pid].get("look", {}))
		if client:
			s.freeze = true
			s.set_physics_process(false)
		s.global_position = city.spawn + Vector3(3.0 * i, 0, 0)
		s.headlight.visible = night > 0.1
		s.rack.item_fell.connect(_on_item_fell)
		s.rack.spilled.connect(_on_spilled)
		s.crashed.connect(_on_crash)
		s.honked.connect(_on_honk)
		s.jolted.connect(_on_jolt)
		scooters.append(s)
		var a := _make_arrow()
		add_child(a)
		arrows.append(a)
	scooter = scooters[local_index]
	arrow = arrows[local_index]
	if Net.online:
		netsync = NetSync.new()
		netsync.world = self
		add_child(netsync)
		if not client:
			audio.forward = func(n: String): netsync.send_fx("sfx", [n])
	if split:
		_build_split_screen()
	else:
		camera = ChaseCamera.new()
		camera.target = scooter
		add_child(camera)
		camera.current = true
		camera.snap()
		cameras = [camera]
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_spawn_npcs()
	if client:
		for n in cars + dogs + walkers:
			n.set_physics_process(false)
		audio.music(true)
		return
	if run.big_order_day():
		_spawn_offer("cake")
		hud.popup(Game.t("big_order"), UiKit.GOLD, true, 4.0, 120.0)
	for i in 2:
		_spawn_offer()
	running = true
	tutorial = run.day == 1 and int(Game.save.runs) <= 1 and not Net.online and not run.competitive()
	audio.music(true)


# ---------------------------------------------------------------- building

var night := 0.0
var lamps: Array = []


func _build_environment() -> void:
	var r := Look.environment(self, run.tod, city.theme, run.chaos)
	env = r.env
	night = r.night
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
	if not _bmats.has(hex):
		_bmats[hex] = Look.building_mat(Color(hex), night, float(_bmats.size()) * 3.7)
	return _bmats[hex]


func _build_city() -> void:
	var size: float = city.size
	var half_road := CityGen.ROAD * 0.5
	# ground
	var g := U.static_box(self, Vector3(size + 60, 1, size + 60), Color(city.theme.ground), Vector3(size * 0.5, -0.5, size * 0.5))
	g.collision_layer = 1
	(g.get_child(1) as MeshInstance3D).material_override = Look.road_mat("rain" in run.chaos)
	# grass outside city
	U.box(self, Vector3(size + 400, 0.9, size + 400), Color(city.theme.outer), Vector3(size * 0.5, -0.52, size * 0.5))
	# boundary walls
	for w in [[Vector3(size * 0.5, 1, -half_road - 0.5), Vector3(size + 14, 2, 1)],
			[Vector3(size * 0.5, 1, size + half_road + 0.5), Vector3(size + 14, 2, 1)],
			[Vector3(-half_road - 0.5, 1, size * 0.5), Vector3(1, 2, size + 14)],
			[Vector3(size + half_road + 0.5, 1, size * 0.5), Vector3(1, 2, size + 14)]]:
		U.static_box(self, w[1], Color("#e9c46a"), w[0])
	# lane dashes + crosswalks, batched into one MultiMesh each (thousands of stripes, one draw call)
	var n: int = city.n
	var dashes := []
	var stripes := []
	for i in n + 1:
		for j in n:
			for k in 4:
				var t := (j + 0.5) * CityGen.PITCH + (k - 1.5) * 8.0
				dashes.append(Transform3D(Basis.IDENTITY, Vector3(i * CityGen.PITCH, 0.01, t)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(t, 0.01, i * CityGen.PITCH)))
	for i in n + 1:
		for j in n + 1:
			var c := Vector3(i * CityGen.PITCH, 0.012, j * CityGen.PITCH)
			for side in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
				var across := Vector3(side.z, 0, side.x)
				for s in 6:
					var p: Vector3 = c + side * 7.5 + across * ((s - 2.5) * 1.6)
					stripes.append(Transform3D(Basis(Vector3.UP, atan2(side.x, side.z)), p))
	_multimesh(dashes, Vector3(0.25, 0.02, 3.0), Color("#f1faee"))
	_multimesh(stripes, Vector3(0.8, 0.02, 2.6), Color("#f8f9fa"))
	# parked cars along the curbs
	for k in 18:
		var b: Dictionary = city.blocks[rng.randi() % city.blocks.size()]
		var side := rng.randi() % 4
		var off := CityGen.BLOCK * 0.5 + 1.4
		var t := rng.randf_range(-12, 12)
		var pos: Vector3 = b.center + [Vector3(off, 0, t), Vector3(-off, 0, t), Vector3(t, 0, off), Vector3(t, 0, -off)][side]
		var pc := StaticBody3D.new()
		pc.position = pos
		pc.rotation.y = 0.0 if side < 2 else PI / 2
		var pcs := CollisionShape3D.new()
		var psh := BoxShape3D.new()
		psh.size = Vector3(2.0, 1.5, 4.0)
		pcs.shape = psh
		pcs.position = Vector3(0, 0.95, 0)
		pc.add_child(pcs)
		Npcs.car_body(pc, Color.from_hsv(rng.randf(), 0.55, 0.85))
		add_child(pc)
	# blocks
	for b in city.blocks:
		var c: Vector3 = b.center
		var col := (Color("#74c69d") if run.theme != "beach" else Color("#f4e1a1")) if b.park else Color(city.theme.walk)
		var slab := U.static_box(self, Vector3(CityGen.BLOCK, 0.15, CityGen.BLOCK), col, c + Vector3(0, 0.075, 0))
		(slab.get_child(1) as MeshInstance3D).material_override = Look.tile_mat(col, b.park and run.theme != "beach")
		_street_furniture(c)
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
		var leaf := Color("#52b788").lerp(Color("#2d6a4f"), rng.randf())
		U.sphere(tr, 1.3, leaf, Vector3(0, 3.0, 0))
		U.sphere(tr, 0.9, leaf.lightened(0.1), Vector3(0.6, 3.6, 0.2))
		U.sphere(tr, 0.8, leaf.darkened(0.1), Vector3(-0.5, 3.4, -0.4))
		add_child(tr)
	_backdrop()
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


## Curbs, lamp posts at block corners, benches. Lamps light up at night.
func _street_furniture(c: Vector3) -> void:
	var h := CityGen.BLOCK * 0.5
	for e in [[Vector3(0, 0.08, h), Vector3(CityGen.BLOCK, 0.17, 0.25)], [Vector3(0, 0.08, -h), Vector3(CityGen.BLOCK, 0.17, 0.25)],
			[Vector3(h, 0.08, 0), Vector3(0.25, 0.17, CityGen.BLOCK)], [Vector3(-h, 0.08, 0), Vector3(0.25, 0.17, CityGen.BLOCK)]]:
		U.box(self, e[1], Color("#d9d9d9"), c + e[0])
	for k in [Vector3(1, 0, 1), Vector3(-1, 0, -1)]:
		var p: Vector3 = c + k * (h - 0.8)
		var lamp := Node3D.new()
		lamp.position = p
		add_child(lamp)
		U.cyl(lamp, 0.07, 0.1, 5.0, Color("#2b2d42"), Vector3(0, 2.6, 0), 8)
		U.box(lamp, Vector3(0.08, 0.08, 1.2), Color("#2b2d42"), Vector3(0, 5.1, -0.5 * k.z))
		var bulb := U.sphere(lamp, 0.22, Color("#fff3b0"), Vector3(0, 4.95, -1.0 * k.z))
		if night > 0.1:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#fff3b0")
			mat.emission_enabled = true
			mat.emission = Color("#ffcf7a")
			mat.emission_energy_multiplier = 4.0
			bulb.material_override = mat
			var l := OmniLight3D.new()
			l.light_color = Color("#ffcf7a")
			l.light_energy = 2.5 * night
			l.omni_range = 14.0
			l.position = Vector3(0, 4.6, -1.0 * k.z)
			lamp.add_child(l)
			lamps.append(l)
	if rng.randf() < 0.5:
		var bench := Node3D.new()
		bench.position = c + Vector3(rng.randf_range(-10, 10), 0.15, h - 1.2)
		add_child(bench)
		U.box(bench, Vector3(1.8, 0.08, 0.5), Color("#8b5e34"), Vector3(0, 0.45, 0))
		U.box(bench, Vector3(1.8, 0.5, 0.08), Color("#8b5e34"), Vector3(0, 0.75, 0.22))
		for x in [-0.8, 0.8]:
			U.box(bench, Vector3(0.06, 0.45, 0.45), Color("#2b2d42"), Vector3(x, 0.22, 0))


## Merge static city meshes per material: ~3000 draw calls -> a few hundred.
func _merge_static() -> void:
	var list := []
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.get_child_count() > 0 or mi.mesh == null or mi.material_override == null or mi.mesh.get_surface_count() != 1:
			continue
		var p: Node = mi.get_parent()
		var dynamic := false
		while p and p != self:
			if p is RigidBody3D or p is CharacterBody3D or p is AnimatableBody3D:
				dynamic = true
				break
			p = p.get_parent()
		if not dynamic:
			list.append(mi)
	# split by 3x3 city chunk so merged pieces can still be frustum/occlusion culled
	var cs: float = city.size / 3.0
	var chunk_of := func(mi: Node3D) -> int:
		var gp: Vector3 = mi.global_position
		return clampi(int(gp.x / cs), -1, 3) * 10 + clampi(int(gp.z / cs), -1, 3)
	for m in U.merge(list, self, chunk_of):
		add_child(m)
	for mi in list:
		mi.get_parent().remove_child(mi)
		mi.queue_free()


## Distant skyline, sea (beach) and park grass: depth beyond the playable grid.
func _backdrop() -> void:
	var size: float = city.size
	var mid := Vector3(size * 0.5, 0, size * 0.5)
	var beach := run.theme == "beach"
	var tall := 3.0 if run.theme == "downtown" else 1.0
	var pal: Array = city.theme.palette
	for i in 90:
		var a := TAU * i / 90.0 + rng.randf_range(-0.03, 0.03)
		var r := size * 0.5 + rng.randf_range(45.0, 140.0)
		var p := mid + Vector3(cos(a), 0, sin(a)) * r
		if beach and cos(a) > 0.3:
			continue   # leave the sea side open
		var w := rng.randf_range(10, 22)
		var h := rng.randf_range(8, 26) * tall * (1.0 if rng.randf() > 0.15 else 2.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, w)
		mi.mesh = bm
		mi.material_override = _bmat(pal[rng.randi() % pal.size()])
		mi.position = p + Vector3(0, h * 0.5 - 0.5, 0)
		mi.rotation.y = rng.randf() * PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	if beach:
		var sea := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(600, 900)
		pm.subdivide_width = 60
		pm.subdivide_depth = 90
		sea.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = Look.shader(Look.WATER_SHADER)
		sea.material_override = m
		sea.position = Vector3(size + 40.0 + 300.0, -0.35, size * 0.5)
		add_child(sea)
	# grass tufts in parks
	var tufts := []
	for b in city.blocks:
		if not b.park or beach:
			continue
		for i in 260:
			var p: Vector3 = b.center + Vector3(rng.randf_range(-16, 16), 0.15, rng.randf_range(-16, 16))
			tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.3)), p + Vector3(0, 0.12, 0)))
	if tufts.size() > 0:
		_multimesh(tufts, Vector3(0.08, 0.25, 0.4), Color("#40916c"))


func _multimesh(xforms: Array, size: Vector3, c: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = U.mat(c)
	mm.mesh = bm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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
	var occ := OccluderInstance3D.new()   # buildings hide whatever is behind them
	var bo := BoxOccluder3D.new()
	bo.size = s * 0.96
	occ.occluder = bo
	sb.add_child(occ)
	_roof_details(c + Vector3(0, 0.15, 0), s, Color(lot.color))
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


## Parapet, plinth, AC units, water tanks and antennas: cheap silhouettes that sell the city.
func _roof_details(base: Vector3, s: Vector3, c: Color) -> void:
	var top := base + Vector3(0, s.y, 0)
	var trim := c.darkened(0.3)
	for e in [[Vector3(0, 0.25, s.z * 0.5), Vector3(s.x + 0.2, 0.5, 0.25)], [Vector3(0, 0.25, -s.z * 0.5), Vector3(s.x + 0.2, 0.5, 0.25)],
			[Vector3(s.x * 0.5, 0.25, 0), Vector3(0.25, 0.5, s.z)], [Vector3(-s.x * 0.5, 0.25, 0), Vector3(0.25, 0.5, s.z)]]:
		U.box(self, e[1], trim, top + e[0])
	U.box(self, Vector3(s.x + 0.12, 0.6, s.z + 0.12), c.darkened(0.45), base + Vector3(0, 0.3, 0))   # plinth
	var k := rng.randi() % 4
	for i in k:
		var p := top + Vector3(rng.randf_range(-s.x, s.x) * 0.3, 0, rng.randf_range(-s.z, s.z) * 0.3)
		match rng.randi() % 3:
			0:
				U.box(self, Vector3(1.2, 0.8, 0.9), Color("#ced4da"), p + Vector3(0, 0.4, 0))
				U.cyl(self, 0.3, 0.3, 0.05, Color("#495057"), p + Vector3(0, 0.83, 0), 10)
			1:
				U.cyl(self, 0.7, 0.7, 1.4, Color("#8d6e63"), p + Vector3(0, 1.6, 0), 12)
				U.cyl(self, 0.0, 0.75, 0.4, Color("#5d4037"), p + Vector3(0, 2.5, 0), 12)
				for a in 4:
					U.cyl(self, 0.05, 0.05, 1.0, Color("#3e2723"), p + Vector3(cos(a * PI / 2) * 0.5, 0.5, sin(a * PI / 2) * 0.5), 4)
			2:
				U.cyl(self, 0.03, 0.03, 2.5, Color("#6c757d"), p + Vector3(0, 1.25, 0), 4)
				U.box(self, Vector3(0.9, 0.04, 0.04), Color("#6c757d"), p + Vector3(0, 2.1, 0))


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
	U.bake(rb)
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
	var ncars: int = (6 if not "traffic" in run.chaos else 14) + int(city.theme.cars)
	var n: int = city.n
	for i in ncars:
		var car := Npcs.Car.new()
		var col := Color.from_hsv(rng.randf(), 0.6, 0.9)
		car.setup(n, Vector2i(rng.randi_range(0, n), rng.randi_range(0, n)), col, rng.randi())
		car.scooter = scooter
		car.world_ref = self
		U.bake(car)
		car.honk.connect(func(_c): audio.play("horn", 0.3))
		add_child(car)
		cars.append(car)
	var blocks: Array = city.blocks
	for i in 14:
		var b: Dictionary = blocks[rng.randi() % blocks.size()]
		var wk := Npcs.Walker.new()
		var look := {"skin": rng.randi() % 6, "jacket": rng.randi() % 9, "helmet": [7, 4, 2, 7][rng.randi() % 4], "helmet_color": rng.randi() % 9, "accessory": rng.randi() % 6}
		add_child(wk)
		wk.setup(b.center, look, rng.randf() * 120.0, 1.0 if rng.randf() < 0.5 else -1.0)
		wk.world_ref = self
		U.bake(wk.body)
		wk.bumped.connect(_on_walker_bumped)
		walkers.append(wk)
	if "dogs" in run.chaos:
		for i in 3:
			var d := Npcs.Dog.new()
			var lot: Dictionary = city.lots[rng.randi() % city.lots.size()]
			d.setup(lot.curb + Vector3(0, 0.3, 0))
			d.scooter = scooter
			d.world_ref = self
			d.bit.connect(_on_dog_bite)
			add_child(d)
			dogs.append(d)


# ---------------------------------------------------------------- orders

func _spawn_offer(food := "", special := "") -> void:
	if food == "":
		food = run.pick_food()
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
	if special == "rush":
		quirk = "vip"
		total = minf(total, 30.0)
	total *= float(mods.get("timer_mult", 1.0))
	orders.append({"id": next_order_id, "food": food, "rest": rest, "cust": cust, "quirk": quirk,
		"state": "offer", "t_total": total, "t_left": total, "crashed": false, "ready": not has_cook, "q": 1.0})
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
			var ready: bool = o.get("ready", true)
			var key := "r%d_%s" % [o.rest, ready]
			if ready or not want.has("r%d_true" % o.rest):
				want[key] = {"pos": city.lots[o.rest].curb, "color": Game.beacon_color("rest") if ready else Color("#adb5bd"),
					"text": _rest_name(city.lots[o.rest].rest) + ("" if ready else "\n" + Game.t("cooking"))}
		else:
			var lot: Dictionary = city.lots[o.cust]
			var txt := Game.up(Game.food_name(o.food))
			if o.quirk != "":
				txt += "\n" + Game.t("quirk_" + o.quirk)
			want["c%d" % o.id] = {"pos": lot.curb, "color": Game.beacon_color("cust"), "text": txt, "target": _target_point(o)}
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

func _emote_input() -> void:
	for e in 4:
		if Input.is_action_just_pressed("emote_%d" % e):
			if client:
				netsync.emote_req.rpc_id(1, e)
			else:
				emote(local_index, e)
		if split and Input.is_action_just_pressed("p2_emote_%d" % e):
			emote(1, e)


func _physics_process(dt: float) -> void:
	if running or client:
		_emote_input()
	if client:
		_update_arrow()
		audio.engine(scooter.speed, 0.0)
		return
	if not running:
		return
	_record()
	clock += dt
	time_left -= dt
	if time_left <= 0.0:
		_end_shift()
		return
	var wet := clock < shower_until
	for sc in scooters:
		sc.mods["shower"] = wet
	event_timer -= dt
	if event_timer <= 0.0:
		event_timer = rng.randf_range(40.0, 70.0)
		_random_event()
	offer_timer -= dt
	var n_offers := orders.filter(func(o): return o.state == "offer").size()
	if (offer_timer <= 0.0 and n_offers < 3) or n_offers == 0:
		offer_timer = rng.randf_range(7.0, 12.0)
		_spawn_offer()
	for o in orders:
		if o.state == "carry":
			o.t_left -= dt
		elif has_cook and not o.get("ready", true):
			o["wait"] = float(o.get("wait", 0.0)) + dt
			if o.wait > 15.0:   # nobody cooked it: the kitchen staff does a so-so job
				cook_done(o.id, 0.6)
	_check_loose()
	# shortcut: per-scooter logic swaps the `scooter` field; signal handlers still assume scooter 0.
	for i in scooters.size():
		scooter = scooters[i]
		arrow = arrows[i]
		var sp := absf(scooter.speed)
		var pos := scooter.global_position
		if not scooter.is_crashed:
			_check_pickups(pos, sp)
			_check_hand_delivery(pos, sp)
			_check_loose_pickup(pos, sp)
		_chaos_tick(dt, sp)
		if scooter.controls_enabled and not scooter.is_crashed and _pressed("throw"):
			throw_top()
		_update_arrow()
	scooter = scooters[local_index]
	arrow = arrows[local_index]
	request_pickup = false
	if rain:
		rain.global_position = camera.global_position + Vector3(0, 8, 0) - camera.global_basis.z * 8.0
	audio.engine(scooter.speed, scooter.throttle)


func _check_pickups(pos: Vector3, sp: float) -> void:
	if sp > 4.5:
		return
	for o in orders:
		if o.state != "offer" or not o.get("ready", true):
			continue
		if int(o.get("team", -1)) >= 0 and clock < float(o.get("reserved_until", 0.0)) and int(o.team) != scooter.team:
			continue   # the other team's cook made this one
		var curb: Vector3 = city.lots[o.rest].curb
		if pos.distance_to(curb) < 5.0:
			if scooter.rack.is_full():
				hud.popup(Game.t("capacity"), Color("#ffd166"))
				continue
			var it := FoodItem.new(o.food)
			it.order_id = o.id
			var q: float = o.get("q", 1.0)   # the cook's timing sets how fresh it leaves the kitchen
			it.heat = 60.0 + 40.0 * q
			it.integrity = 70.0 + 30.0 * q
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
			if clock < elevator_until:
				# climb the stairs: stand still, or skip it all by throwing onto the balcony
				var before := int(o.get("stairs", 0.0))
				o["stairs"] = float(o.get("stairs", 0.0)) + get_physics_process_delta_time()
				if int(o.stairs) > before and int(o.stairs) < STAIRS:
					hud.popup(Game.t("stairs") % [int(o.stairs), STAIRS], Color("#c77dff"))
				if o.stairs < STAIRS:
					continue
			scooter.rack.remove_item(it)
			_deliver(o, it, false)


func nearest_scooter(p: Vector3) -> Scooter:
	var best: Scooter = scooters[0]
	for s in scooters:
		if s.global_position.distance_squared_to(p) < best.global_position.distance_squared_to(p):
			best = s
	return best


## First-run hints, one step at a time.
func _tutorial_tick() -> void:
	var rack := scooter.rack
	match _tut_step:
		0:
			hud.banner(Game.t("tut_0"))
			if rack.items.size() > 0:
				_tut_step = 1
		1:
			hud.banner(Game.t("tut_1"))
			if rack.danger() > 0.55:
				_tut_step = 2
			elif reviews.size() > 0:
				_tut_step = 3
		2:
			hud.banner(Game.t("tut_2"))
			if rack.danger() < 0.2 or reviews.size() > 0:
				_tut_step = 3 if reviews.size() > 0 else 1
		3:
			hud.banner(Game.t("tut_3"))
			if run.stats.throws > 0 or reviews.size() >= 3:
				_tut_step = 4
		_:
			hud.banner("")
			tutorial = false


## Cook finished an order (local host cook, or validated RPC from a client cook).
func cook_done(order_id: int, q: float, team := -1) -> void:
	var o := order_by_id(order_id)
	if o.is_empty() or o.state != "offer" or o.get("ready", true):
		return
	o.ready = true
	if run.competitive() and team >= 0:
		o["team"] = team
		o["reserved_until"] = clock + 12.0
	o.q = clampf(q, 0.0, 1.0)
	audio.play("pickup")
	_refresh_beacons()


func submit_cook(order_id: int, q: float) -> void:
	if client:
		netsync.cook_result.rpc_id(1, order_id, q)
	else:
		cook_done(order_id, q, Net.team_of(Net.my_id()) if Net.online else -1)


## Which keys belong to the current scooter: solo = everything, coop = passenger keys, split = own pad/keys.
func _pressed(what: String) -> bool:
	if scooter.take(what):   # network driver or passenger pressed it
		return true
	if scooter.remote:
		return false
	if Net.online:
		return Input.is_action_just_pressed("solo_" + what) or Input.is_action_just_pressed("p2_" + what)
	if split:
		return Input.is_action_just_pressed(("solo_" if scooter.player == 0 else "p2_") + what)
	if coop:
		return Input.is_action_just_pressed("p2_" + what)
	return Input.is_action_just_pressed("solo_" + what) or Input.is_action_just_pressed("p2_" + what)


var split_layer: CanvasLayer


func _build_split_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	split_layer = layer
	add_child(layer)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)
	for s in scooters:
		var c := SubViewportContainer.new()
		c.stretch = true
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(c)
		var vp := SubViewport.new()
		vp.world_3d = get_viewport().find_world_3d()
		vp.audio_listener_enable_3d = false
		c.add_child(vp)
		var cam := ChaseCamera.new()
		cam.target = s
		vp.add_child(cam)
		cam.current = true
		cam.snap.call_deferred()
		cameras.append(cam)
	camera = cameras[0]
	get_viewport().disable_3d = true


func _exit_tree() -> void:
	if split:
		get_viewport().disable_3d = false


func _check_loose_pickup(pos: Vector3, sp: float) -> void:
	var r: float = mods.get("pickup_radius", 2.5)
	var pressed: bool = (request_pickup and scooter == scooters[local_index]) or _pressed("pickup")
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
	var who := clampi(it.carrier, 0, scooters.size() - 1)
	var ctx := {"time_left": o.t_left, "time_total": o.t_total, "thrown": thrown, "crashed": o.crashed,
		"combo": combo, "quirk": o.quirk, "mods": scooters[who].mods}
	var res := Tips.compute(it, ctx)
	if clock < happy_until:
		res.tip = int(res.tip * 1.5)
	var rv := Reviews.make(it.kind, res.tags, Game.lang(), rng)
	rv.stars = res.stars
	rv.tip = res.tip
	rv.food = it.kind
	rv.heat = it.heat
	rv.integrity = it.integrity
	rv.day = run.day
	reviews.append(rv)
	run.add_tip(res.tip, scooters[who].team)
	if who == local_index:
		SteamBridge.achieve("FIRST_DELIVERY")
		if thrown:
			SteamBridge.achieve("BALCONY_THROW")
		if it.kind == "soup" and it.integrity > 90.0:
			SteamBridge.achieve("SOUP_SURVIVOR")
	rv["by"] = who
	if thrown:
		run.stats.throws += 1
	if it.spilled:
		run.stats.spilled += 1
	hud.review(rv)
	_customer_reaction(city.lots[o.cust], res.stars)
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


## Name above every scooter so players can find each other (visible through walls).
func _name_tag(s: Scooter, text: String) -> void:
	if scooters.size() < 2 and not Net.online:
		return
	var l := U.label3d(s, text, Vector3(0, 2.35, 0), 56, Color(Game.TEAM_COLORS[s.team]).lightened(0.4) if run.competitive() else Color.WHITE)
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 48
	s.name_tag = l


## Quick chat bubble above a scooter (keys 1-4 / d-pad).
func emote(idx: int, e: int) -> void:
	if idx < 0 or idx >= scooters.size():
		return
	var s: Scooter = scooters[idx]
	var l := U.label3d(s, Game.t("emote_%d" % e), Vector3(0, 3.0, 0), 80, [UiKit.BAD, UiKit.GOLD, UiKit.GOOD, Color("#4cc9f0")][e])
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 3.6, 2.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tw.tween_callback(l.queue_free)
	audio.play("pickup", 0.3)
	if netsync:
		netsync.send_fx("emote", [idx, e])


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


func _cam_for(s: Scooter) -> ChaseCamera:
	if Net.online:
		return camera
	return cameras[mini(s.player, cameras.size() - 1)]


func _on_crash(_s: Scooter) -> void:
	var sp := _s._prev_vel.length()
	if sp > best_crash_speed and _rec_after < 0:
		_rec_after = Replay.AFTER
		_rec_speed = sp
		_rec_who = _s.index
	debug_log.crash_speeds.append(snappedf(_s._prev_vel.length(), 0.1))
	run.stats.crashes += 1
	for o in orders:
		if o.state == "carry":
			o.crashed = true
	hud.popup(Game.t("crash"), Color("#ef476f"), true)
	if scooters.find(_s) == local_index:
		SteamBridge.achieve("WIPEOUT")
	audio.play("crash")
	if not Net.online or scooters.find(_s) == local_index:
		_cam_for(_s).add_trauma(0.9)
	if netsync:
		netsync.send_fx("trauma", [scooters.find(_s), 0.9])


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


var _bump_popup_at := -10.0

func _on_walker_bumped(wk: Node3D) -> void:
	var s := nearest_scooter(wk.global_position)
	s.rack.jolt(3.0)
	audio.play("thud")
	if clock - _bump_popup_at > 0.6:   # a whole pack knocked over at once: one shout, not a pile
		_bump_popup_at = clock
		hud.popup(["HEY!", "OOF!", "MY LEG!", "RUDE!"][rng.randi() % 4], Color("#ffd166"))
	debug_log["walkers_hit"] = int(debug_log.get("walkers_hit", 0)) + 1


func _on_dog_bite(_d: Node3D) -> void:
	audio.play("bark")
	var victim := nearest_scooter(_d.global_position)
	if int(victim.mods.get("treats", 0)) > 0:   # bought dog treats: a happy lick instead of a bite
		hud.popup("*NOM NOM*", Color("#90be6d"))
		return
	victim.rack.jolt(4.5)
	for it in victim.rack.items:
		it.tilt_vel += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 2.0
	hud.popup("WOOF!", Color("#ffd166"))


var convoy_timer := 12.0
var event_timer := 45.0
var happy_until := -1.0
var shower_until := -1.0
var elevator_until := -1.0
const STAIRS := 4   # broken elevator: seconds (one per floor) standing at the door before the hand-off


## Mid-shift surprises so no two minutes feel the same.
func _random_event(forced := "") -> void:
	var options := ["happy", "rush", "shower", "roadworks", "convoy", "elevator", "marathon"]
	var e: String = forced if forced != "" else options[rng.randi() % options.size()]
	match e:
		"happy":
			happy_until = clock + 20.0
			hud.popup(Game.t("ev_happy"), UiKit.GOLD, true, 3.0)
		"rush":
			_spawn_offer("", "rush")
			hud.popup(Game.t("ev_rush"), UiKit.BAD, true, 3.0)
		"shower":
			shower_until = clock + 25.0
			hud.popup(Game.t("ev_shower"), Color("#4cc9f0"), true, 3.0)
			if netsync:
				netsync.send_fx("shower", [])
			_shower_fx()
		"roadworks":
			var n: int = city.n
			var horiz := rng.randf() < 0.5
			var line := rng.randi_range(1, n - 1) * CityGen.PITCH
			var along := (rng.randi_range(0, n - 1) + 0.5) * CityGen.PITCH
			var pos := Vector3(along, 0, line) if horiz else Vector3(line, 0, along)
			hud.popup(Game.t("ev_roadworks"), Color("#ff9f1c"), true, 3.0)
			if netsync:
				netsync.send_fx("roadworks", [pos, horiz])
			make_roadworks(pos, horiz)
		"convoy":
			_spawn_convoy()
		"marathon":
			var n: int = city.n
			var line := rng.randi_range(1, n - 1) * CityGen.PITCH
			var along_x := rng.randf() < 0.5
			var total := n * CityGen.PITCH
			var start := Vector3(0.0, 0, line) if along_x else Vector3(line, 0, 0.0)
			var d := Vector3.RIGHT if along_x else Vector3.BACK
			var sd := rng.randi()
			hud.popup(Game.t("ev_marathon"), Color("#06d6a0"), true, 3.0)
			if netsync:
				netsync.send_fx("marathon", [start, d, total, sd])
			make_marathon(start, d, total, sd)
		"elevator":
			elevator_until = clock + 30.0
			hud.popup(Game.t("ev_elevator"), Color("#c77dff"), true, 3.5)


## Barrier + cones across a road segment for the rest of the shift.
func make_roadworks(pos: Vector3, horiz: bool) -> void:
	var yaw := 0.0 if horiz else PI / 2
	var b := U.static_box(self, Vector3(0.4, 1.0, CityGen.ROAD - 1.0), Color("#ff9f1c"), pos + Vector3(0, 0.5, 0), yaw)
	for k in 5:
		U.box(b, Vector3(0.42, 0.25, 1.2), Color("#f8f9fa"), Vector3(0, 0.2, -4.0 + k * 2.0))
	for k in 4:
		var c := U.cyl(self, 0.05, 0.25, 0.75, Color("#ff7b00"), pos + Vector3(0, 0.37, 0) + Vector3(0, 0, -3.0 + k * 2.0).rotated(Vector3.UP, yaw) + Vector3(1.0, 0, 0).rotated(Vector3.UP, yaw), 8)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _shower_fx() -> void:
	if rain:
		return
	var p := CPUParticles3D.new()
	p.amount = 500
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 1, 18)
	p.direction = Vector3(0.1, -1, 0)
	p.spread = 2.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector3.ZERO
	var dm := BoxMesh.new()
	dm.size = Vector3(0.02, 0.5, 0.02)
	dm.material = U.mat(Color(0.8, 0.85, 1.0, 0.5), true)
	p.mesh = dm
	add_child(p)
	rain = p
	get_tree().create_timer(25.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
		rain = null)


func _spawn_convoy() -> void:
	var n: int = city.n
	var line := rng.randi_range(1, n - 1) * CityGen.PITCH
	var along_x := rng.randf() < 0.5
	var forward := rng.randf() < 0.5
	var total := n * CityGen.PITCH
	var start := Vector3(0.0 if forward else total, 0, line + 3.0) if along_x else Vector3(line - 3.0, 0, 0.0 if forward else total)
	var d := (Vector3.RIGHT if along_x else Vector3.BACK) * (1.0 if forward else -1.0)
	hud.popup(Game.t("convoy_alert"), Color("#ff70a6"), true)
	if netsync:
		netsync.send_fx("convoy", [start, d, total])
	make_convoy(start, d, total)


## A pack of runners down one road; deterministic from the seed so clients build the same pack.
func make_marathon(start: Vector3, d: Vector3, total: float, sd: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var side := d.cross(Vector3.UP)
	for i in 16:
		var wk := Npcs.Runner.new()
		wk.start = start + side * r.randf_range(-4.5, 4.5)
		wk.dir = d
		wk.total = total
		add_child(wk)
		var look := {"skin": r.randi() % 6, "jacket": [4, 6][i % 2], "helmet": 7, "helmet_color": 0, "accessory": r.randi() % 6}
		wk.setup(wk.start, look, -i * 1.6 - r.randf() * 1.5, 1.0)
		wk.speed = r.randf_range(3.4, 4.2)
		wk.world_ref = self
		U.bake(wk.body)
		wk.bumped.connect(_on_walker_bumped)


## Also called on clients: the convoy's motion is deterministic, so each peer moves its own copy.
func make_convoy(start: Vector3, d: Vector3, total: float) -> void:
	var c := Npcs.Convoy.new()
	add_child(c)
	c.setup(start, d, total)
	c.honk.connect(func(): audio.play("horn", 0.25))


func _chaos_tick(dt: float, sp: float) -> void:
	if "convoy" in run.chaos and scooter == scooters[0]:
		convoy_timer -= dt
		if convoy_timer <= 0.0:
			convoy_timer = rng.randf_range(35.0, 55.0)
			_spawn_convoy()
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
	if "pigeons" in run.chaos and not pigeon_busy and int(scooter.mods.get("treats", 0)) <= 0:
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

## A little customer pops out of the door and cheers or stomps.
func _customer_reaction(lot: Dictionary, stars: int) -> void:
	if netsync:
		netsync.send_fx("customer", [city.lots.find(lot), stars])
	var c := Node3D.new()
	add_child(c)
	var side: Vector3 = lot.side
	c.global_position = lot.door + side * 0.8 + Vector3(0, 0.15, 0)
	c.rotation.y = atan2(side.x, side.z)
	var fig := Node3D.new()
	Courier.build(fig, {"skin": rng.randi() % 6, "jacket": rng.randi() % 9, "helmet": 7, "accessory": rng.randi() % 6}, true)
	fig.scale = Vector3.ONE * 1.15
	fig.position.y = 0.68
	c.add_child(fig)
	var happy := stars >= 4
	var txt := (["YUM!", "WOW!", "YES!"] if happy else (["UGH.", "...", "HMPF"] if stars <= 2 else ["OK."]))
	var l := U.label3d(c, txt[rng.randi() % txt.size()], Vector3(0, 2.2, 0), 90, UiKit.GOOD if happy else (UiKit.BAD if stars <= 2 else Color.WHITE))
	l.no_depth_test = true
	var tw := c.create_tween()
	if happy:
		for i in 3:
			tw.tween_property(c, "position:y", c.position.y + 0.6, 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "position:y", c.position.y, 0.15).set_ease(Tween.EASE_IN)
	else:
		for i in 4:
			tw.tween_property(c, "rotation:z", 0.25, 0.08)
			tw.tween_property(c, "rotation:z", -0.25, 0.08)
		tw.tween_property(c, "rotation:z", 0.0, 0.08)
	tw.tween_interval(1.0)
	tw.tween_property(c, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(c.queue_free)

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
	if netsync:
		netsync.send_fx("confetti", [pos])
	for c in [Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"), Color("#118ab2")]:
		_burst(pos, c, 12, 8.0, 0.12, 1.4)


func _drip(pos: Vector3, c: Color) -> void:
	_burst(pos, c, 10, 3.0, 0.08, 0.8)


func _splat(pos: Vector3, c: Color) -> void:
	if netsync:
		netsync.send_fx("splat", [pos, c.to_html()])
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

var _rec: Array = []
var _rec_tick := 0
var _rec_after := -1
var _rec_speed := 0.0
var _rec_who := 0
var best_crash_who := 0
var best_crash: Array = []
var best_crash_speed := 0.0
var skip_replay := false


## Ring buffer at 30 Hz; after a crash we keep recording a bit, then keep the clip if it's the biggest.
func _record() -> void:
	_rec_tick += 1
	if _rec_tick % 2:
		return
	_rec.append(Replay.capture(self))
	if _rec_after < 0 and _rec.size() > Replay.KEEP:
		_rec.pop_front()
	if _rec_after >= 0:
		_rec_after -= 1
		if _rec_after == 0:
			best_crash = _rec.duplicate()
			best_crash_speed = _rec_speed
			best_crash_who = _rec_who
			_rec_after = -1
			_rec = _rec.slice(_rec.size() - Replay.KEEP)


func _end_shift() -> void:
	running = false
	scooter.controls_enabled = false
	audio.music(false)
	audio.play("whistle")
	if _rec_after >= 0:   # crash happened in the last seconds: keep what we have
		best_crash = _rec.duplicate()
		best_crash_who = _rec_who
	if best_crash.size() > 10 and not skip_replay:
		if netsync:
			netsync.send_fx("replay", [best_crash, best_crash_who])
		await play_replay(best_crash, best_crash_who)
	var top := reviews.duplicate()
	top.sort_custom(func(a, b): return Reviews.funny_score(a.tag, a.stars) > Reviews.funny_score(b.tag, b.stars))
	shift_ended.emit({"reviews": reviews, "top": top.slice(0, 3), "earned": run.earned_today})


## Slow-motion clip of the day's biggest crash (online: the host sends it to everyone).
var replays_shown := 0

func play_replay(data: Array, who: int) -> void:
	replays_shown += 1
	if split:
		split_layer.visible = false
		get_viewport().disable_3d = false
	var hidden: Array = scooters.filter(func(s): return s.visible)
	for s in hidden:
		s.visible = false
	var food: Array = loose.filter(func(lf): return is_instance_valid(lf) and lf.visible)
	if netsync:
		food.append_array(netsync._loose_vis.values())
	for lf in food:
		lf.visible = false
	hud.visible = false
	var rp := Replay.new()
	add_child(rp)
	rp.play(data, camera, scooters, who)
	await rp.finished
	rp.queue_free()
	camera.current = true
	for s in hidden:
		if is_instance_valid(s):
			s.visible = true
	for lf in food:
		if is_instance_valid(lf):
			lf.visible = true
	hud.visible = true
	if split:
		split_layer.visible = true
		get_viewport().disable_3d = true


func pause(p: bool) -> void:
	get_tree().paused = p
