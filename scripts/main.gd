extends Node
## Game flow: menu -> shift -> summary -> garage -> next shift ... -> fired.

const UNLOCK_DAYS := [2, 3, 4, 5, 6, 7, 8]   # reaching these days unlocks burger, drinks, ice cream, sushi, cake, jelly, coffee

var run: RunState
var world: World
var coop := false
var split := false
var daily := false
var ui: CanvasLayer
var menu_scene: Node3D
var menu_scooter: Scooter
var menu_cam: Camera3D
var paused_panel: Control
var toast: Label
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Net.players_changed.connect(func():
		if not world and Net.online:
			show_online())
	Net.connection_failed.connect(func(reason):
		show_menu()
		_toast(Game.t("disconnected") + " (" + reason + ")"))
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


func _center_box(root: Control, width := 420.0) -> VBoxContainer:
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
	menu_cam.position = Vector3(-2.4, 1.9, 3.4)
	menu_cam.look_at(Vector3(-0.9, 1.3, 0))
	var root := _screen(false)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 24)
	v.custom_minimum_size = Vector2(340, 0)
	v.add_theme_constant_override("separation", 7)
	root.add_child(v)
	var title := UiKit.label("TIP OVER", 60, UiKit.GOLD)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_outline_color", Color("#9d0208"))
	v.add_child(title)
	v.add_child(UiKit.label(Game.t("tagline"), 17))
	v.add_child(UiKit.button(Game.t("play"), func(): start_run(randi(), false, false)))
	v.add_child(UiKit.button(Game.t("daily"), func(): start_run(_daily_seed(), false, true)))
	v.add_child(UiKit.button(Game.t("couch"), show_couch))
	v.add_child(UiKit.button(Game.t("online"), show_online))
	v.add_child(UiKit.button(Game.t("character"), show_character))
	v.add_child(UiKit.button(Game.t("settings"), show_settings))
	v.add_child(UiKit.button(Game.t("quit"), func(): get_tree().quit()))
	var best := UiKit.label(Game.t("best") % int(Game.save.best_day), 15, Color(1, 1, 1, 0.85))
	best.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	best.position = Vector2(-300, 24)
	root.add_child(best)
	var today: String = Time.get_date_string_from_system()
	if Game.save.daily_best.has(today):
		v.add_child(UiKit.label("Daily %s: day %d" % [today, int(Game.save.daily_best[today])], 14, Color(1, 1, 1, 0.7)))
	_focus_first(v)


## Same-screen modes for 2 players.
func show_couch() -> void:
	_build_menu_scene()
	var root := _screen()
	var v := _center_box(root, 500)
	v.add_child(UiKit.label(Game.t("couch"), 34, UiKit.GOLD))
	v.add_child(UiKit.button(Game.t("coop"), func(): start_run(randi(), true, false)))
	v.add_child(UiKit.button(Game.t("split"), func(): start_run(randi(), false, false, true)))
	v.add_child(UiKit.button(Game.t("versus"), func(): start_run(randi(), false, false, true, "competitive")))
	var tip := UiKit.label(Game.t("couch_tip"), 14, Color(1, 1, 1, 0.8))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	v.add_child(UiKit.button(Game.t("back"), show_menu))
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
	menu_scooter = s
	s.freeze = true
	s.controls_enabled = false
	s.set_physics_process(false)
	turntable.add_child(s)
	for k in ["pizza", "coffee", "soup", "jelly", "cake"]:
		s.rack.mods = {"capacity": 9}
		s.rack.add_item(FoodItem.new(k))
	s.rack.items[3].tilt = Vector2(0.12, 0.05)
	s.rack.items[4].tilt = Vector2(-0.18, 0.08)
	s.rack._update_visuals()
	var cam := Camera3D.new()
	menu_cam = cam
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


