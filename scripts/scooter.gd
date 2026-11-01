class_name Scooter
extends RigidBody3D
## Arcade scooter: raycast suspension, grip, steering, upright torque.
## Forward is -Z. Feeds its own acceleration into the food rack.

signal crashed(scooter: Scooter)
signal honked(scooter: Scooter)
signal jolted(strength: float)

const TOP_SPEED := 16.0
const ACCEL := 6.5
const MAX_LAT := 10.0
const BRAKE := 10.5
const REVERSE_SPEED := 4.0
const MAX_YAW := 2.3
const RIDE_HEIGHT := 0.7
const SPRING := 2100.0
const DAMP := 260.0

var mods := {}
var coop := false
var split := false
var player := 0          # split screen: 0 = WASD/pad 0, 1 = arrows/pad 1
var controls_enabled := true
var color := Color("#ff6b35")
var rack: Rack
var visual: Node3D
var headlight: SpotLight3D
var look := {}
var rider: Node3D
var wheels: Array = []
var rays: Array = []
var grounded := false
var is_crashed := false
var crash_timer := 0.0
var ragdoll: RigidBody3D
var throttle := 0.0
var steer := 0.0
var speed := 0.0            # forward speed, m/s
var local_accel := Vector2.ZERO
var flip_timer := 0.0
var jolt_cooldown := 0.0
var _prev_vel := Vector3.ZERO
var _prev_comp := [0.0, 0.0, 0.0, 0.0]
var _smooth_accel := Vector2.ZERO
var crash_count := 0
var stall_t := 0.0
var _gas_ramp := 0.0
var _brake_ramp := 0.0
var external_input := {}
var team := 0
var name_tag: Label3D
var index := 0                # position in World.scooters
var remote := false           # host-side scooter driven by a network player
var net_pending := {}         # button presses received from that player
var net_seen := {}
var passenger_ids: Array = []      # online players riding on the back
var passenger_balance := Vector2.ZERO
var _mouse_bal := Vector2.ZERO


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and controls_enabled and not remote:
		_mouse_bal += Vector2(e.relative.x, -e.relative.y) * 0.015    # used by tests / autopilot: {"throttle":1, "steer":0, ...}


