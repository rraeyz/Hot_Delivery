class_name Tips
extends RefCounted
## Tip + star + review-tag calculation. Pure, unit-tested.


## ctx keys: time_left (s), time_total (s), thrown (bool), crashed (bool),
## combo (int, deliveries in a row), quirk (String), mods (Dictionary)
static func compute(item: FoodItem, ctx: Dictionary) -> Dictionary:
	var mods: Dictionary = ctx.get("mods", {})
	var time_left: float = ctx.get("time_left", 0.0)
	var time_total: float = maxf(1.0, ctx.get("time_total", 60.0))
	var thrown: bool = ctx.get("thrown", false)
	var quirk: String = ctx.get("quirk", "")
	var combo: int = ctx.get("combo", 0)
	var hot_thr: float = mods.get("heat_bonus_thr", 80.0)
	var pay: float = item.def.pay
	var tags := tags_for(item, ctx)

	if item.destroyed():
		return {"tip": 2, "stars": 1, "tags": tags}

	var tip := pay * item.integrity / 100.0
	if item.heat >= hot_thr:
		tip += 10.0
	elif item.heat >= 50.0:
		tip += 4.0
	if time_left > 0.0:
		tip += 5.0
	if quirk == "picky" and item.heat < 90.0:
		tip *= 0.3
	if quirk == "vip":
		tip *= 2.0
	if thrown:
		tip *= mods.get("throw_mult", 2.0)
		if quirk == "yeet":
			tip *= 1.5
	elif quirk == "yeet":
		tip *= 0.25
	tip *= 1.0 + 0.2 * mini(combo, 5)
	tip *= mods.get("tip_mult", 1.0)

	var score := 0.45 * item.integrity / 100.0 + 0.35 * item.heat / 100.0
	score += 0.2 if time_left > 0.0 else 0.0
	if quirk == "vip":
		score -= 0.15
	if thrown:
		score += 0.1
	var stars := clampi(int(round(score * 5.0)), 1, 5)
	stars = mini(5, stars + int(mods.get("bonus_star", 0)))
	if item.heat < 50.0 or item.integrity < 50.0:
		stars = mini(stars, 3)
	return {"tip": int(round(tip)), "stars": stars, "tags": tags}


static func tags_for(item: FoodItem, ctx: Dictionary) -> Array:
	var tags := []
	var time_left: float = ctx.get("time_left", 0.0)
	var time_total: float = maxf(1.0, ctx.get("time_total", 60.0))
	if item.destroyed():
		tags.append("destroyed")
	if item.is_liquid() and item.spilled and item.integrity < 70.0:
		tags.append("spilled")
	if ctx.get("thrown", false):
		tags.append("thrown")
	if ctx.get("crashed", false):
		tags.append("crash")
	if item.dropped:
		tags.append("dropped")
	if item.heat < 50.0:
		tags.append("melted" if item.is_cold() else "cold")
	if time_left <= 0.0:
		tags.append("late")
	elif time_left > time_total * 0.5:
		tags.append("fast")
	if item.integrity >= 90.0 and item.heat >= 80.0 and time_left > 0.0:
		tags.append("perfect")
	return tags
