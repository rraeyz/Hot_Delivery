class_name NetSync
extends Node
## Lives under World as "NetSync". Host: broadcasts snapshots at 20 Hz and fx events.
## Client: sends its input to the host and draws the latest snapshot smoothly.

const SEND_EVERY := 3   # physics frames between snapshots (60/3 = 20 Hz)

var world: World
var _tick := 0
var _snap := {}          # latest snapshot (client)
var _btn := {"throw": 0, "pickup": 0, "horn": 0, "reset": 0}
var _loose_vis := {}     # client: loose food id -> Node3D
var _last_orders_hash := 0


func _ready() -> void:
	name = "NetSync"


func _physics_process(dt: float) -> void:
	if not Net.online:
		return
	if world.client:
		_send_input()
		_apply(dt)
	else:
		_tick += 1
		if _tick % SEND_EVERY == 0:
			snap.rpc(_build())


# ---------------------------------------------------------------- client -> host input

func _send_input() -> void:
	var s: Scooter = world.scooter
	if Net.is_cook(Net.my_id()):
		return
	if Net.is_passenger(Net.my_id()):
		var bal := Vector2(Input.get_action_strength("p2_bal_right") + Input.get_action_strength("solo_bal_right") - Input.get_action_strength("p2_bal_left") - Input.get_action_strength("solo_bal_left"),
			Input.get_action_strength("p2_bal_fwd") + Input.get_action_strength("solo_bal_fwd") - Input.get_action_strength("p2_bal_back") - Input.get_action_strength("solo_bal_back"))
		bal += s._mouse_bal.limit_length(1.0)
		s._mouse_bal *= 0.8
		for b in ["throw", "pickup"]:
			if Input.is_action_just_pressed("solo_" + b) or Input.is_action_just_pressed("p2_" + b):
				_btn[b] += 1
		inp_from_client.rpc_id(1, {"balance": bal.limit_length(1.0), "btn": _btn.duplicate()})
		return
	var inp: Dictionary
	if s.external_input.size() > 0:     # bot / autotest
		inp = s.external_input.duplicate()
		if world.request_pickup:
			_btn.pickup += 1
			world.request_pickup = false
	else:
		s.read_input()
		inp = {"throttle": s.throttle, "steer": s.steer, "balance": s.rack.balance}
		for b in ["throw", "pickup"]:
			if Input.is_action_just_pressed("solo_" + b) or Input.is_action_just_pressed("p2_" + b):
				_btn[b] += 1
		if Input.is_action_just_pressed("p1_horn"):
			_btn.horn += 1
		if Input.is_action_just_pressed("p1_reset"):
			_btn.reset += 1
	inp["btn"] = _btn.duplicate()
	inp_from_client.rpc_id(1, inp)


