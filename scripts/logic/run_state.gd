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

## Competitive mode: one new card per round, they stack up. Chaos cards reuse the chaos events.
const COMP_CARDS := {
	"rain": {}, "wind": {}, "dogs": {}, "pigeons": {}, "traffic": {}, "bumps": {}, "fog": {}, "heatwave": {},
	"impatient": {"timer_mult": 0.7}, "fragile": {"jolt_mult": 1.5, "wobble_mult": 1.15},
	"no_doorbell": {"hand_mult": 0.5}, "cold_kitchen": {"heat_loss_mult": 1.6}, "greedy": {"capacity": 1, "wobble_mult": 1.25},
}
const ROUNDS := 7

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
var mode := "normal"        # "normal" (co-op, one missed rent allowed) or "competitive"
var strikes := 0
var warned := false          # missed rent this shift but still employed
var finished := false        # competitive: all rounds played
var players := 1
var wallets: Array = []      # competitive: money per player
var earned_by: Array = []
var owned_by: Array = []
var shops: Array = []
var cards: Array = []
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
	return 150.0 if competitive() else 210.0


func setup_competitive(n: int) -> void:
	mode = "competitive"
	players = n
	wallets = []
	earned_by = []
	owned_by = []
	shops = []
	for i in n:
		wallets.append(0)
		earned_by.append(0)
		owned_by.append([])
		shops.append([])
	cards = []
	chaos = []


func competitive() -> bool:
	return mode == "competitive"


func mods(player := -1) -> Dictionary:
	var m := {"capacity": 3, "heat_loss_mult": 1.0, "jolt_mult": 1.0, "top_speed_mult": 1.0,
		"accel_mult": 1.0, "slosh_mult": 1.0, "wobble_mult": 1.0, "spill_thr_mult": 1.0,
		"grip_mult": 1.0, "gyro": 0.0, "tape": 0, "pickup_radius": 2.5, "throw_mult": 2.0,
		"throw_accuracy": 1.0, "tip_mult": 1.0, "bonus_star": 0, "horn_power": 0.0,
		"balance_power": 7.0, "heat_bonus_thr": 80.0, "day_pay_mult": 1.0 + 0.08 * (day - 1)}
	m["timer_mult"] = 1.0
	m["hand_mult"] = 1.0
	var mine: Array = owned_by[player] if competitive() and player >= 0 and player < owned_by.size() else owned
	for c in cards:
		var cm: Dictionary = COMP_CARDS.get(c, {})
		for k in cm:
			if k in MULT_KEYS or k.ends_with("_mult"):
				m[k] *= cm[k]
			else:
				m[k] += cm[k]
	for u in mine:
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


func add_tip(amount: int, player := 0) -> void:
	if competitive() and player < wallets.size():
		wallets[player] += amount
		earned_by[player] += amount
	else:
		money += amount
	earned_today += amount
	stats.deliveries += 1
	stats.best_tip = maxi(stats.best_tip, amount)


## Pays rent at the end of the shift. Returns false if fired.
func end_shift() -> bool:
	if competitive():
		if day >= ROUNDS:
			finished = true
			return true
		var options := COMP_CARDS.keys().filter(func(c): return c not in cards)
		if options.size() > 0:
			cards.append(options[rng.randi() % options.size()])
		for p in players:
			roll_shop_for(p)
		return true
	var r := rent()
	warned = false
	if money < r:
		strikes += 1
		if strikes > 1:
			fired = true
			return false
		warned = true     # first miss: the boss lets it slide, you lose your savings
		money = 0
		roll_shop()
		return true
	money -= r
	roll_shop()
	return true


func winner() -> int:
	var best := 0
	for i in earned_by.size():
		if earned_by[i] > earned_by[best]:
			best = i
	return best


func roll_shop_for(p: int) -> void:
	var saved_owned := owned
	owned = owned_by[p]
	roll_shop()
	shops[p] = shop.duplicate()
	owned = saved_owned


func buy_for(p: int, u: String) -> bool:
	var cost := UPGRADES[u].cost + 15 * owned_by[p].count(u) as int
	if u not in shops[p] or wallets[p] < cost:
		return false
	wallets[p] -= cost
	owned_by[p].append(u)
	shops[p].erase(u)
	return true


func next_day() -> void:
	day += 1
	earned_today = 0
	roll_chaos()
	if competitive():
		chaos = cards.filter(func(c): return c in CHAOS)


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


const SYNC_KEYS := ["seed_value", "day", "money", "earned_today", "owned", "chaos", "shop", "fired",
	"stats", "unlock_level", "theme", "tod", "mode", "strikes", "warned", "finished", "players", "wallets",
	"earned_by", "owned_by", "shops", "cards"]


## Everything a client needs to build the same day as the host.
func to_dict() -> Dictionary:
	var d := {}
	for k in SYNC_KEYS:
		d[k] = get(k)
	return d


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new(int(d.get("seed_value", 0)), int(d.get("unlock_level", 0)))
	for k in SYNC_KEYS:
		if d.has(k):
			r.set(k, d[k])
	return r
