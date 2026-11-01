class_name RunState
extends RefCounted
## One roguelite run: days, money, rent, upgrades, daily chaos. Pure, unit-tested.

const UPGRADES := {
	"thermo": {"cost": 35, "mods": {"heat_loss_mult": 0.6}},
	"shocks": {"cost": 35, "mods": {"jolt_mult": 0.4, "top_speed_mult": 0.95}},
	"tape": {"cost": 30, "mods": {"tape": 1}},
	"rocket": {"cost": 55, "mods": {"top_speed_mult": 1.3, "accel_mult": 1.4, "slosh_mult": 1.35}},
	"rack": {"cost": 50, "mods": {"capacity": 1, "wobble_mult": 1.1}},
	"lid": {"cost": 40, "mods": {"spill_thr_mult": 1.4}},
	"gyro": {"cost": 65, "mods": {"gyro": 1.0}},
	"magnet": {"cost": 20, "mods": {"pickup_radius": 3.0}},
	"arm": {"cost": 45, "mods": {"throw_mult": 0.5, "throw_accuracy": 0.6}},
	"mustache": {"cost": 45, "mods": {"tip_mult": 0.15, "bonus_star": 1}},
	"horn": {"cost": 15, "mods": {"horn_power": 1.0}},
	"grease": {"cost": 25, "mods": {"grip_mult": 0.55, "tip_mult": 0.25}},
	"bungee": {"cost": 40, "mods": {"wobble_mult": 0.75, "balance_power": 2.0}},
	"oven": {"cost": 40, "mods": {"heat_bonus_thr": -15.0}},
}

# Multiplicative mods multiply, everything else adds.
const MULT_KEYS := ["heat_loss_mult", "jolt_mult", "top_speed_mult", "accel_mult", "slosh_mult",
	"wobble_mult", "spill_thr_mult", "grip_mult"]

const CHAOS := ["rain", "wind", "heatwave", "bumps", "traffic", "dogs", "pigeons", "fog"]
const QUIRKS := ["", "", "", "yeet", "vip", "impatient", "picky", "rooftop"]

var seed_value := 0
var rng := RandomNumberGenerator.new()
var day := 1
var money := 0
var earned_today := 0
var owned: Array = []
var chaos: Array = []
var shop: Array = []
var fired := false
var stats := {"deliveries": 0, "crashes": 0, "throws": 0, "spilled": 0, "best_tip": 0}
var theme := "bazaar"
var tod := "noon"   # time of day of the current shift
var unlock_level := 0   # how many extra foods are unlocked (meta progression)


func _init(s: int = 0, unlocks: int = 0) -> void:
	seed_value = s
	rng.seed = s
	unlock_level = unlocks
	roll_chaos()


static func rent_for(d: int) -> int:
	var n := d - 1
	return 50 + 25 * n + 4 * n * n


func rent() -> int:
	return rent_for(day)


func shift_length() -> float:
	return 210.0


func mods() -> Dictionary:
	var m := {"capacity": 3, "heat_loss_mult": 1.0, "jolt_mult": 1.0, "top_speed_mult": 1.0,
		"accel_mult": 1.0, "slosh_mult": 1.0, "wobble_mult": 1.0, "spill_thr_mult": 1.0,
		"grip_mult": 1.0, "gyro": 0.0, "tape": 0, "pickup_radius": 2.5, "throw_mult": 2.0,
		"throw_accuracy": 1.0, "tip_mult": 1.0, "bonus_star": 0, "horn_power": 0.0,
		"balance_power": 7.0, "heat_bonus_thr": 80.0, "day_pay_mult": 1.0 + 0.08 * (day - 1)}
	for u in owned:
		var um: Dictionary = UPGRADES[u].mods
		for k in um:
			if k in MULT_KEYS:
				m[k] *= um[k]
			else:
				m[k] += um[k]
	if "rain" in chaos:
		m.grip_mult *= 0.6
		m.heat_loss_mult *= 1.6
	if "heatwave" in chaos:
		m["heatwave"] = true
	if "wind" in chaos:
		m.wobble_mult *= 1.2
	return m


## Foods that can appear in orders, given meta unlocks and the current day.
func food_pool() -> Array:
	var pool := []
	for k in FoodItem.DEFS:
		var u: int = FoodItem.DEFS[k].unlock
		if k == "cake":
			continue
		if u <= unlock_level:
			pool.append(k)
	return pool


## Every third day a wedding cake order arrives: the "boss" delivery.
func big_order_day() -> bool:
	return day % 3 == 0


func pick_food() -> String:
	if unlock_level >= 5 and day >= 3 and rng.randf() < 0.08:
		return "cake"
	var pool := food_pool()
	return pool[rng.randi() % pool.size()]


func pick_quirk() -> String:
	if day < 2:
		return ""
	return QUIRKS[rng.randi() % QUIRKS.size()]


func roll_chaos() -> void:
	chaos.clear()
	tod = "noon" if day == 1 else ["morning", "noon", "sunset", "night"][rng.randi() % 4]
	var n := 0
	if day >= 2:
		n = 1
	if day >= 5:
		n = 2
	if day >= 9:
		n = 3
	var options := CHAOS.duplicate()
	for i in n:
		var c: String = options[rng.randi() % options.size()]
		options.erase(c)
		chaos.append(c)


func add_tip(amount: int) -> void:
	money += amount
	earned_today += amount
	stats.deliveries += 1
	stats.best_tip = maxi(stats.best_tip, amount)


## Pays rent at the end of the shift. Returns false if fired.
func end_shift() -> bool:
	var r := rent()
	if money < r:
		fired = true
		return false
	money -= r
	roll_shop()
	return true


func next_day() -> void:
	day += 1
	earned_today = 0
	roll_chaos()


func roll_shop() -> void:
	shop.clear()
	var options := []
	for u in UPGRADES:
		if u not in owned or u in ["tape", "rack"]:
			options.append(u)
	for i in mini(3, options.size()):
		var u: String = options[rng.randi() % options.size()]
		options.erase(u)
		shop.append(u)


func cost_of(u: String) -> int:
	var c: int = UPGRADES[u].cost
	return c + 15 * owned.count(u)


func buy(u: String) -> bool:
	if u not in shop or money < cost_of(u):
		return false
	money -= cost_of(u)
	owned.append(u)
	shop.erase(u)
	return true


func reroll_cost() -> int:
	return 10


func reroll() -> bool:
	if money < reroll_cost():
		return false
	money -= reroll_cost()
	roll_shop()
	return true
