class_name LooseFood
extends RigidBody3D
## A food item that fell off or was thrown. Can be picked up again.

signal landed(lf: LooseFood, speed: float)

var item: FoodItem
var thrown := false          # thrown on purpose toward a balcony
var target: Vector3 = Vector3.INF
var age := 0.0
var _prev_speed := 0.0
var _hit_ground := false


func setup(it: FoodItem) -> void:
	item = it
	mass = 2.0
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var sh := FoodVisual.shape(it.kind)
	cs.shape = sh
	cs.position = Vector3(0, (sh as BoxShape3D).size.y * 0.5, 0)
	add_child(cs)
	add_child(FoodVisual.build(it.kind))
	body_entered.connect(_on_body_entered)


func _physics_process(dt: float) -> void:
	age += dt
	item.step_heat(dt, 2.0)
	_prev_speed = linear_velocity.length()


func _on_body_entered(_b: Node) -> void:
	if age < 0.05:
		return
	if _prev_speed > 2.0:
		item.impact(_prev_speed)
	if not _hit_ground:
		_hit_ground = true
		landed.emit(self, _prev_speed)