func show_character() -> void:
	_build_menu_scene()
	menu_cam.position = Vector3(-1.5, 1.75, 1.9)
	menu_cam.look_at(Vector3(-0.35, 1.45, 0))
	var root := _screen(false)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 40)
	v.custom_minimum_size = Vector2(340, 0)
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	v.add_child(UiKit.label(Game.t("character"), 39, UiKit.GOLD))
	var look: Dictionary = Game.settings.look
	for slot in Courier.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := UiKit.label(Game.t(slot), 15)
		name_l.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_l)
		var vals: Array = Courier.SLOTS[slot]
		var cur = vals[int(look.get(slot, 0)) % vals.size()]
		var val_l := UiKit.label(Courier.label(str(cur), Game.lang()) if not str(cur).begins_with("#") else "■■■", 15, Color(cur) if str(cur).begins_with("#") else Color.WHITE)
		val_l.custom_minimum_size = Vector2(130, 0)
		var minus := UiKit.button("<", func(): _change_look(slot, -1))
		var plus := UiKit.button(">", func(): _change_look(slot, 1))
		row.add_child(minus)
		row.add_child(val_l)
		row.add_child(plus)
		v.add_child(row)
	v.add_child(UiKit.button(Game.t("random"), func():
		var l := {}
		for slot in Courier.SLOTS:
			l[slot] = randi() % Courier.SLOTS[slot].size()
		_set_look(l)))
	v.add_child(UiKit.button(Game.t("back"), show_menu))
	_focus_first(v)


func _change_look(slot: String, dir: int) -> void:
	_set_look(Courier.cycle(Game.settings.look, slot, dir))


func _set_look(l: Dictionary) -> void:
	Game.settings.look = l
	Game.write_save()
	if menu_scooter:
		menu_scooter.set_look(l)
	show_character()


var _rebinding := ""


func show_keys() -> void:
	var root := _screen()
	var v := _center_box(root, 500)
	v.add_child(UiKit.label(Game.t("keys"), 34, UiKit.GOLD))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	for a in Game.REBINDABLE:
		g.add_child(UiKit.label(Game.t("a_" + a), 18))
		var label := Game.t("press_key") if _rebinding == a else Game.key_name(a)
		g.add_child(UiKit.button(label, func():
			_rebinding = a
			show_keys()))
	v.add_child(g)
	v.add_child(UiKit.button(Game.t("back"), show_settings))
	_focus_first(v)


func _input(e: InputEvent) -> void:
	if _rebinding != "" and e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode != KEY_ESCAPE:
			Game.rebind(_rebinding, e.physical_keycode)
		_rebinding = ""
		get_viewport().set_input_as_handled()
		show_keys()


func show_controls() -> void:
	var root := _screen()
	var v := _center_box(root, 760)
	v.add_child(UiKit.label(Game.t("controls"), 34, UiKit.GOLD))
	var en := Game.lang() == "en"
	var rows := [
		["Drive" if en else "Sür", "W/S + A/D", "RT/LT + L-stick"],
		["Balance tower" if en else "Kuleyi dengele", "Arrows / mouse" if en else "Oklar / fare", "R-stick"],
		["Throw top food" if en else "Üstteki yemeği fırlat", "SPACE", "A"],
		["Pick up" if en else "Yerden al", "F", "X"],
		["Horn / Get up" if en else "Korna / Kalk", "H / R", "B / Y"],
		["Screenshot" if en else "Ekran görüntüsü", "F12", "Select"],
		["Co-op passenger" if en else "Co-op yolcu", "Arrows, ENTER, R-Shift" if en else "Oklar, ENTER, Sağ Shift", "Pad 2"],
		["Split screen P2" if en else "Bölünmüş ekran 2.O", "Arrows, ENTER, R-Shift, R-Ctrl" if en else "Oklar, ENTER, Sağ Shift, Ctrl", "Pad 2"],
	]
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 40)
	for r in rows:
		g.add_child(UiKit.label(r[0], 15, UiKit.GOLD))
		g.add_child(UiKit.label(r[1], 15))
		g.add_child(UiKit.label(r[2], 15, Color(1, 1, 1, 0.75)))
	v.add_child(g)
	var tip := UiKit.label("Orange beam = restaurant, green beam = customer. Stop next to them, or throw the top item at the yellow balcony ring for 2x tips." if en else "Turuncu ışık = restoran, yeşil ışık = müşteri. Yanında dur ya da en üstteki yemeği balkondaki sarı halkaya fırlat: 2 kat bahşiş.", 14, Color(1, 1, 1, 0.85))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	v.add_child(UiKit.button(Game.t("back"), show_menu))
	_focus_first(v)