@rpc("any_peer", "unreliable_ordered")
func inp_from_client(inp: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var passenger := Net.is_passenger(sender)
	var idx := Net.ride_target(sender) if passenger else Net.drivers().find(sender)
	if idx < 0 or idx >= world.scooters.size():
		return
	var s: Scooter = world.scooters[idx]
	if passenger:
		var pb = inp.get("balance", Vector2.ZERO)
		s.passenger_balance = (pb as Vector2).limit_length(1.0) if pb is Vector2 else Vector2.ZERO
		var pbtn = inp.get("btn", {})
		if pbtn is Dictionary:
			for b in ["throw", "pickup"]:
				var key: String = "p_" + b
				var n := int(pbtn.get(b, 0))
				if n > int(s.net_seen.get(key, 0)):
					s.net_pending[b] = int(s.net_pending.get(b, 0)) + mini(3, n - int(s.net_seen.get(key, 0)))
					s.net_seen[key] = n
		return
	# clamp everything coming from the network
	var bal = inp.get("balance", Vector2.ZERO)
	s.external_input = {"throttle": clampf(float(inp.get("throttle", 0.0)), -1.0, 1.0),
		"steer": clampf(float(inp.get("steer", 0.0)), -1.0, 1.0),
		"balance": (bal as Vector2).limit_length(1.0) if bal is Vector2 else Vector2.ZERO}
	var btn = inp.get("btn", {})
	if btn is Dictionary:
		for b in ["throw", "pickup", "horn", "reset"]:
			var n := int(btn.get(b, 0))
			if n > int(s.net_seen.get(b, 0)):
				s.net_pending[b] = int(s.net_pending.get(b, 0)) + mini(3, n - int(s.net_seen.get(b, 0)))
				s.net_seen[b] = n


# ---------------------------------------------------------------- host -> client snapshot

func _build() -> Dictionary:
	var sc := []
	for s in world.scooters:
		var items := []
		for it in s.rack.items:
			items.append([it.kind, it.tilt, it.slosh, it.heat, it.integrity, it.order_id])
		var rag = s.ragdoll.global_transform if s.is_crashed and is_instance_valid(s.ragdoll) else null
		sc.append([s.global_transform, s.visual.rotation.z, s.is_crashed, rag, s.speed, items])
	var lo := []
	for lf in world.loose:
		if is_instance_valid(lf):
			lo.append([lf.item.get_instance_id(), lf.item.kind, lf.global_transform])
	var cars := []
	for c in world.cars:
		cars.append(c.global_transform)
	var dogs := []
	for d in world.dogs:
		dogs.append(d.global_transform)
	var wk := []
	for w in world.walkers:
		wk.append([w.global_transform, w.body.position, w.body.rotation])
	return {"t": world.time_left, "m": world.run.money, "e": world.run.earned_today, "s": sc, "l": lo,
		"k": cars, "d": dogs, "w": wk, "o": world.orders}


@rpc("authority", "unreliable_ordered")
func snap(data: Dictionary) -> void:
	_snap = data


func _apply(dt: float) -> void:
	if _snap.is_empty():
		return
	var k := 1.0 - exp(-14.0 * dt)
	world.time_left = _snap.t
	world.run.money = _snap.m
	world.run.earned_today = _snap.e
	var sc: Array = _snap.s
	for i in mini(sc.size(), world.scooters.size()):
		var s: Scooter = world.scooters[i]
		var e: Array = sc[i]
		var xf: Transform3D = e[0]
		s.global_transform = s.global_transform.interpolate_with(xf, k) if s.global_position.distance_to(xf.origin) < 8.0 else xf
		s.visual.rotation.z = e[1]
		s.rider.visible = not e[2]
		s.is_crashed = e[2]
		s.speed = e[4]
		_apply_ragdoll(s, e[3])
		_apply_rack(s, e[5])
	var ck: Array = _snap.k
	for i in mini(ck.size(), world.cars.size()):
		world.cars[i].global_transform = world.cars[i].global_transform.interpolate_with(ck[i], k)
	var dg: Array = _snap.d
	for i in mini(dg.size(), world.dogs.size()):
		world.dogs[i].global_transform = world.dogs[i].global_transform.interpolate_with(dg[i], k)
	var wl: Array = _snap.get("w", [])
	for i in mini(wl.size(), world.walkers.size()):
		var w: Node3D = world.walkers[i]
		w.global_transform = w.global_transform.interpolate_with(wl[i][0], k)
		w.body.position = wl[i][1]
		w.body.rotation = wl[i][2]
	_apply_loose(_snap.l, k)
	var h := hash(_snap.o)
	if h != _last_orders_hash:
		_last_orders_hash = h
		world.orders = _snap.o
		world._refresh_beacons()


func _apply_ragdoll(s: Scooter, rag) -> void:
	if rag == null:
		if is_instance_valid(s.ragdoll):
			s.ragdoll.queue_free()
			s.ragdoll = null
		return
	if not is_instance_valid(s.ragdoll):
		var r := RigidBody3D.new()   # visual only on clients
		r.freeze = true
		r.collision_layer = 0
		r.collision_mask = 0
		var vis := Node3D.new()
		Courier.build(vis, s.look)
		r.add_child(vis)
		world.add_child(r)
		s.ragdoll = r
	s.ragdoll.global_transform = rag


func _apply_rack(s: Scooter, items: Array) -> void:
	var kinds := items.map(func(e): return e[0])
	var cur := s.rack.items.map(func(it): return it.kind)
	if kinds != cur:
		s.rack.items.clear()
		for e in items:
			s.rack.items.append(FoodItem.new(e[0]))
		s.rack._rebuild()
	for i in items.size():
		var it: FoodItem = s.rack.items[i]
		var e: Array = items[i]
		it.tilt = e[1]
		it.slosh = e[2]
		it.heat = e[3]
		it.integrity = e[4]
		it.order_id = e[5]
	s.rack._update_visuals()


func _apply_loose(list: Array, k: float) -> void:
	var seen := {}
	for e in list:
		var id: int = e[0]
		seen[id] = true
		if not _loose_vis.has(id):
			var v := FoodVisual.build(e[1])
			world.add_child(v)
			v.global_transform = e[2]
			_loose_vis[id] = v
		var n: Node3D = _loose_vis[id]
		n.global_transform = n.global_transform.interpolate_with(e[2], k)
	for id in _loose_vis.keys():
		if not seen.has(id):
			_loose_vis[id].queue_free()
			_loose_vis.erase(id)


# ---------------------------------------------------------------- fx events (host -> clients)

func send_fx(kind: String, args: Array) -> void:
	if Net.online and multiplayer.is_server():
		fx.rpc(kind, args)


@rpc("authority", "reliable")
func fx(kind: String, args: Array) -> void:
	match kind:
		"popup":
			world.hud.popup(args[0], Color(args[1]), args[2])
		"review":
			world.hud.review(args[0])
		"sfx":
			world.audio.play(args[0])
		"confetti":
			world._confetti(args[0])
		"customer":
			world._customer_reaction(world.city.lots[args[0]], args[1])
		"splat":
			world._splat(args[0], Color(args[1]))
		"emote":
			var e: int = args[1]
			world.emote(args[0], e)
		"shower":
			world._shower_fx()
		"marathon":
			world.make_marathon(args[0], args[1], args[2], args[3])
		"replay":
			world.play_replay(args[0], args[1])
		"roadworks":
			world.make_roadworks(args[0], args[1])
		"convoy":
			world.make_convoy(args[0], args[1], args[2])
		"trauma":
			if args[0] == Net.my_index():
				world.camera.add_trauma(args[1])


@rpc("any_peer", "reliable")
func cook_result(order_id: int, q: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and Net.is_cook(sender):
		world.cook_done(order_id, q, Net.team_of(sender))


@rpc("any_peer", "reliable")
func emote_req(e: int) -> void:
	if multiplayer.is_server():
		world.emote(Net.my_index_of(multiplayer.get_remote_sender_id()), clampi(e, 0, 3))
