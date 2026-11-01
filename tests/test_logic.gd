extends RefCounted
## Unit tests for pure game logic (food physics, tips, reviews, run state).


func _sim(item: FoodItem, accel: Vector2, seconds: float, level := 0, mods := {}) -> float:
	var spilled := 0.0
	for i in int(seconds * 60.0):
		spilled += item.step(1.0 / 60.0, accel, level, Vector2.ZERO, mods)
	return spilled


func test_heat_decays(t) -> void:
	var p := FoodItem.new("pizza")
	p.step_heat(10.0)
	t.check(is_equal_approx(p.heat, 100.0 - 3.2), "pizza loses 0.32/s")
	var p2 := FoodItem.new("pizza")
	p2.step_heat(10.0, 0.5)
	t.check(p2.heat > p.heat, "thermo mult slows cooling")
	p.step_heat(10000.0)
	t.check(p.heat == 0.0, "heat clamps at 0")


func test_still_food_stays_put(t) -> void:
	var s := FoodItem.new("soup")
	var spilled := _sim(s, Vector2.ZERO, 5.0)
	t.check(spilled == 0.0 and s.integrity == 100.0, "soup at rest does not spill")
	t.check(s.tilt.length() < 0.001, "no tilt at rest")


func test_gentle_driving_ok(t) -> void:
	var s := FoodItem.new("soup")
	var spilled := _sim(s, Vector2(0, 2.0), 3.0)
	t.check(spilled == 0.0, "gentle acceleration keeps soup in bowl")
	var p := FoodItem.new("pizza")
	_sim(p, Vector2(4.0, 0), 3.0)
	t.check(p.tilt.length() < p.fall_limit(), "pizza survives a normal turn")


func test_hard_brake_spills_soup(t) -> void:
	var s := FoodItem.new("soup")
	var spilled := _sim(s, Vector2(0, -14.0), 1.0)
	t.check(spilled > 5.0, "hard brake spills soup (spilled %.1f)" % spilled)
	t.check(s.spilled, "spilled flag set")
	var lid := FoodItem.new("soup")
	var spilled_lid := _sim(lid, Vector2(0, -14.0), 1.0, 0, {"spill_thr_mult": 1.4})
	t.check(spilled_lid < spilled, "lid upgrade reduces spill")


func test_brake_tilts_forward(t) -> void:
	var p := FoodItem.new("pizza")
	_sim(p, Vector2(0, -8.0), 0.5)
	t.check(p.tilt.y > 0.0, "braking tilts food forward")
	var q := FoodItem.new("pizza")
	_sim(q, Vector2(-8.0, 0), 0.5)
	t.check(q.tilt.x > 0.0, "left turn pushes food to the right")


func test_higher_wobbles_more(t) -> void:
	var a := FoodItem.new("burger")
	var b := FoodItem.new("burger")
	_sim(a, Vector2(6.0, 0), 1.0, 0)
	_sim(b, Vector2(6.0, 0), 1.0, 3)
	t.check(b.tilt.length() > a.tilt.length(), "top of stack wobbles more")


func test_balance_counters(t) -> void:
	var a := FoodItem.new("pizza")
	var b := FoodItem.new("pizza")
	for i in 60:
		a.step(1.0 / 60.0, Vector2(-8.0, 0), 0, Vector2.ZERO)
		b.step(1.0 / 60.0, Vector2(-8.0, 0), 0, Vector2(-1.0, 0))
	t.check(absf(b.tilt.x) < absf(a.tilt.x), "leaning against the turn reduces tilt")


func test_jolt_damages_fragile(t) -> void:
	var s := FoodItem.new("sushi")
	s.jolt(6.0, Vector2(1, 0))
	t.check(s.integrity < 100.0, "big jolt hurts sushi")
	var p := FoodItem.new("pizza")
	p.jolt(1.0, Vector2(1, 0))
	t.check(p.integrity == 100.0, "tiny bump is harmless")
	var q := FoodItem.new("sushi")
	q.jolt(6.0, Vector2(1, 0), {"jolt_mult": 0.4})
	t.check(q.integrity > s.integrity, "shocks reduce jolt damage")


func test_fall_spills_liquid(t) -> void:
	var s := FoodItem.new("soup")
	s.on_fall()
	t.check(s.integrity <= 45.0 and s.dropped, "falling soup loses most of the bowl")


func test_tip_perfect(t) -> void:
	var p := FoodItem.new("pizza")
	var r := Tips.compute(p, {"time_left": 30.0, "time_total": 40.0})
	t.check(r.tip == 25, "perfect pizza tip = 10 + 10 heat + 5 speed (got %d)" % r.tip)
	t.check(r.stars == 5, "perfect = 5 stars")
	t.check("perfect" in r.tags and "fast" in r.tags, "perfect tags")