func show_settings() -> void:
	var root := _screen()
	var v := _center_box(root)
	v.add_child(UiKit.label(Game.t("settings"), 34, UiKit.GOLD))
	var lang_btn := UiKit.button("%s: %s" % [Game.t("lang"), I18n.NAMES.get(Game.lang(), Game.lang())], func():
		Game.settings.lang = I18n.LANGS[(I18n.LANGS.find(Game.lang()) + 1) % I18n.LANGS.size()]
		Game.write_save()
		show_settings())
	v.add_child(lang_btn)
	for key in ["volume", "music", "shake"]:
		v.add_child(UiKit.label(Game.t(key), 14))
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
	v.add_child(UiKit.button("%s: %s" % [Game.t("quality"), Game.t("q%d" % int(Game.settings.quality))], func():
		Game.settings.quality = (int(Game.settings.quality) + 1) % 3
		Game.write_save()
		show_settings()))
	var nc := Game.colors_unlocked()
	var cb := UiKit.button("%s %d/%d" % [Game.t("color"), int(Game.settings.color) + 1, nc], func():
		Game.settings.color = (int(Game.settings.color) + 1) % Game.colors_unlocked()
		Game.write_save()
		show_settings())
	cb.add_theme_color_override("font_color", Color(Game.SCOOTER_COLORS[int(Game.settings.color)]).lightened(0.3))
	v.add_child(cb)
	var fs := CheckButton.new()
	fs.text = Game.t("fullscreen")
	fs.button_pressed = Game.settings.fullscreen
	fs.toggled.connect(func(on):
		Game.settings.fullscreen = on
		Game.apply_settings())
	v.add_child(fs)
	var cb2 := CheckButton.new()
	cb2.text = Game.t("colorblind")
	cb2.button_pressed = Game.settings.get("colorblind", false)
	cb2.toggled.connect(func(on):
		Game.settings.colorblind = on
		Game.write_save())
	v.add_child(cb2)
	v.add_child(UiKit.button(Game.t("keys"), show_keys))
	v.add_child(UiKit.button(Game.t("controls"), show_controls))
	var cr := UiKit.label(Game.t("credits"), 14, Color(1, 1, 1, 0.6))
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cr)
	v.add_child(UiKit.button(Game.t("back"), func():
		Game.write_save()
		if world:
			show_pause()
		else:
			show_menu()))
	_focus_first(v)


# ---------------------------------------------------------------- run flow

func start_run(seed_value: int, coop_mode: bool, is_daily: bool, split_mode := false, mode := "normal") -> void:
	coop = coop_mode
	split = split_mode
	daily = is_daily
	run = RunState.new(seed_value, int(Game.save.unlock_level))
	if mode == "competitive":
		run.setup_competitive(2)   # always two teams: A and B (1v1, 2v1, 2v2, cooks + couriers...)
	var ds: Array = CityGen.THEMES.keys() if is_daily else Game.districts_unlocked()
	run.theme = ds[run.rng.randi() % ds.size()]
	Game.save.runs += 1
	start_day()


func start_day() -> void:
	if Net.online and Net.is_host():
		remote_start_day.rpc(run.to_dict())
	_build_day()


@rpc("authority", "reliable")
func remote_start_day(d: Dictionary) -> void:
	run = RunState.from_dict(d)
	coop = false
	split = false
	_build_day()


func _build_day() -> void:
	_free_world()
	_free_menu_scene()
	_clear_ui()
	get_tree().paused = false
	world = World.new()
	world.name = "World"
	world.setup(run, coop, split)
	world.shift_ended.connect(show_summary)
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE


func _free_world() -> void:
	if world:
		remove_child(world)   # free the name "World" right away: RPC paths must match on every peer
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
		var names := ["burger", "drinks", "icecream", "sushi", "cake", "jelly", "coffee"]
		return Game.t("unlock") % Game.up(Game.food_name(names[lvl - 1]))
	return ""


