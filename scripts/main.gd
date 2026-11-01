extends Node
## Game flow: menu -> shift -> summary -> garage -> next shift ... -> fired.

const UNLOCK_DAYS := [2, 3, 4, 5, 6]   # reaching these days unlocks burger, drinks, ice cream, sushi, cake

var run: RunState
var world: World
var coop := false
var split := false
var daily := false
var ui: CanvasLayer
var menu_scene: Node3D
var paused_panel: Control
var toast: Label
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	UiKit.click_player = AudioStreamPlayer.new()
	UiKit.click_player.stream = load("res://assets/audio/click.wav")
	add_child(UiKit.click_player)
	if args.has("autotest"):
		_autotest()
		return
	show_menu()


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	paused_panel = null


func _screen(dim := true) -> Control:
	_clear_ui()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme()
	ui.add_child(root)
	if dim:
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.08, 0.15, 0.75)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
	return root


func _center_box(root: Control, width := 520.0) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	return v


func _focus_first(v: Control) -> void:
	for c in v.find_children("*", "Button", true, false):
		(c as Button).call_deferred("grab_focus")
		return


# ---------------------------------------------------------------- menu

func show_menu() -> void:
	get_tree().paused = false
	_free_world()
	_build_menu_scene()
	var root := _screen(false)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 90)
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	var title := UiKit.label("TIP OVER", 96, UiKit.GOLD)
	title.add_theme_constant_override("outline_size", 24)
	title.add_theme_color_override("font_outline_color", Color("#9d0208"))
	v.add_child(title)
	v.add_child(UiKit.label("Keep it hot. Keep it in the bowl." if Game.lang() == "en" else "Sıcak kalsın. Kasede kalsın.", 24))
	v.add_child(Control.new())
	v.add_child(UiKit.button(Game.t("play"), func(): start_run(randi(), false, false)))
	v.add_child(UiKit.button(Game.t("daily"), func(): start_run(_daily_seed(), false, true)))
	v.add_child(UiKit.button(Game.t("coop"), func(): start_run(randi(), true, false)))
	v.add_child(UiKit.button(Game.t("split"), func(): start_run(randi(), false, false, true)))
	v.add_child(UiKit.button(Game.t("settings"), show_settings))
	v.add_child(UiKit.button(Game.t("quit"), func(): get_tree().quit()))
	var best := UiKit.label(Game.t("best") % int(Game.save.best_day), 20, Color(1, 1, 1, 0.8))
	v.add_child(best)
	var today: String = Time.get_date_string_from_system()
	if Game.save.daily_best.has(today):
		v.add_child(UiKit.label("Daily %s: day %d" % [today, int(Game.save.daily_best[today])], 18, Color(1, 1, 1, 0.7)))
	var foot := UiKit.label(Game.t("credits"), 14, Color(1, 1, 1, 0.6))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(20, -30)
	root.add_child(foot)
	_focus_first(v)


func _daily_seed() -> int:
	return hash(Time.get_date_string_from_system())


func _build_menu_scene() -> void:
	if menu_scene:
		return
	menu_scene = Node3D.new()
	add_child(menu_scene)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#ffb4a2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#ffe5d9")
	e.ambient_light_energy = 0.6
	we.environment = e
	menu_scene.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	menu_scene.add_child(sun)
	U.cyl(menu_scene, 3.0, 3.2, 0.3, Color("#e76f51"), Vector3(0, -0.15, 0), 32)
	var turntable := Node3D.new()
	turntable.name = "Turntable"
	menu_scene.add_child(turntable)
	var s := Scooter.new()
	s.freeze = true
	s.controls_enabled = false
	s.set_physics_process(false)
	turntable.add_child(s)
	for k in ["pizza", "pizza", "soup", "burger", "cake"]:
		s.rack.mods = {"capacity": 9}
		s.rack.add_item(FoodItem.new(k))
	s.rack.items[3].tilt = Vector2(0.12, 0.05)
	s.rack.items[4].tilt = Vector2(-0.18, 0.08)
	s.rack._update_visuals()
	var cam := Camera3D.new()
	cam.position = Vector3(-2.4, 1.9, 3.4)
	menu_scene.add_child(cam)
	cam.look_at(Vector3(-0.9, 1.3, 0))
	cam.current = true
	var tw := turntable.create_tween().set_loops()
	tw.tween_property(turntable, "rotation:y", TAU, 14.0).from(0.0)


func _free_menu_scene() -> void:
	if menu_scene:
		menu_scene.queue_free()
		menu_scene = null