func test_tip_cold_and_late(t) -> void:
	var p := FoodItem.new("pizza")
	p.heat = 30.0
	var r := Tips.compute(p, {"time_left": -5.0, "time_total": 40.0})
	t.check(r.tip == 10, "cold + late = base only (got %d)" % r.tip)
	t.check(r.stars <= 3, "cold food max 3 stars")
	t.check("cold" in r.tags and "late" in r.tags, "cold/late tags")


func test_tip_throw_doubles(t) -> void:
	var a := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "time_total": 40.0})
	var b := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "time_total": 40.0, "thrown": true})
	t.check(b.tip == a.tip * 2, "balcony throw doubles the tip")
	t.check(Reviews.primary_tag(b.tags).begins_with("thrown"), "throw review tag")


func test_tip_destroyed(t) -> void:
	var s := FoodItem.new("soup")
	s.integrity = 5.0
	var r := Tips.compute(s, {"time_left": 10.0, "time_total": 40.0, "thrown": true})
	t.check(r.tip == 2 and r.stars == 1, "destroyed food = pity tip")
	t.check(Reviews.primary_tag(r.tags) == "destroyed", "destroyed tag wins")


func test_tip_combo_and_quirks(t) -> void:
	var base := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "time_total": 40.0})
	var combo := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "time_total": 40.0, "combo": 2})
	t.check(combo.tip > base.tip, "combo increases tip")
	var yeet_hand := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "quirk": "yeet"})
	t.check(yeet_hand.tip < base.tip, "yeet customer hates hand delivery")
	var vip := Tips.compute(FoodItem.new("pizza"), {"time_left": 10.0, "quirk": "vip"})
	t.check(vip.tip == base.tip * 2, "vip doubles tip")