func show_summary(result: Dictionary) -> void:
	if run.competitive():
		run.end_shift()
		var light := {"top": result.top, "earned": result.earned}
		if Net.online:
			remote_comp.rpc(run.to_dict(), light)
		show_comp(light)
		return
	var paid := run.end_shift()
	if Net.online:
		remote_summary.rpc({"top": result.top, "earned": result.earned}, run.to_dict(), paid)
	if world:
		world.hud.visible = false
	var root := _screen()
	var v := _center_box(root, 760)
	v.add_child(UiKit.label(Game.t("shift_over") + " — " + Game.t("day") + " %d" % run.day, 31, UiKit.GOLD))
	v.add_child(UiKit.label("%s: $%d    %s: $%d" % [Game.t("earned"), result.earned, Game.t("rent"), run.rent()], 18))
	var verdict := UiKit.label(Game.t("paid") if paid else Game.t("fired"), 28, UiKit.GOOD if paid else UiKit.BAD)
	v.add_child(verdict)
	if run.warned:
		v.add_child(UiKit.label(Game.t("warned"), 15, UiKit.GOLD))
	if result.top.size() > 0:
		v.add_child(UiKit.label(Game.t("best_reviews"), 15, Color(1, 1, 1, 0.8)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		for rv in result.top:
			h.add_child(Hud.review_card(rv, 240))
		v.add_child(h)
	v.add_child(UiKit.label("TIP OVER · " + Game.t("save_card"), 14, Color(1, 1, 1, 0.6)))
	if paid:
		run.day += 0  # day advances when leaving the garage
		var unlock := _next_day_unlock_preview()
		if unlock != "":
			v.add_child(UiKit.label(unlock, 17, UiKit.GOLD))
		v.add_child(UiKit.button(Game.t("garage"), show_garage))
	else:
		v.add_child(UiKit.label(Game.t("stats") % [run.stats.deliveries, run.stats.crashes, run.stats.throws], 15))
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


## Client view of the end of a shift: same cards, but the host runs the garage.
@rpc("authority", "reliable")
func remote_summary(result: Dictionary, d: Dictionary, paid: bool) -> void:
	run = RunState.from_dict(d)
	if world:
		world.hud.visible = false
	var root := _screen()
	var v := _center_box(root, 760)
	v.add_child(UiKit.label(Game.t("shift_over") + " — " + Game.t("day") + " %d" % run.day, 31, UiKit.GOLD))
	v.add_child(UiKit.label("%s: $%d" % [Game.t("earned"), result.earned], 18))
	v.add_child(UiKit.label(Game.t("paid") if paid else Game.t("fired"), 28, UiKit.GOOD if paid else UiKit.BAD))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	for rv in result.top:
		h.add_child(Hud.review_card(rv, 240))
	v.add_child(h)
	v.add_child(UiKit.label(Game.t("waiting_host"), 17, Color(1, 1, 1, 0.8)))
	v.add_child(UiKit.button(Game.t("leave"), func():
		Net.leave()
		show_menu()))


@rpc("authority", "reliable")
func remote_comp(d: Dictionary, light: Dictionary) -> void:
	run = RunState.from_dict(d)
	show_comp(light)


var _comp_light := {}


## Competitive end of round: leaderboard, the new difficulty card, and each player's own shop.
func show_comp(light: Dictionary) -> void:
	_comp_light = light
	if world:
		world.hud.visible = false
	var root := _screen()
	var v := _center_box(root, 860)
	var order: Array = range(run.players)
	order.sort_custom(func(a, b): return run.earned_by[a] > run.earned_by[b])
	if run.finished:
		v.add_child(UiKit.label(Game.team_name(run.winner()) + " " + Game.t("winner"), 36, UiKit.GOLD))
		if Net.online and run.winner() == Net.team_of(Net.my_id()):
			SteamBridge.achieve("COMPETITIVE_WIN")
	else:
		v.add_child(UiKit.label("%s %d/%d" % [Game.t("round"), run.day, RunState.ROUNDS], 31, UiKit.GOLD))
	v.add_child(UiKit.label(Game.t("leaderboard"), 15, Color(1, 1, 1, 0.8)))
	for rank in order.size():
		var i: int = order[rank]
		v.add_child(UiKit.label("%d. %s   $%d" % [rank + 1, Game.team_name(i), run.earned_by[i]], 30 if rank == 0 else 26))
	if light.get("top", []).size() > 0:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		for rv in light.top:
			h.add_child(Hud.review_card(rv, 240))
		v.add_child(h)
	if run.finished:
		v.add_child(UiKit.button(Game.t("menu"), func():
			Net.leave()
			show_menu()))
		_focus_first(v)
		return
	if run.cards.size() > 0:
		var ct := Game.card_text(run.cards.back())
		v.add_child(UiKit.label("%s: %s — %s" % [Game.t("new_card"), ct[0], ct[1]], 17, UiKit.BAD.lightened(0.3)))
	# local split shows both shops; online shows only mine
	var mine: Array = [Net.team_of(Net.my_id())] if Net.online else range(run.players)
	var shops := HBoxContainer.new()
	shops.add_theme_constant_override("separation", 24)
	v.add_child(shops)
	for p in mine:
		var col := VBoxContainer.new()
		col.add_child(UiKit.label("%s  $%d" % [Game.t("your_shop") if Net.online else Game.team_name(p), run.wallets[p]], 15, UiKit.GOLD))
		for u in run.shops[p]:
			var txt := Game.upgrade_text(u)
			var cost: int = RunState.UPGRADES[u].cost + 15 * run.owned_by[p].count(u)
			var b := UiKit.button("%s $%d" % [txt[0], cost], func(): _comp_buy(p, u))
			b.tooltip_text = txt[1]
			b.disabled = run.wallets[p] < cost
			col.add_child(b)
			var d := UiKit.label(txt[1], 14, Color(1, 1, 1, 0.75))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(320, 0)
			col.add_child(d)
		shops.add_child(col)
	if Net.is_host():
		v.add_child(UiKit.button(Game.t("next_round"), func():
			run.next_day()
			start_day()))
	else:
		v.add_child(UiKit.label(Game.t("waiting_host"), 15, Color(1, 1, 1, 0.8)))
	_focus_first(v)


func _comp_buy(p: int, u: String) -> void:
	if Net.online and not Net.is_host():
		request_buy.rpc_id(1, u)
		return
	if run.buy_for(p, u):
		if Net.online:
			remote_comp.rpc(run.to_dict(), _comp_light)
		show_comp(_comp_light)


@rpc("any_peer", "reliable")
func request_buy(u: String) -> void:
	if not multiplayer.is_server() or not RunState.UPGRADES.has(u):
		return
	var p := Net.team_of(multiplayer.get_remote_sender_id())
	if run.buy_for(p, u):
		remote_comp.rpc(run.to_dict(), _comp_light)
		show_comp(_comp_light)


var online_mode := "normal"


func show_online() -> void:
	_build_menu_scene()
	var root := _screen()
	var v := _center_box(root, 500)
	v.add_child(UiKit.label(Game.t("online"), 34, UiKit.GOLD))
	var name_e := LineEdit.new()
	name_e.text = str(Game.settings.get("name", "Courier"))
	name_e.placeholder_text = Game.t("your_name")
	name_e.max_length = 16
	name_e.text_changed.connect(func(t):
		Game.settings.name = t
		Game.write_save())
	v.add_child(name_e)
	if not Net.online and SteamBridge.peer_supported():
		v.add_child(UiKit.button(Game.t("steam_host"), func():
			if Net.host_steam() == OK:
				show_online()))
		v.add_child(UiKit.label(Game.t("steam_tip"), 14, Color(1, 1, 1, 0.75)))
	if Net.online and SteamBridge.lobby_id != 0 and Net.is_host():
		v.add_child(UiKit.button(Game.t("invite"), SteamBridge.invite_friends))
	if not Net.online:
		var ip_e := LineEdit.new()
		ip_e.text = str(Game.settings.get("last_ip", "127.0.0.1"))
		ip_e.placeholder_text = "IP"
		v.add_child(ip_e)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiKit.button(Game.t("host"), func():
			if Net.host() == OK:
				show_online()
			else:
				_toast("Port %d busy" % Net.PORT)))
		row.add_child(UiKit.button(Game.t("join"), func():
			Game.settings.last_ip = ip_e.text.strip_edges()
			Game.write_save()
			if Net.join(ip_e.text.strip_edges()) == OK:
				show_online()))
		v.add_child(row)
		var tip := UiKit.label(Game.t("online_tip"), 14, Color(1, 1, 1, 0.75))
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tip)
	else:
		v.add_child(UiKit.label(Game.t("players") + " (%d/%d)" % [Net.players.size(), Net.MAX_PLAYERS], 17))
		for id in Net.order():
			var info: Dictionary = Net.players[id]
			var role := (" — " + Game.t("r_" + str(info.get("role", "drive")))) if not Net.drivers().has(id) else ""
			role += "  [" + Game.team_label(Net.team_of(id)) + "]"
			var l := UiKit.label(("★ " if id == 1 else "• ") + str(info.get("name", "?")) + role, 17, Color(Game.SCOOTER_COLORS[int(info.get("color", 0)) % 8]).lightened(0.3))
			v.add_child(l)
		v.add_child(UiKit.button("%s: %s" % [Game.t("role"), Game.t("r_" + Net.role)], func():
			Net.role = Net.ROLES[(Net.ROLES.find(Net.role) + 1) % Net.ROLES.size()]
			Net.update_me()
			show_online()))
		var my_team := Net.team_of(Net.my_id())
		v.add_child(UiKit.button("%s: %s" % [Game.t("team"), Game.team_label(my_team)], func():
			Net.team = 1 - Net.team_of(Net.my_id())
			Net.update_me()
			show_online()))
		if Net.is_host():
			v.add_child(UiKit.button("%s: %s" % [Game.t("mode"), Game.t("m_" + online_mode)], func():
				online_mode = "competitive" if online_mode == "normal" else "normal"
				show_online()))
			var b := UiKit.button(Game.t("start"), func(): start_run(randi(), false, false, false, online_mode))
			v.add_child(b)
		else:
			v.add_child(UiKit.label(Game.t("waiting_host"), 15, Color(1, 1, 1, 0.8)))
	v.add_child(UiKit.button(Game.t("back"), func():
		Net.leave()
		show_menu()))
	_focus_first(v)


