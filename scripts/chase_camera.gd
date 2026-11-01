class_name ChaseCamera
extends Camera3D
## Smooth third-person camera behind the scooter, with trauma-based shake.

var target: Scooter
var trauma := 0.0
var distance := 4.3
var height := 2.3
var _yaw := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	fov = 68.0
	far = 400.0
	_noise.frequency = 2.0


func snap() -> void:
	if target:
		_yaw = target.global_rotation.y
		global_position = _desired()
		look_at(target.focus_point() + Vector3.UP * 1.3)


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func _desired() -> Vector3:
	var back := Vector3(sin(_yaw), 0, cos(_yaw))
	var spd := target.linear_velocity.length() if target else 0.0
	var d := distance + spd * 0.1
	return target.focus_point() + back * d + Vector3.UP * (height + spd * 0.03)


func _process(dt: float) -> void:
	if not target:
		return
	_t += dt
	if not target.is_crashed:
		_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-3.5 * dt))
	global_position = global_position.lerp(_desired(), 1.0 - exp(-6.0 * dt))
	var look := target.focus_point() + Vector3.UP * 1.3 - Vector3(sin(_yaw), 0, cos(_yaw)) * 3.0
	look_at(look)
	trauma = maxf(0.0, trauma - dt * 1.2)
	var sh: float = trauma * trauma * Game.settings.shake
	if sh > 0.0:
		rotation.x += _noise.get_noise_2d(_t * 40.0, 0) * 0.08 * sh
		rotation.y += _noise.get_noise_2d(0, _t * 40.0) * 0.08 * sh
		rotation.z += _noise.get_noise_2d(_t * 40.0, 50) * 0.06 * sh