func _ready() -> void:
	if player == 0 and color == Color("#ff6b35"):
		color = Color(Game.SCOOTER_COLORS[int(Game.settings.color) % Game.SCOOTER_COLORS.size()])
	if look.is_empty():
		look = Game.settings.look if player == 0 else Courier.default_look(player)
	mass = 140.0
	gravity_scale = 1.0
	can_sleep = false
	continuous_cd = true
	angular_damp = 1.0
	linear_damp = 0.05
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.1
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.55, 0.55, 1.5)
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, 0)
	for p in [Vector3(-0.28, 0.5, -0.65), Vector3(0.28, 0.5, -0.65), Vector3(-0.28, 0.5, 0.65), Vector3(0.28, 0.5, 0.65)]:
		var r := RayCast3D.new()
		r.position = p
		r.target_position = Vector3(0, -0.9, 0)
		r.collision_mask = 1 | 8
		add_child(r)
		rays.append(r)
	_build_visual()
	rack = Rack.new()
	rack.body = self
	rack.position = Vector3(0, 0.98, 0.5)
	visual.add_child(rack)


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	# deck + body
	U.box(visual, Vector3(0.42, 0.12, 1.35), Color("#2b2d42"), Vector3(0, 0.38, 0))
	# rounded, glossy body (a squashed capsule) instead of boxes
	var paint := U.mat(color, false, 0.25)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.27
	bm.height = 0.8
	body.mesh = bm
	body.rotation.x = PI / 2
	body.scale = Vector3(1.0, 1.0, 0.75)
	body.position = Vector3(0, 0.62, 0.33)
	body.material_override = paint
	visual.add_child(body)
	var seat := MeshInstance3D.new()
	var sm := CapsuleMesh.new()
	sm.radius = 0.2
	sm.height = 0.62
	seat.mesh = sm
	seat.rotation.x = PI / 2
	seat.scale = Vector3(1.1, 1.0, 0.35)
	seat.position = Vector3(0, 0.84, 0.3)
	seat.material_override = U.mat(Color("#1d1d1d"), false, 0.5)
	visual.add_child(seat)
	var shield := U.box(visual, Vector3(0.38, 0.55, 0.16), color, Vector3(0, 0.64, -0.58))
	shield.material_override = paint
	shield.rotation.x = 0.18
	for x in [-0.34, 0.34]:   # mirrors
		U.cyl(visual, 0.01, 0.01, 0.25, Color("#adb5bd"), Vector3(x, 1.42, -0.72), 6)
		U.sphere(visual, 0.05, Color("#dee2e6"), Vector3(x, 1.55, -0.72)).scale = Vector3(1, 0.7, 0.4)
	var stem := U.cyl(visual, 0.03, 0.03, 0.8, Color("#adb5bd"), Vector3(0, 0.95, -0.62))
	stem.rotation.x = -0.25
	U.box(visual, Vector3(0.7, 0.05, 0.05), Color("#1d1d1d"), Vector3(0, 1.33, -0.72))
	U.sphere(visual, 0.08, Color("#fff3b0"), Vector3(0, 0.95, -0.7))  # headlight
	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 0.95, -0.75)
	headlight.spot_range = 22.0
	headlight.spot_angle = 32.0
	headlight.light_energy = 3.0
	headlight.light_color = Color("#fff3d6")
	headlight.visible = false
	visual.add_child(headlight)
	# rack plate
	U.box(visual, Vector3(0.62, 0.04, 0.62), Color("#6c757d"), Vector3(0, 0.96, 0.5))
	for x in [-0.29, 0.29]:
		U.box(visual, Vector3(0.03, 0.2, 0.62), Color("#6c757d"), Vector3(x, 0.88, 0.5))
	for z in [-0.6, 0.62]:
		var w := Node3D.new()
		w.position = Vector3(0, 0.25, z)
		visual.add_child(w)
		var t := U.cyl(w, 0.25, 0.25, 0.16, Color("#111111"))
		t.rotation.z = PI / 2
		var hub := U.cyl(w, 0.12, 0.12, 0.17, Color("#dee2e6"))
		hub.rotation.z = PI / 2
		wheels.append(w)
	rider = Node3D.new()
	visual.add_child(rider)
	Courier.build(rider, look)
	rider.position = Vector3(0, 0.85, 0.05)


## Rebuild the rider after the look changed (character screen).
## Show riders standing on the back step, holding the tower.
func add_passenger_visual(l: Dictionary) -> void:
	var p := Node3D.new()
	Courier.build(p, l)
	p.position = Vector3(0.42 * (1 if visual.get_child_count() % 2 == 0 else -1), 0.55, 0.62)
	p.scale = Vector3.ONE * 0.9
	visual.add_child(p)


func set_look(l: Dictionary) -> void:
	look = l
	for c in rider.get_children():
		c.queue_free()
	Courier.build(rider, look)


func _axis(neg: String, pos: String) -> float:
	return Input.get_action_strength(pos) - Input.get_action_strength(neg)


## Consume one queued network button press.
func take(b: String) -> bool:
	if int(net_pending.get(b, 0)) > 0:
		net_pending[b] -= 1
		return true
	return false


func read_input() -> void:
	if remote and external_input.is_empty():
		throttle = 0.0
		steer = 0.0
		return
	if external_input.size() > 0:
		throttle = external_input.get("throttle", 0.0)
		steer = external_input.get("steer", 0.0)
		rack.balance = (external_input.get("balance", Vector2.ZERO) + passenger_balance).limit_length(1.0)
		return
	var pre := "p1_" if player == 0 else "p2d_"
	var gas := Input.get_action_strength(pre + "throttle")
	var brk := Input.get_action_strength(pre + "brake")
	# keyboard keys are all-or-nothing: ramp them so a tap is gentle and a hold is hard
	var dt := get_physics_process_delta_time()
	_gas_ramp = 0.0 if gas < 0.05 else minf(1.0, maxf(_gas_ramp, 0.55) + dt * 1.5)
	_brake_ramp = 0.0 if brk < 0.05 else minf(1.0, maxf(_brake_ramp, 0.3) + dt * 1.4)
	throttle = gas * _gas_ramp - brk * _brake_ramp
	steer = _axis(pre + "left", pre + "right")
	var bal := Vector2.ZERO
	if player == 1:
		bal = Vector2(_axis("p2s_bal_left", "p2s_bal_right"), _axis("p2s_bal_back", "p2s_bal_fwd"))
	elif not split:
		bal = Vector2(_axis("p2_bal_left", "p2_bal_right"), _axis("p2_bal_back", "p2_bal_fwd"))
	if not coop and player == 0:
		bal += Vector2(_axis("solo_bal_left", "solo_bal_right"), _axis("solo_bal_back", "solo_bal_fwd"))
	if player == 0:
		bal += _mouse_bal.limit_length(1.0)  # mouse balances too (passenger in co-op, anyone solo)
	_mouse_bal *= 0.8
	rack.balance = (bal + passenger_balance).limit_length(1.0)