func test_reviews(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for lang in ["en", "tr"]:
		for tag in Reviews.LINES[lang]:
			t.check(Reviews.LINES[lang][tag].size() >= 3, "%s/%s has >=3 lines" % [lang, tag])
	t.check(Reviews.LINES.en.keys() == Reviews.LINES.tr.keys(), "en/tr have the same tags")
	var r := Reviews.make("soup", ["spilled"], "tr", rng)
	t.check(r.line.length() > 5 and not "{food}" in r.line, "review line filled: " + r.line)
	var r2 := Reviews.make("soup", ["spilled"], "xx", rng)
	t.check(r2.tag == "spilled", "unknown language falls back to en")
	t.check(Reviews.funny_score("thrown_perfect", 5) > Reviews.funny_score("ok", 3), "funny ranking")


func test_run_rent_and_shop(t) -> void:
	t.check(RunState.rent_for(1) == 50, "day 1 rent 50")
	t.check(RunState.rent_for(4) > RunState.rent_for(3), "rent grows")
	var r := RunState.new(42)
	t.check(r.chaos.is_empty(), "day 1 has no chaos")
	r.add_tip(30)
	t.check(r.end_shift() and r.warned and not r.fired and r.money == 0, "first missed rent: warning, savings gone")
	r.add_tip(10)
	t.check(not r.end_shift() and r.fired, "second missed rent -> fired")
	var r2 := RunState.new(42)
	r2.add_tip(120)
	t.check(r2.end_shift() and r2.money == 70, "rent paid")
	t.check(r2.shop.size() == 3, "3 upgrade cards offered")
	var u: String = r2.shop[0]
	r2.money = 999
	t.check(r2.buy(u) and u in r2.owned, "buy upgrade")
	t.check(not r2.buy(u), "can't buy the same card twice from one shop")
	r2.next_day()
	t.check(r2.day == 2 and r2.chaos.size() == 1, "day 2 has one chaos event")


func test_run_mods(t) -> void:
	var r := RunState.new(1)
	r.owned = ["thermo", "rocket", "rack", "rack"]
	var m := r.mods()
	t.check(is_equal_approx(m.heat_loss_mult, 0.6), "thermo mult")
	t.check(m.capacity == 5, "two racks = +2 capacity")
	t.check(m.slosh_mult > 1.0, "rocket side effect: more slosh")


func test_run_deterministic(t) -> void:
	var a := RunState.new(99)
	var b := RunState.new(99)
	for i in 5:
		a.next_day()
		b.next_day()
	t.check(a.chaos == b.chaos, "same seed = same chaos (daily run)")
	t.check(a.pick_food() == b.pick_food(), "same seed = same orders")


func test_city_gen(t) -> void:
	var a := CityGen.generate(5)
	var b := CityGen.generate(5)
	t.check(a.lots.size() > 40, "city has lots (%d)" % a.lots.size())
	t.check(a.rest_ids.size() == 5, "5 restaurants")
	t.check(a.lots[a.rest_ids[0]].center == b.lots[b.rest_ids[0]].center, "deterministic city")
	for k in FoodItem.DEFS:
		var r := CityGen.rest_for(a, k)
		t.check(a.lots[r].rest == CityGen.FOOD_REST[k], "restaurant for " + k)
	for lot in a.lots:
		t.check(lot.balcony.y < lot.size.y + 0.1, "balcony below roof")
		t.check(lot.door.distance_to(lot.curb) < 12.0, "curb near door")
	var c := CityGen.generate(6)
	t.check(c.lots[0].size != a.lots[0].size, "different seed differs")


func test_themes_and_big_days(t) -> void:
	for th in CityGen.THEMES:
		var c := CityGen.generate(9, 5, 8, th)
		t.check(c.rest_ids.size() == 5, "theme %s has 5 restaurants" % th)
	var dt := CityGen.generate(9, 5, 8, "downtown")
	var bz := CityGen.generate(9, 5, 8, "bazaar")
	var tall := func(c): return c.lots.filter(func(l): return l.size.y > 20.0).size()
	t.check(tall.call(dt) > tall.call(bz), "downtown is taller than the bazaar")
	var r := RunState.new(1)
	t.check(not r.big_order_day(), "day 1 is normal")
	r.day = 3
	t.check(r.big_order_day(), "day 3 brings the wedding cake")


func test_courier_look(t) -> void:
	var l := Courier.default_look()
	for slot in Courier.SLOTS:
		var n: int = Courier.SLOTS[slot].size()
		var x := l
		for i in n:
			x = Courier.cycle(x, slot, 1)
		t.check(x[slot] == l[slot], "cycling %s wraps around" % slot)
		t.check(Courier.cycle(l, slot, -1)[slot] == n - 1 or l[slot] != 0, "cycling %s backwards wraps" % slot)
	var root := Node3D.new()
	for h in Courier.HELMETS.size():
		var look := l.duplicate()
		look.helmet = h
		look.accessory = h % Courier.ACCESSORIES.size()
		Courier.build(root, look)
	t.check(root.get_child_count() > 20, "courier builds every helmet/accessory")
	root.free()


func test_run_sync_roundtrip(t) -> void:
	var r := RunState.new(77, 2)
	r.day = 4
	r.money = 123
	r.owned = ["thermo", "rack"]
	r.roll_chaos()
	var c := RunState.from_dict(r.to_dict())
	t.check(c.day == 4 and c.money == 123 and c.owned == r.owned, "run state survives the network")
	t.check(c.chaos == r.chaos and c.tod == r.tod and c.theme == r.theme, "chaos/tod/theme synced")
	t.check(c.mods().capacity == r.mods().capacity, "same mods on both sides")


func test_competitive(t) -> void:
	var r := RunState.new(5)
	r.setup_competitive(3)
	r.add_tip(40, 1)
	r.add_tip(25, 2)
	t.check(r.wallets == [0, 40, 25] and r.money == 0, "tips go to the player's own wallet")
	t.check(r.winner() == 1, "richest player leads")
	t.check(r.end_shift() and r.cards.size() == 1, "each round adds a difficulty card")
	t.check(r.shops[1].size() == 3, "every player gets their own shop")
	var u: String = r.shops[1][0]
	r.wallets[1] = 500
	t.check(r.buy_for(1, u) and u in r.owned_by[1] and not u in r.owned_by[0], "upgrades are personal")
	r.next_day()
	for i in RunState.ROUNDS:
		r.end_shift()
		r.next_day()
	t.check(r.finished, "competitive ends after the last round")
	t.check(r.cards.size() >= 5, "cards stacked up (%d)" % r.cards.size())
	var c := RunState.from_dict(r.to_dict())
	t.check(c.competitive() and c.wallets == r.wallets and c.cards == r.cards, "competitive state syncs")
	var m := RunState.new(1)
	m.setup_competitive(2)
	m.cards = ["impatient", "greedy"]
	t.check(m.mods(0).timer_mult < 1.0 and m.mods(0).capacity == 4, "card effects apply")


func test_cook_quality(t) -> void:
	t.check(Kitchen.quality(0.5, 0.5) == 1.0, "dead center = perfect")
	t.check(Kitchen.quality(0.9, 0.2) == 0.0, "way off = ruined")
	t.check(Kitchen.quality(0.55, 0.5) > Kitchen.quality(0.7, 0.5), "closer is better")


func test_languages(t) -> void:
	var tags: Array = Reviews.LINES.en.keys()
	for lang in I18n.REVIEWS:
		for tag in tags:
			t.check(I18n.REVIEWS[lang].has(tag) and I18n.REVIEWS[lang][tag].size() >= 3, "%s review lines for %s" % [lang, tag])
		t.check(I18n.FOOD[lang].keys() == Reviews.FOOD_NAMES.en.keys(), lang + " has every food name")
		t.check(I18n.UPGRADES[lang].keys().size() == RunState.UPGRADES.size(), lang + " has every upgrade")
		t.check(I18n.CHAOS[lang].keys().size() == RunState.CHAOS.size(), lang + " has every chaos event")
		t.check(I18n.UI[lang].size() >= 100, lang + " UI mostly translated")
		var rng := RandomNumberGenerator.new()
		var r := Reviews.make("soup", ["spilled"], lang, rng)
		t.check(not "{food}" in r.line, lang + " review filled")
	for lang in I18n.LANGS:
		t.check(I18n.NAMES.has(lang), "language has a display name: " + lang)
