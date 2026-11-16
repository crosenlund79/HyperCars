class_name PlayerGarage
extends RefCounted
## The player's money and weapon inventory for one garage session (kept while
## the game runs; nothing is saved to disk). The single authority for what the
## player owns: the race only receives a copy of the equipped rounds, and the
## rounds left after the race are written back once by settle_race().
## Quick races and spectating never use it.
## Pure logic (no scene access), so it is unit-testable.

const W := WeaponRules.Weapon
const FRONT := 0
const REAR := 1

var rules: GarageRules
var money := 0
## Rounds owned per weapon type (WeaponRules.Weapon -> int).
var stock: Dictionary = {}
## Equipped weapon type per slot: [front, rear] (W.NONE = empty slot).
var equipped: Array[int] = [W.NONE, W.NONE]
## Races paid so far, and what the last settled race paid.
var races_settled := 0
var last_position := 0
var last_prize := 0
## M6: the car's condition (0 .. 100 %), carried from race to race, and its
## armour grade (0 = none). Condition before the last race and after it.
var condition := 100.0
var armour := 0
var last_condition_before := 100.0
## Free emergency patch-up given at the start of the last race (points).
var last_patch := 0.0
var _race_pending := false


func _init(p_rules: GarageRules) -> void:
	rules = p_rules
	money = rules.start_money
	for w in WeaponRules.ALL_WEAPONS:
		stock[w] = 0
	stock[W.FRONT_MISSILE] = rules.start_front_missiles
	stock[W.MINE] = rules.start_mines
	equipped = [W.FRONT_MISSILE, W.MINE]


func count(w: int) -> int:
	return stock.get(w, 0)


func can_buy(w: int, n: int = 1) -> bool:
	return not _race_pending and stock.has(w) and n > 0 and money >= rules.price(w) * n \
		and count(w) + n <= rules.max_stock


## Buys n rounds; false (nothing changes) when unaffordable or over the cap.
func buy(w: int, n: int = 1) -> bool:
	if not can_buy(w, n):
		return false
	money -= rules.price(w) * n
	stock[w] += n
	return true


func can_sell(w: int, n: int = 1) -> bool:
	return not _race_pending and stock.has(w) and n > 0 and count(w) >= n


## Sells n rounds at the lower sell price.
func sell(w: int, n: int = 1) -> bool:
	if not can_sell(w, n):
		return false
	money += rules.sell_price(w) * n
	stock[w] -= n
	return true


## Mounts weapon type w in its slot (W.NONE empties the given slot).
func equip(slot: int, w: int) -> bool:
	if _race_pending or slot < 0 or slot > 1:
		return false
	if w != W.NONE and not WeaponRules.compatible(w, slot):
		return false
	equipped[slot] = w
	return true


## [front weapon, front rounds, rear weapon, rear rounds] the car carries.
func race_loadout() -> Array:
	return [equipped[FRONT], count(equipped[FRONT]) if equipped[FRONT] != W.NONE else 0,
		equipped[REAR], count(equipped[REAR]) if equipped[REAR] != W.NONE else 0]


# ----------------------------------------------------- condition (M6)

## Points of condition missing.
func damage_points() -> float:
	return maxf(0.0, 100.0 - condition)


## Price of a full repair.
func full_repair_cost() -> int:
	return rules.repair_price(damage_points())


## Repairs `points` of condition (whole points, capped at full); false when
## there is nothing to repair or it is unaffordable.
func can_repair(points: float = 1.0) -> bool:
	return not _race_pending and damage_points() > 0.0 and points > 0.0 \
		and money >= rules.repair_price(minf(points, damage_points()))


func repair(points: float) -> bool:
	points = minf(points, damage_points())
	if not can_repair(points):
		return false
	money -= rules.repair_price(points)
	condition = minf(100.0, condition + ceil(points - 0.0001))
	return true


## Repairs everything, or as much as the money pays for. Returns points repaired.
func repair_affordable() -> float:
	if _race_pending or damage_points() <= 0.0:
		return 0.0
	var points := minf(ceil(damage_points() - 0.0001), floor(money / float(maxi(1, rules.repair_price_per_point))))
	if points <= 0.0:
		return 0.0
	var before := condition
	repair(points)
	return condition - before


## Condition the car starts the next race with: its own, or the free
## emergency patch-up when it is below the minimum.
func race_condition() -> float:
	return maxf(condition, rules.min_start_condition)


## Damage reduction of the fitted armour.
func armour_reduction() -> float:
	return rules.armour_reduction[clampi(armour, 0, rules.max_armour())]


func armour_name(grade: int = armour) -> String:
	return rules.armour_names[clampi(grade, 0, rules.armour_names.size() - 1)]


## Price of the next armour grade (0 when the best is fitted).
func next_armour_price() -> int:
	return rules.armour_price[armour + 1] if armour < rules.max_armour() else 0


func can_buy_armour() -> bool:
	return not _race_pending and armour < rules.max_armour() and money >= next_armour_price()


func buy_armour() -> bool:
	if not can_buy_armour():
		return false
	money -= next_armour_price()
	armour += 1
	return true


## A garage race has started: the shop is closed until it is settled. A car
## below the minimum condition gets the free emergency patch-up now.
func begin_race() -> void:
	_race_pending = true
	last_condition_before = condition
	last_patch = maxf(0.0, rules.min_start_condition - condition)
	condition = race_condition()


func race_pending() -> bool:
	return _race_pending


## Pays the prize for the finishing position and keeps the rounds left in the
## equipped weapons. Applies once per begun race; returns the prize, or -1 if
## there was no race to settle (repeat calls change nothing).
## condition_left: the car's condition at the end (%; -1 keeps it unchanged).
func settle_race(position: int, front_left: int, rear_left: int, condition_left: float = -1.0) -> int:
	if not _race_pending:
		return -1
	_race_pending = false
	if condition_left >= 0.0:
		condition = clampf(condition_left, 0.0, 100.0)
	for slot in 2:
		var w := equipped[slot]
		if w != W.NONE:
			var left := front_left if slot == FRONT else rear_left
			stock[w] = clampi(left, 0, count(w))
	last_position = position
	last_prize = rules.prize_for(position)
	money += last_prize
	races_settled += 1
	return last_prize


## A begun race that never finished (left before the flag): nothing is paid,
## no rounds are used up and the car is as it was (no patch-up either).
func abandon_race() -> void:
	if _race_pending:
		condition = last_condition_before
	_race_pending = false


## Total shop value of everything owned (for display).
func inventory_value() -> int:
	var v := 0
	for w in stock:
		v += rules.price(w) * stock[w]
	return v
