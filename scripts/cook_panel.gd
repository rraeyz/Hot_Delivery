class_name CookPanel
extends PanelContainer
## The cook's job: pick an order, then stop the needle in the green zone.
## Better timing = hotter, more intact food for the couriers.

const SPEED := {"soup": 2.4, "pizza": 1.7, "cake": 3.2, "sushi": 2.8, "drinks": 2.2, "burger": 2.0, "icecream": 2.6}

var world: World
var list: VBoxContainer
var gauge: Gauge
var title: Label
var current := -1        # order id being cooked
var t := 0.0
var _refresh := 0.0


class Gauge extends Control:
	var needle := 0.5
	var zone := 0.5
	var width := 0.14

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2((zone - width * 0.5) * size.x, 0), Vector2(width * size.x, size.y)), UiKit.GOOD)
		draw_rect(Rect2(Vector2(needle * size.x - 3, -6), Vector2(6, size.y + 12)), Color.WHITE)


func setup(w: World) -> void:
	world = w
	custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	add_child(v)
	title = UiKit.label(Game.t("kitchen"), 28, UiKit.GOLD)
	v.add_child(title)
	gauge = Gauge.new()
	gauge.custom_minimum_size = Vector2(390, 36)
	gauge.visible = false
	v.add_child(gauge)
	list = VBoxContainer.new()
	v.add_child(list)


func _process(dt: float) -> void:
	if not world:
		return
	if current >= 0:
		var o := world.order_by_id(current)
		if o.is_empty() or o.get("ready", true):
			_stop_cooking()
			return
		t += dt
		gauge.needle = 0.5 + 0.5 * sin(t * SPEED.get(o.food, 2.0))
		gauge.queue_redraw()
		if Input.is_action_just_pressed("solo_throw") or Input.is_action_just_pressed("p2_throw") or Input.is_action_just_pressed("ui_accept"):
			finish(gauge.needle)
		return
	_refresh -= dt
	if _refresh <= 0.0:
		_refresh = 0.3
		_rebuild()


func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	for o in world.orders:
		if o.state == "offer" and not o.get("ready", true):
			var id: int = o.id
			list.add_child(UiKit.button("%s %s" % [Game.t("cook_it"), Game.food_name(o.food).to_upper()], func(): start(id)))


func start(order_id: int) -> void:
	current = order_id
	t = randf() * TAU
	gauge.zone = randf_range(0.2, 0.8)
	gauge.visible = true
	title.text = Game.t("stop")
	for c in list.get_children():
		c.queue_free()


func finish(needle: float) -> void:
	var q := Kitchen.quality(needle, gauge.zone)
	world.hud.popup(Game.t("perfect_cook") if q > 0.9 else "%d%%" % int(q * 100), UiKit.GOOD if q > 0.6 else UiKit.GOLD)
	world.submit_cook(current, q)
	_stop_cooking()


func _stop_cooking() -> void:
	current = -1
	gauge.visible = false
	title.text = Game.t("kitchen")
	_refresh = 0.0