func show_garage() -> void:
	var root := _screen()
	var v := _center_box(root, 800)
	v.add_child(UiKit.label(Game.t("garage"), 34, UiKit.GOLD))
	v.add_child(UiKit.label("%s: $%d    %s %d: $%d" % [Game.t("money"), run.money, Game.t("rent"), run.day + 1, RunState.rent_for(run.day + 1)], 17))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for u in run.shop:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(240, 170)
		var pv := VBoxContainer.new()
		p.add_child(pv)
		var txt := Game.upgrade_text(u)
		pv.add_child(UiKit.label(txt[0], 18, UiKit.GOLD))
		var d := UiKit.label(txt[1], 14)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(210, 70)
		pv.add_child(d)
		if run.owned.count(u) > 0:
			pv.add_child(UiKit.label("x%d %s" % [run.owned.count(u), Game.t("owned")], 14, UiKit.GOOD))
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
		var o := UiKit.label(Game.t("owned") + ": " + ", ".join(names), 14, Color(1, 1, 1, 0.8))
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
		if run.day >= 5:
			SteamBridge.achieve("DAY_5")
		if run.day >= 10:
			SteamBridge.achieve("DAY_10")
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
		v.add_child(UiKit.label(Game.t("chaos") + ": " + " · ".join(preview), 14, Color("#ffd166")))
	_focus_first(v)