func _physics_process(dt: float) -> void:
	rack.mods = mods
	if is_crashed:
		crash_timer -= dt
		if crash_timer <= 0.0:
			recover()
		_prev_vel = linear_velocity
		return
	if controls_enabled:
		read_input()
	else:
		throttle = 0.0
		steer = 0.0
		rack.balance = Vector2.ZERO
	var b := global_transform.basis
	var fwd := -b.z
	var up := b.y
	# --- suspension
	var normal_sum := Vector3.ZERO
	var hits := 0
	var max_comp_speed := 0.0
	for i in rays.size():
		var r: RayCast3D = rays[i]
		r.force_raycast_update()
		if r.is_colliding():
			var p := r.get_collision_point()
			var dist := r.global_position.distance_to(p)
			var comp := maxf(0.0, RIDE_HEIGHT - dist)
			var comp_speed: float = (comp - _prev_comp[i]) / dt
			_prev_comp[i] = comp
			max_comp_speed = maxf(max_comp_speed, comp_speed)
			var point_vel := linear_velocity + angular_velocity.cross(r.global_position - global_position)
			var f := SPRING * comp - DAMP * point_vel.dot(up)
			if comp > 0.0:
				apply_force(up * maxf(0.0, f), r.global_position - global_position)
			normal_sum += r.get_collision_normal()
			hits += 1
		else:
			_prev_comp[i] = 0.0
	grounded = hits >= 2
	var ground_n := normal_sum.normalized() if hits > 0 else Vector3.UP
	# --- drive
	var v := linear_velocity
	speed = v.dot(fwd)
	var top: float = TOP_SPEED * mods.get("top_speed_mult", 1.0)
	var acc: float = ACCEL * mods.get("accel_mult", 1.0)
	if grounded:
		var flat_fwd := (fwd - ground_n * fwd.dot(ground_n)).normalized()
		if throttle > 0.05:
			if speed < -0.5:
				apply_central_force(flat_fwd * BRAKE * mass * throttle)
			else:
				apply_central_force(flat_fwd * acc * mass * throttle * clampf(1.0 - pow(speed / top, 2.0), 0.0, 1.0))
		elif throttle < -0.05:
			if speed > 0.5:
				apply_central_force(-flat_fwd * BRAKE * mass * -throttle)
			else:
				apply_central_force(-flat_fwd * acc * 0.6 * mass * -throttle * clampf(1.0 + speed / REVERSE_SPEED, 0.0, 1.0))
		else:
			apply_central_force(-flat_fwd * signf(speed) * minf(absf(speed) * 4.0, 1.6) * mass)
		# grip: kill sideways velocity
		var right := b.x
		var lat := v.dot(right)
		var wet: float = 0.65 if mods.get("shower", false) else 1.0
		var grip: float = 9.0 * mods.get("grip_mult", 1.0) * wet
		var max_grip: float = 22.0 * mods.get("grip_mult", 1.0) * wet
		apply_central_force(-right * clampf(lat * grip, -max_grip, max_grip) * mass)
	# --- steering (yaw rate control)
	var sf := clampf(absf(speed) / 3.0, 0.0, 1.0) * (1.0 - 0.45 * clampf(absf(speed) / top, 0.0, 1.0))
	var yaw_cap := minf(MAX_YAW * sf, MAX_LAT * mods.get("grip_mult", 1.0) / maxf(1.0, absf(speed)) + 0.15)
	var target_yaw := -steer * yaw_cap * (1.0 if speed >= 0.0 else -1.0)
	if not grounded:
		target_yaw *= 0.3
	var yaw_rate := angular_velocity.dot(up)
	apply_torque(up * (target_yaw - yaw_rate) * 18.0 * mass * 0.25)
	# --- upright
	var want_up := ground_n if grounded else Vector3.UP
	var axis := up.cross(want_up)
	var ang_no_yaw := angular_velocity - up * yaw_rate
	var k_up := 60.0 if grounded else 25.0
	apply_torque((axis * k_up - ang_no_yaw * 7.0) * mass * 0.3)
	# --- feel: lean + wheel spin
	visual.rotation.z = lerpf(visual.rotation.z, -steer * sf * 0.35, 0.12)
	for w in wheels:
		w.rotation.x -= speed * dt / 0.25
	# --- acceleration felt by the food
	var a_world := (v - _prev_vel) / dt
	var a_local := b.inverse() * a_world
	var a2 := Vector2(a_local.x, -a_local.z).limit_length(40.0)
	_smooth_accel = _smooth_accel.lerp(a2, 0.5)
	local_accel = _smooth_accel
	jolt_cooldown -= dt
	if max_comp_speed > 3.0 and jolt_cooldown <= 0.0:
		var s: float = minf(max_comp_speed * 0.4, 7.0) * mods.get("jolt_mult", 1.0)
		rack.jolt(s)
		jolted.emit(s)
		jolt_cooldown = 0.15
	rack.heat_mult = 1.5 if mods.get("shower", false) else 1.0
	rack.step(dt, local_accel)
	# --- crash detection
	var hv_prev := Vector3(_prev_vel.x, 0, _prev_vel.z)
	var hv := Vector3(v.x, 0, v.z)
	if hv_prev.length() > 7.0 and (hv_prev - hv).length() > 6.5:
		crash(hv_prev)
	if up.dot(Vector3.UP) < 0.35:
		flip_timer += dt
		if flip_timer > 0.6:
			crash(hv_prev)
	else:
		flip_timer = 0.0
	if controls_enabled and (take("horn") if remote else Input.is_action_just_pressed("p1_horn" if player == 0 else "p2d_horn")):
		honked.emit(self)
	if controls_enabled and (take("reset") if remote else Input.is_action_just_pressed("p1_reset" if player == 0 else "p2d_reset")) and not is_crashed:
		recover(true)
	# wedged in something (ramp side, wall corner)? pop free after 3 s of pushing without moving
	if absf(throttle) > 0.5 and v.length() < 0.3:
		stall_t += dt
		if stall_t > 3.0:
			recover(true)
	else:
		stall_t = 0.0
	_prev_vel = v


