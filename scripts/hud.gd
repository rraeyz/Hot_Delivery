class_name Hud
extends CanvasLayer
## In-shift HUD: status, orders with heat/condition bars, stack danger meter, popups, reviews.

var world: World
var status: Label
var timer_label: Label
var orders_box: VBoxContainer
var meter: DangerMeter
var popups: Control
var review_box: VBoxContainer
var hint: Label
var cook_panel: CookPanel
var _refresh := 0.0


class DangerMeter extends Control:
	var tilt := Vector2.ZERO
	var danger := 0.0
	var count := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_circle(c, r, Color(0, 0, 0, 0.45))
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
		draw_arc(c, r * 0.5, 0, TAU, 30, Color(1, 1, 1, 0.2), 2.0)
		if count == 0:
			return
		var col := UiKit.GOOD.lerp(UiKit.BAD, clampf(danger, 0, 1))
		var p := c + Vector2(tilt.x, -tilt.y).limit_length(1.0) * r
		draw_circle(p, 10.0 + danger * 6.0, col)


func setup(w: World) -> void:
	world = w
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(16, 16)
	root.add_child(top)
	status = UiKit.label("", 28)
	top.add_child(status)
	timer_label = UiKit.label("", 60, Color.WHITE)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(-110, 6)
	timer_label.size = Vector2(220, 80)
	root.add_child(timer_label)
	orders_box = VBoxContainer.new()
	orders_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	orders_box.position = Vector2(-356, 16)
	orders_box.custom_minimum_size = Vector2(340, 0)
	orders_box.add_theme_constant_override("separation", 8)
	root.add_child(orders_box)
	meter = DangerMeter.new()
	meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	meter.size = Vector2(140, 140)
	meter.position = Vector2(-70, -170)
	root.add_child(meter)
	popups = Control.new()
	popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(popups)
	review_box = VBoxContainer.new()
	review_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	review_box.position = Vector2(16, -300)
	review_box.custom_minimum_size = Vector2(520, 0)
	review_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(review_box)
	var hint_key := "hint_split" if w.split else ("hint_coop" if w.coop else "hint")
	if Net.online and Net.is_cook(Net.my_id()):
		hint_key = "hint_cook"
	elif Net.online and Net.is_passenger(Net.my_id()):
		hint_key = "hint_ride"
	hint = UiKit.label(Game.t(hint_key), 22, Color(1, 1, 1, 0.9))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-640, -44)
	hint.size = Vector2(1280, 32)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(hint)
	if Net.online and Net.is_cook(Net.my_id()):
		var cp := CookPanel.new()
		cp.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		cp.position = Vector2(16, -120)
		root.add_child(cp)
		cp.setup(w)
		cook_panel = cp
	if w.run.chaos.size() > 0:
		var names := []
		for c in w.run.chaos:
			names.append(Game.chaos_text(c)[0])
		popup(Game.t("chaos") + ": " + ", ".join(names), UiKit.GOLD, true, 5.0)
	popup(Game.t("rent_due") % w.run.rent(), Color.WHITE, false, 4.0, 260.0)


func _process(dt: float) -> void:
	if not world:
		return
	var r := world.run
	var rent_col := "#06d6a0" if r.money >= r.rent() else "#ffd166"
	if r.competitive():
		var parts := []
		for i in r.wallets.size():
			parts.append("%s $%d" % [Game.player_name(i), r.earned_by[i]])
		status.text = "%s %d/%d   %s" % [Game.t("round"), r.day, RunState.ROUNDS, "   ".join(parts)]
		status.add_theme_color_override("font_color", Color.WHITE)
	else:
		status.text = "%s %d   %s $%d   %s $%d" % [Game.t("day"), r.day, Game.t("money"), r.money, Game.t("rent"), r.rent()]
		status.add_theme_color_override("font_color", Color(rent_col))
	var tl := maxf(0.0, world.time_left)
	timer_label.text = "%d:%02d" % [int(tl / 60.0), int(tl) % 60]
	timer_label.add_theme_color_override("font_color", UiKit.BAD if tl < 20.0 else Color.WHITE)
	var rack := world.scooter.rack
	meter.tilt = Vector2.ZERO
	if rack.items.size() > 0:
		var top: FoodItem = rack.items.back()
		meter.tilt = rack.top_tilt() / top.limit
	meter.danger = rack.danger()
	meter.count = rack.items.size()
	meter.queue_redraw()
	if world.clock > 25.0:
		hint.modulate.a = maxf(0.0, hint.modulate.a - dt * 0.5)
	_refresh -= dt
	if _refresh <= 0.0:
		_refresh = 0.2
		_rebuild_orders()