# ---------------------------------------------------------------- pause / input

func show_pause() -> void:
	var root := _screen()
	paused_panel = root
	var v := _center_box(root)
	v.add_child(UiKit.label("II", 34, UiKit.GOLD))
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
	elif e.is_action_pressed("pause") and world and (world.running or world.client) and Net.online:
		if paused_panel:
			resume()
		else:
			show_pause()
	elif e.is_action_pressed("pause") and world and world.running:
		if get_tree().paused:
			resume()
		else:
			get_tree().paused = true
			show_pause()


func _toast(msg: String) -> void:
	if toast and is_instance_valid(toast):
		toast.queue_free()
	toast = UiKit.label(msg, 14, Color.WHITE)
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
	if args.has("lang"):
		Game.settings.lang = args.lang
	if args.has("quality"):
		Game.settings.quality = int(args.quality)
	var out: String = args.get("out", "user://autotest")
	DirAccess.make_dir_recursive_absolute(out)
	if args.has("nethost") or args.has("netjoin"):
		await _autotest_net()
		return
	var chaos: String = args.get("chaos", "")
	run = RunState.new(int(args.get("seed", "3")), int(args.get("unlocks", "5")))
	run.theme = args.get("theme", "bazaar")
	run.tod = args.get("tod", run.tod)
	if args.get("mode", "") == "competitive":
		run.setup_competitive(2)
	if chaos != "":
		run.chaos = Array(chaos.split(","))
	if args.has("menu"):
		show_menu()
		if args.has("character"):
			Game.settings.look = {"skin": 2, "jacket": 3, "helmet": int(args.character), "helmet_color": 4, "accessory": 2}
			menu_scooter.set_look(Game.settings.look)
			show_character()
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
	if args.has("occ"):
		get_viewport().use_occlusion_culling = args.occ == "1"
	if args.has("walker_check"):   # place a pedestrian and a bin right in front of the camera
		var wk: Node3D = w.walkers[0]
		wk.set_physics_process(false)
		wk.global_position = w.scooter.global_position - w.scooter.global_basis.z * 4.0 + w.scooter.global_basis.x * 1.2
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
			print("t=%.1f speed=%.1f items=%d loose=%d crashed=%s money=%d objects=%d draws=%d" % [t, w.scooter.speed, w.scooter.rack.items.size(), w.loose.size(), w.scooter.is_crashed, run.money,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()


## Two processes on one machine:
##   godot --headless --fixed-fps 60 --path . -- --autotest --nethost --secs=40
##   godot --headless --fixed-fps 60 --path . -- --autotest --netjoin=127.0.0.1 --secs=40
func _autotest_net() -> void:
	var secs := float(args.get("secs", "30"))
	Net.role = "ride" if args.has("ride") else ("cook" if args.has("cook") else "drive")
	if args.has("nethost"):
		Net.host()
		var waited := 0.0
		while Net.players.size() < int(args.get("wait", "2")) and waited < 20.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		print("NET host sees players: ", Net.players.size())
		start_run(int(args.get("seed", "4")), false, false, false, args.get("mode", "normal"))
	else:
		Net.join(args.netjoin)
		var waited := 0.0
		while world == null and waited < 25.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		if world == null:
			print("NET FAIL client never got a world")
			get_tree().quit(1)
			return
	var w := world
	if args.has("len"):
		w.time_left = float(args.len)
	await get_tree().process_frame
	var bot := Autopilot.new(w)
	var t := 0.0
	var start_pos: Array = w.scooters.map(func(s): return s.global_position)
	var cooked := 0
	var max_players := 0   # the peer may quit a moment before we check
	var max_drivers := 0
	while t < secs and is_instance_valid(w):
		max_players = maxi(max_players, Net.players.size())
		max_drivers = maxi(max_drivers, Net.drivers().size())
		if args.has("crash") and Net.is_host() and t >= float(args.crash):
			args.erase("crash")
			w.scooter.crash(-w.scooter.global_basis.z * 12.0)
		if Net.is_cook(Net.my_id()):
			if int(t * 60.0) % 90 == 0:
				for o in w.orders:
					if o.state == "offer" and not o.get("ready", true):
						w.submit_cook(o.id, 0.8)
						cooked += 1
						break
		else:
			w.scooter.external_input = bot.drive(1.0 / 60.0)
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if args.has("out") and int(t * 60.0) % 300 == 0:
			get_viewport().get_texture().get_image().save_png("%s/net_%02d.png" % [args.out, int(t)])
	if not is_instance_valid(w):
		print("NET FAIL world vanished (disconnected?)")
		get_tree().quit(1)
		return
	var moved: Array = []
	for i in w.scooters.size():
		moved.append(snappedf(w.scooters[i].global_position.distance_to(start_pos[i]), 0.1))
	print("NET %s scooters=%d local=%d moved=%s money=%d orders=%d deliveries=%d" % ["host" if Net.is_host() else "client",
		w.scooters.size(), w.local_index, moved, run.money, w.orders.size(), w.reviews.size()])
	print("NET replays shown: ", w.replays_shown)
	var ok: bool = max_players >= 2 and w.scooters.size() == max_drivers and moved.all(func(m): return m > 5.0) and w.orders.size() > 0
	if Net.cooks().size() > 0:
		var ready := w.orders.filter(func(o): return o.get("ready", true) or o.state != "offer").size()
		print("NET cook: cooked=%d ready_or_taken=%d" % [cooked, ready])
		ok = ok and ready > 0
	print("NET RESULT ", "PASS" if ok else "FAIL players=%d drivers=%d" % [max_players, max_drivers])
	if Net.is_host():
		await get_tree().create_timer(3.0).timeout   # let the client finish first
	get_tree().quit(0 if ok else 1)
