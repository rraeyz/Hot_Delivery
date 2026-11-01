class_name CityGen
extends RefCounted
## Generates a city layout as plain data (no nodes) so it is testable.
## Roads run along x = i*PITCH and z = i*PITCH for i in 0..n.

const PITCH := 46.0
const ROAD := 12.0
const BLOCK := 34.0
const REST_KINDS := ["pizza", "soup", "burger", "dessert", "sushi"]
const FOOD_REST := {"pizza": "pizza", "soup": "soup", "burger": "burger", "drinks": "burger",
	"icecream": "dessert", "cake": "dessert", "sushi": "sushi"}
const PALETTE := ["#f4a261", "#e76f51", "#2a9d8f", "#e9c46a", "#8ecae6", "#ffb4a2", "#b5838d",
	"#90be6d", "#f9c74f", "#cdb4db", "#a8dadc", "#ffd6a5"]


const THEMES := {
	"bazaar": {"palette": PALETTE, "park": 0.14, "tall": 0.12, "ramps": 5, "props": 70,
		"ground": "#2f3238", "outer": "#7cb518", "walk": "#b8b0a6", "sky": "#4ea8de", "cars": 0},
	"beach": {"palette": ["#ffe5b4", "#a8dadc", "#ffafcc", "#bde0fe", "#fdffb6", "#caffbf", "#ffc6ff", "#9bf6ff"],
		"park": 0.3, "tall": 0.03, "ramps": 9, "props": 90,
		"ground": "#3a3d42", "outer": "#f4e1a1", "walk": "#f1dca7", "sky": "#48cae4", "cars": -2},
	"downtown": {"palette": ["#6c757d", "#adb5bd", "#457b9d", "#1d3557", "#a8dadc", "#e5e5e5", "#ced4da", "#5c677d"],
		"park": 0.05, "tall": 0.45, "ramps": 3, "props": 50,
		"ground": "#25272b", "outer": "#55595f", "walk": "#9a9a9a", "sky": "#90e0ef", "cars": 6},
}


static func generate(seed_value: int, n: int = 5, bump_count: int = 8, theme := "bazaar") -> Dictionary:
	var th: Dictionary = THEMES[theme]
	var pal: Array = th.palette
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size := n * PITCH
	var blocks := []
	var lots := []
	for bx in n:
		for bz in n:
			var c := Vector3((bx + 0.5) * PITCH, 0, (bz + 0.5) * PITCH)
			var park := rng.randf() < float(th.park)
			blocks.append({"center": c, "park": park})
			if park:
				continue
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var w := rng.randf_range(10.5, 13.5)
				var d := rng.randf_range(10.5, 13.5)
				var h := rng.randf_range(5.0, 16.0)
				if rng.randf() < float(th.tall):
					h = rng.randf_range(22.0, 34.0)
				var bc := c + Vector3(q.x * 8.5, 0, q.y * 8.5)
				# face one of the two outer sides
				var side := Vector3(q.x, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, q.y)
				var half := (w if side.x != 0.0 else d) * 0.5
				var door := bc + side * (half + 0.4)
				var curb := c + side * (BLOCK * 0.5 + 2.5) + (Vector3(bc.x - c.x, 0, 0) if side.x == 0.0 else Vector3(0, 0, bc.z - c.z))
				var bal_h := clampf(float(rng.randi_range(1, 4)) * 3.0 + 1.0, 4.0, h - 1.5)
				lots.append({
					"center": bc, "size": Vector3(w, h, d), "side": side, "door": door, "curb": curb,
					"balcony": door + side * 0.9 + Vector3.UP * bal_h, "bal_h": bal_h,
					"roof": bc + Vector3.UP * (h + 0.6),
					"color": pal[rng.randi() % pal.size()], "rest": "",
				})
	# restaurants: spread them out by picking lots far from each other
	var rest_ids := []
	var candidates := _shuffled(range(lots.size()), rng)
	for k in REST_KINDS:
		var best := -1
		var best_d := -1.0
		for i in candidates:
			if i in rest_ids:
				continue
			var md := 1e9
			for j in rest_ids:
				md = minf(md, lots[i].center.distance_to(lots[j].center))
			md += rng.randf() * 20.0
			if md > best_d:
				best_d = md
				best = i
		if best >= 0:
			rest_ids.append(best)
			lots[best].rest = k
			var lot: Dictionary = lots[best]
			lot.size.y = rng.randf_range(4.5, 6.0)
			lot.bal_h = minf(lot.bal_h, lot.size.y - 1.5)
			lot.balcony = lot.door + lot.side * 0.9 + Vector3.UP * lot.bal_h
			lot.roof = lot.center + Vector3.UP * (lot.size.y + 0.6)
	# road features on segments between intersections
	var segments := []
	for i in n + 1:
		for j in n:
			segments.append({"pos": Vector3(i * PITCH, 0, (j + 0.5) * PITCH), "yaw": 0.0})
			segments.append({"pos": Vector3((j + 0.5) * PITCH, 0, i * PITCH), "yaw": PI / 2})
	segments = _shuffled(segments, rng)
	var ramps := []
	var bumps := []
	var idx := 0
	for i in mini(int(th.ramps), segments.size()):
		var s: Dictionary = segments[idx]
		idx += 1
		ramps.append({"pos": s.pos + _along(s.yaw) * rng.randf_range(-8, 8), "yaw": s.yaw + (PI if rng.randf() < 0.5 else 0.0)})
	for i in bump_count:
		var s: Dictionary = segments[idx % segments.size()]
		idx += 1
		bumps.append({"pos": s.pos + _along(s.yaw) * rng.randf_range(-12, 12), "yaw": s.yaw})
	var props := []
	for i in int(th.props):
		var b: Dictionary = blocks[rng.randi() % blocks.size()]
		var side := rng.randi() % 4
		var t := rng.randf_range(-15, 15)
		var off := BLOCK * 0.5 - 1.0
		var p: Vector3 = b.center + [Vector3(off, 0, t), Vector3(-off, 0, t), Vector3(t, 0, off), Vector3(t, 0, -off)][side]
		props.append({"pos": p, "kind": ["cone", "bin", "crate", "cone", "hydrant"][rng.randi() % 5]})
	var trees := []
	for b in blocks:
		if b.park:
			for i in 7:
				trees.append(b.center + Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14)))
	var mid := int(n / 2.0)
	return {"n": n, "size": size, "blocks": blocks, "lots": lots, "rest_ids": rest_ids,
		"ramps": ramps, "bumps": bumps, "props": props, "trees": trees,
		"spawn": Vector3(mid * PITCH, 0.3, mid * PITCH + 6.0), "theme": th}


static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	var out := a.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


static func _along(yaw: float) -> Vector3:
	# direction along the road for a segment with this yaw (yaw 0 = road along z)
	return Vector3(sin(yaw), 0, cos(yaw))


## Index of the restaurant lot serving this food.
static func rest_for(city: Dictionary, food: String) -> int:
	var k: String = FOOD_REST[food]
	for i in city.rest_ids:
		if city.lots[i].rest == k:
			return i
	return city.rest_ids[0]