func _rebuild_orders() -> void:
	for c in orders_box.get_children():
		c.queue_free()
	var head := UiKit.label(Game.t("orders"), 26, UiKit.GOLD)
	orders_box.add_child(head)
	var carried := {}
	for it in world.scooter.rack.items:
		carried[it.order_id] = it
	for lf in world.loose:
		if is_instance_valid(lf):
			carried[lf.item.order_id] = lf.item
	var any := false
	for o in world.active_orders():
		any = true
		var p := PanelContainer.new()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var name: String = Game.up(Game.food_name(o.food))
		var q: String = (" · " + Game.t("quirk_" + o.quirk)) if o.quirk != "" else ""
		if o.state == "offer":
			p.add_theme_stylebox_override("panel", UiKit.style(Color(0.2, 0.2, 0.25, 0.85)))
			v.add_child(UiKit.label("%s%s" % [name, q], 23, Color("#ff9f1c")))
			v.add_child(UiKit.label("%s %s · %dm" % [Game.t("pickup"), world._rest_name(world.city.lots[o.rest].rest), int(world.scooter.global_position.distance_to(world.city.lots[o.rest].curb))], 18, Color(1, 1, 1, 0.85)))
		else:
			var it: FoodItem = carried.get(o.id)
			var tleft: float = o.t_left
			var tcol := Color.WHITE if tleft > 0 else UiKit.BAD
			v.add_child(UiKit.label("%s%s   %s" % [name, q, ("%ds" % int(tleft)) if tleft > 0 else "LATE"], 23, tcol))
			if it:
				v.add_child(_bar(it.heat, Color("#4cc9f0") if it.is_cold() else Color("#f3722c")))
				v.add_child(_bar(it.integrity, UiKit.GOOD))
			var dist := int(world.scooter.global_position.distance_to(world.city.lots[o.cust].curb))
			v.add_child(UiKit.label("%s · %dm" % [Game.t("deliver"), dist], 18, Color(1, 1, 1, 0.85)))
		orders_box.add_child(p)
	if not any:
		orders_box.add_child(UiKit.label(Game.t("no_orders"), 22))


func _bar(v: float, c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100
	b.value = v
	b.show_percentage = false
	b.custom_minimum_size = Vector2(300, 12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(5)
	b.add_theme_stylebox_override("fill", fg)
	b.add_theme_stylebox_override("background", bg)
	return b


var _banner: Label


## Persistent instruction line under the timer ("" hides it).
func banner(text: String) -> void:
	if not _banner:
		_banner = UiKit.label("", 32, UiKit.GOLD)
		_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.position = Vector2(-640, 86)
		_banner.size = Vector2(1280, 50)
		_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_banner.add_theme_constant_override("outline_size", 10)
		popups.add_child(_banner)
	_banner.text = text
	_banner.visible = text != ""


func popup(text: String, c: Color, big := false, life := 1.3, y_off := 0.0) -> void:
	if world and world.netsync:
		world.netsync.send_fx("popup", [text, c.to_html(), big])
	var l := UiKit.label(text, 84 if big else 54, c)
	l.add_theme_constant_override("outline_size", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.size = Vector2(1400, 110)
	l.position = Vector2(-700, -200 + y_off + popups.get_child_count() * 10)
	l.pivot_offset = Vector2(700, 55)
	l.scale = Vector2(0.4, 0.4)
	popups.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


static func review_card(rv: Dictionary, wide := 520.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.style(Color("#fffcf2"), 16)
	sb.border_color = UiKit.ACCENT
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(wide, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var n := UiKit.label(rv.name, 26, Color("#1d3557"))
	n.add_theme_constant_override("outline_size", 0)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(UiKit.Stars.new(rv.stars, 26))
	var line := UiKit.label("“" + rv.line + "”", 24, Color("#333333"))
	line.add_theme_constant_override("outline_size", 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(wide - 30, 0)
	v.add_child(line)
	var tip := UiKit.label("+$%d  ·  %s" % [rv.tip, Game.food_name(rv.food)], 20, Color("#2a9d8f"))
	tip.add_theme_constant_override("outline_size", 0)
	v.add_child(tip)
	return p


func review(rv: Dictionary) -> void:
	if world and world.netsync:
		world.netsync.send_fx("review", [rv])
	var p := review_card(rv)
	review_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	while review_box.get_child_count() > 2:
		review_box.get_child(0).free()
