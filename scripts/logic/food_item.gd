class_name FoodItem
extends RefCounted
## Pure food state: heat, integrity, wobble (tilt spring) and soup slosh.
## No nodes here so it can be unit-tested headless.

# sens: how much acceleration tilts it, stiff/damp: spring, fall_limit: radians,
# fragility: damage from jolts, heat_loss: points per second, cold: melts instead of cooling.
const DEFS := {
	"pizza": {"pay": 10, "sens": 0.5, "stiff": 30.0, "damp": 5.0, "fall_limit": 0.85, "fragility": 0.4,
		"heat_loss": 0.32, "cold": false, "liquid": false, "height": 0.12, "unlock": 0},
	"soup": {"pay": 14, "sens": 0.4, "stiff": 34.0, "damp": 6.0, "fall_limit": 0.9, "fragility": 0.1,
		"heat_loss": 0.28, "cold": false, "liquid": true, "height": 0.22, "unlock": 0,
		"slosh_sens": 0.8, "slosh_k": 16.0, "slosh_c": 2.4, "spill_thr": 0.55, "spill_rate": 140.0},
	"burger": {"pay": 12, "sens": 0.7, "stiff": 24.0, "damp": 4.0, "fall_limit": 0.7, "fragility": 0.7,
		"heat_loss": 0.38, "cold": false, "liquid": false, "height": 0.34, "unlock": 1},
	"drinks": {"pay": 12, "sens": 0.6, "stiff": 30.0, "damp": 5.0, "fall_limit": 0.8, "fragility": 0.2,
		"heat_loss": 0.22, "cold": true, "liquid": true, "height": 0.26, "unlock": 2,
		"slosh_sens": 0.9, "slosh_k": 20.0, "slosh_c": 2.6, "spill_thr": 0.5, "spill_rate": 110.0},
	"icecream": {"pay": 13, "sens": 0.65, "stiff": 26.0, "damp": 4.5, "fall_limit": 0.75, "fragility": 0.5,
		"heat_loss": 0.6, "cold": true, "liquid": false, "height": 0.36, "unlock": 3},
	"sushi": {"pay": 16, "sens": 0.5, "stiff": 30.0, "damp": 6.0, "fall_limit": 0.9, "fragility": 1.2,
		"heat_loss": 0.18, "cold": true, "liquid": false, "height": 0.1, "unlock": 4},
	"cake": {"pay": 45, "sens": 1.0, "stiff": 18.0, "damp": 3.5, "fall_limit": 0.6, "fragility": 0.9,
		"heat_loss": 0.15, "cold": true, "liquid": false, "height": 0.6, "unlock": 5},
}

var kind: String
var def: Dictionary
var heat := 100.0          # hot foods: temperature; cold foods: "coldness" (100 = frozen)
var integrity := 100.0     # 0..100, liquids: equals remaining volume
var tilt := Vector2.ZERO   # x = right, y = forward (radians, relative to item below)
var tilt_vel := Vector2.ZERO
var slosh := Vector2.ZERO
var slosh_vel := Vector2.ZERO
var order_id := -1
var tape := 0              # duct tape charges: saves one fall each
var dropped := false       # touched the ground at least once
var spilled := false


var sens: float
var stiff: float
var damp: float
var limit: float
var fragility: float
var heat_loss: float
var cold: bool
var liquid: bool
var h: float
var slosh_sens := 0.0
var slosh_k := 0.0
var slosh_c := 0.0
var spill_thr := 0.0
var spill_rate := 0.0


func _init(k: String = "pizza") -> void:
	kind = k
	def = DEFS[k]
	sens = def.sens
	stiff = def.stiff
	damp = def.damp
	limit = def.fall_limit
	fragility = def.fragility
	heat_loss = def.heat_loss
	cold = def.cold
	liquid = def.liquid
	h = def.height
	if liquid:
		slosh_sens = def.slosh_sens
		slosh_k = def.slosh_k
		slosh_c = def.slosh_c
		spill_thr = def.spill_thr
		spill_rate = def.spill_rate


func is_liquid() -> bool:
	return liquid


func is_cold() -> bool:
	return cold


func height() -> float:
	return h


func fall_limit() -> float:
	return limit


## One physics step on the rack.
## accel: scooter acceleration in its local frame (x right, y forward), m/s^2.
## level: 0 = bottom of the stack. balance: player input (-1..1 each axis).
## Returns the amount of liquid spilled this step.
func step(dt: float, accel: Vector2, level: int, balance: Vector2, mods: Dictionary = {}) -> float:
	var sn: float = sens * mods.get("wobble_mult", 1.0) * (1.0 + 0.3 * level)
	var soft := 1.0 - clampf(tilt.length() / limit, 0.0, 1.0) * 0.6
	var assist: float = mods.get("gyro", 0.0)
	var bp: float = mods.get("balance_power", 7.0)
	var acc := -accel * sn - tilt * (stiff * soft) - tilt_vel * (damp + assist * 6.0)
	acc += balance * bp
	tilt_vel += acc * dt
	tilt += tilt_vel * dt
	if not is_liquid():
		return 0.0
	var ss: float = slosh_sens * mods.get("slosh_mult", 1.0)
	var sacc := -accel * ss - slosh * slosh_k - slosh_vel * slosh_c
	slosh_vel += sacc * dt
	slosh += slosh_vel * dt
	var surface := (slosh + tilt).length()
	var thr: float = spill_thr * mods.get("spill_thr_mult", 1.0)
	if surface <= thr:
		return 0.0
	var amount := minf(integrity, (surface - thr) * spill_rate * dt)
	integrity -= amount
	if amount > 0.0:
		spilled = true
	return amount


func step_heat(dt: float, mult: float = 1.0) -> void:
	heat = maxf(0.0, heat - heat_loss * mult * dt)


## Sudden vertical bump (m/s of vertical velocity change).
func jolt(strength: float, dir: Vector2, mods: Dictionary = {}) -> void:
	var s: float = strength * mods.get("jolt_mult", 1.0)
	integrity = maxf(0.0, integrity - fragility * maxf(0.0, s - 2.0) * 5.0)
	tilt_vel += dir * s * 0.5 * sens
	if is_liquid():
		slosh_vel += dir * s * 1.2


## Fell off the rack or hit the ground as a loose object.
func impact(speed: float) -> void:
	integrity = maxf(0.0, integrity - fragility * maxf(0.0, speed - 2.5) * 6.0)
	if is_liquid() and speed > 1.0:
		integrity = maxf(0.0, integrity - minf(70.0, speed * 12.0))
		spilled = true


func on_fall() -> void:
	dropped = true
	tilt = Vector2.ZERO
	tilt_vel = Vector2.ZERO
	slosh = Vector2.ZERO
	slosh_vel = Vector2.ZERO
	if is_liquid():
		integrity = maxf(0.0, integrity - 55.0)
		spilled = true


func destroyed() -> bool:
	return integrity < 15.0