func show_settings() -> void:
	var root := _screen()
	var v := _center_box(root)
	v.add_child(UiKit.label(Game.t("settings"), 48, UiKit.GOLD))
	var lang_btn := UiKit.button("%s: %s" % [Game.t("lang"), "English" if Game.lang() == "en" else "Türkçe"], func():
		Game.settings.lang = "tr" if Game.lang() == "en" else "en"
		Game.write_save()
		show_settings())
	v.add_child(lang_btn)
	for key in ["volume", "music", "shake"]:
		v.add_child(UiKit.label(Game.t(key), 20))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Game.settings[key]
		s.custom_minimum_size = Vector2(400, 28)
		s.value_changed.connect(func(val):
			Game.settings[key] = val
			Game.apply_settings())
		v.add_child(s)
	var fs := CheckButton.new()
	fs.text = Game.t("fullscreen")
	fs.button_pressed = Game.settings.fullscreen
	fs.toggled.connect(func(on):
		Game.settings.fullscreen = on
		Game.apply_settings())
	v.add_child(fs)
	v.add_child(UiKit.button(Game.t("back"), func():
		Game.write_save()
		if world:
			show_pause()
		else:
			show_menu()))
	_focus_first(v)


# ---------------------------------------------------------------- run flow

func start_run(seed_value: int, coop_mode: bool, is_daily: bool, split_mode := false) -> void:
	coop = coop_mode
	split = split_mode
	daily = is_daily
	run = RunState.new(seed_value, int(Game.save.unlock_level))
	Game.save.runs += 1
	start_day()


func start_day() -> void:
	_free_world()
	_free_menu_scene()
	_clear_ui()
	get_tree().paused = false
	world = World.new()
	world.setup(run, coop, split)
	world.shift_ended.connect(show_summary)
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE


func _free_world() -> void:
	if world:
		world.queue_free()
		world = null


func _unlock_check() -> String:
	var lvl := 0
	for d in UNLOCK_DAYS:
		if run.day >= d:
			lvl += 1
	if lvl > int(Game.save.unlock_level):
		Game.save.unlock_level = lvl
		run.unlock_level = maxi(run.unlock_level, lvl)
		var names := ["burger", "drinks", "icecream", "sushi", "cake"]
		return Game.t("unlock") % Game.food_name(names[lvl - 1]).to_upper()
	return ""


