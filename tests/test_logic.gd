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
	t.check(not r.end_shift() and r.fired, "can't pay rent -> fired")
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
