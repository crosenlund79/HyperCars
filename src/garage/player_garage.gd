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


## A garage race has started: the shop is closed until it is settled.
func begin_race() -> void:
	_race_pending = true


func race_pending() -> bool:
	return _race_pending


## Pays the prize for the finishing position and keeps the rounds left in the
## equipped weapons. Applies once per begun race; returns the prize, or -1 if
## there was no race to settle (repeat calls change nothing).
func settle_race(position: int, front_left: int, rear_left: int) -> int:
	if not _race_pending:
		return -1
	_race_pending = false
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


## A begun race that never finished (left before the flag): nothing is paid
## and no rounds are used up.
func abandon_race() -> void:
	_race_pending = false


## Total shop value of everything owned (for display).
func inventory_value() -> int:
	var v := 0
	for w in stock:
		v += rules.price(w) * stock[w]
	return v