func show_summary(result: Dictionary) -> void:
	var paid := run.end_shift()
	if world:
		world.hud.visible = false
	var root := _screen()
	var v := _center_box(root, 900)
	v.add_child(UiKit.label(Game.t("shift_over") + " — " + Game.t("day") + " %d" % run.day, 44, UiKit.GOLD))
	v.add_child(UiKit.label("%s: $%d    %s: $%d" % [Game.t("earned"), result.earned, Game.t("rent"), run.rent()], 26))
	var verdict := UiKit.label(Game.t("paid") if paid else Game.t("fired"), 40, UiKit.GOOD if paid else UiKit.BAD)
	v.add_child(verdict)
	if result.top.size() > 0:
		v.add_child(UiKit.label(Game.t("best_reviews"), 22, Color(1, 1, 1, 0.8)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		for rv in result.top:
			h.add_child(Hud.review_card(rv, 280))
		v.add_child(h)
	v.add_child(UiKit.label("TIP OVER · " + Game.t("save_card"), 16, Color(1, 1, 1, 0.6)))
	if paid:
		run.day += 0  # day advances when leaving the garage
		var unlock := _next_day_unlock_preview()
		if unlock != "":
			v.add_child(UiKit.label(unlock, 24, UiKit.GOLD))
		v.add_child(UiKit.button(Game.t("garage"), show_garage))
	else:
		v.add_child(UiKit.label(Game.t("stats") % [run.stats.deliveries, run.stats.crashes, run.stats.throws], 22))
		v.add_child(UiKit.button(Game.t("retry"), func(): start_run(randi(), coop, false, split)))
		v.add_child(UiKit.button(Game.t("menu"), show_menu))
		_record_run_end()
	_focus_first(v)


func _next_day_unlock_preview() -> String:
	run.day += 1
	var msg := _unlock_check()
	run.day -= 1
	return msg


func _record_run_end() -> void:
	Game.save.best_day = maxi(int(Game.save.best_day), run.day)
	if daily:
		var today: String = Time.get_date_string_from_system()
		Game.save.daily_best[today] = maxi(int(Game.save.daily_best.get(today, 0)), run.day)
	Game.write_save()


func show_garage() -> void:
	var root := _screen()
	var v := _center_box(root, 960)
	v.add_child(UiKit.label(Game.t("garage"), 48, UiKit.GOLD))
	v.add_child(UiKit.label("%s: $%d    %s %d: $%d" % [Game.t("money"), run.money, Game.t("rent"), run.day + 1, RunState.rent_for(run.day + 1)], 24))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for u in run.shop:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(300, 220)
		var pv := VBoxContainer.new()
		p.add_child(pv)
		var txt := Game.upgrade_text(u)
		pv.add_child(UiKit.label(txt[0], 26, UiKit.GOLD))
		var d := UiKit.label(txt[1], 19)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(270, 90)
		pv.add_child(d)
		if run.owned.count(u) > 0:
			pv.add_child(UiKit.label("x%d %s" % [run.owned.count(u), Game.t("owned")], 16, UiKit.GOOD))
		var b := UiKit.button("%s $%d" % [Game.t("buy"), run.cost_of(u)], func():
			if run.buy(u):
				show_garage())
		b.disabled = run.money < run.cost_of(u)
		pv.add_child(b)
		h.add_child(p)
	if run.owned.size() > 0:
		var names := []
		for u in run.owned:
			names.append(Game.upgrade_text(u)[0])
		var o := UiKit.label(Game.t("owned") + ": " + ", ".join(names), 18, Color(1, 1, 1, 0.8))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(o)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rr := UiKit.button("%s $%d" % [Game.t("reroll"), run.reroll_cost()], func():
		if run.reroll():
			show_garage())
	rr.disabled = run.money < run.reroll_cost()
	row.add_child(rr)
	row.add_child(UiKit.button(Game.t("next_day"), func():
		run.next_day()
		_unlock_check()
		Game.save.best_day = maxi(int(Game.save.best_day), run.day)
		Game.write_save()
		start_day()))
	v.add_child(row)
	var preview := []
	run.day += 1
	run.roll_chaos()
	for c in run.chaos:
		var ct := Game.chaos_text(c)
		preview.append("%s — %s" % [ct[0], ct[1]])
	run.day -= 1
	if preview.size() > 0:
		v.add_child(UiKit.label(Game.t("chaos") + ": " + " · ".join(preview), 18, Color("#ffd166")))
	_focus_first(v)


# ---------------------------------------------------------------- pause / input

func show_pause() -> void:
	var root := _screen()
	paused_panel = root
	var v := _center_box(root)
	v.add_child(UiKit.label("II", 48, UiKit.GOLD))
	v.add_child(UiKit.button(Game.t("resume"), resume))
	v.add_child(UiKit.button(Game.t("settings"), show_settings))
	v.add_child(UiKit.button(Game.t("menu"), show_menu))
	_focus_first(v)


func resume() -> void:
	_clear_ui()
	get_tree().paused = false


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("screenshot"):
		var path := Game.screenshot()
		_toast(Game.t("saved") + " " + path)
	elif e.is_action_pressed("pause") and world and world.running:
		if get_tree().paused:
			resume()
		else:
			get_tree().paused = true
			show_pause()


func _toast(msg: String) -> void:
	if toast and is_instance_valid(toast):
		toast.queue_free()
	toast = UiKit.label(msg, 18, Color.WHITE)
	toast.position = Vector2(20, 680)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(toast)
	get_tree().create_timer(3.0, true).timeout.connect(layer.queue_free)


# ---------------------------------------------------------------- automated visual test

## godot --path . -- --autotest --out=/tmp/shots
## Drives the scooter with a simple autopilot and saves screenshots.
func _autotest() -> void:
	var out: String = args.get("out", "user://autotest")
	DirAccess.make_dir_recursive_absolute(out)
	var chaos: String = args.get("chaos", "")
	run = RunState.new(int(args.get("seed", "3")), int(args.get("unlocks", "5")))
	if chaos != "":
		run.chaos = Array(chaos.split(","))
	if args.has("menu"):
		show_menu()
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png(out + "/menu.png")
		get_tree().quit()
		return
	split = args.has("split")
	start_day()
	var w := world
	await get_tree().process_frame
	if args.has("len"):
		w.time_left = float(args.len)
	var bot := Autopilot.new(w)
	var every := float(args.get("every", "3"))
	var total := float(args.get("secs", "30"))
	var t := 0.0
	var next_shot := every
	var shots := 0
	while t < total and is_instance_valid(w):
		w.scooter.external_input = bot.drive(get_physics_process_delta_time())
		if args.has("crash") and t >= float(args.crash):
			args.erase("crash")
			w.scooter.crash(-w.scooter.global_basis.z * 12.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t >= next_shot:
			next_shot += every
			get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [out, shots])
			shots += 1
			print("t=%.1f speed=%.1f items=%d loose=%d crashed=%s money=%d" % [t, w.scooter.speed, w.scooter.rack.items.size(), w.loose.size(), w.scooter.is_crashed, run.money])
	get_tree().quit()