func crash(vel: Vector3) -> void:
	if is_crashed:
		return
	is_crashed = true
	crash_count += 1
	crash_timer = 2.3
	rider.visible = false
	ragdoll = RigidBody3D.new()
	ragdoll.mass = 70.0
	ragdoll.collision_layer = 4
	ragdoll.collision_mask = 1 | 2 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.1
	cs.shape = cap
	cs.position = Vector3(0, 0.4, 0)
	ragdoll.add_child(cs)
	var vis := Node3D.new()
	ragdoll.add_child(vis)
	Courier.build(vis, look)
	get_parent().add_child(ragdoll)
	ragdoll.global_transform = rider.global_transform
	ragdoll.linear_velocity = vel * 0.9 + Vector3.UP * 5.0
	ragdoll.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	rack.scatter(vel * 0.7)
	crashed.emit(self)


func recover(unstick := false) -> void:
	is_crashed = false
	flip_timer = 0.0
	stall_t = 0.0
	if is_instance_valid(ragdoll):
		ragdoll.queue_free()
	ragdoll = null
	rider.visible = true
	var yaw := global_rotation.y
	var p := global_position
	if unstick:
		p += global_basis.z * 1.5 + Vector3.UP * 1.0
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, maxf(p.y, 0.0) + 0.6, p.z))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_vel = Vector3.ZERO


## Point the camera should follow (ragdoll while crashed).
func focus_point() -> Vector3:
	if is_crashed and is_instance_valid(ragdoll):
		return ragdoll.global_position
	return global_position
