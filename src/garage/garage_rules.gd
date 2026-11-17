class_name GarageRules
extends Resource
## Prices, prize money and starting supplies for the garage (M3.5 Stage 2).
##
## VERIFIED from the original Super Cars II manual (1991): you start with a set
## amount of money; prize money comes from finishing positions (only the top
## five win money); after a race you buy and sell weapons; you choose FRONT or
## REAR for each, two weapon types per race; selling pays less than the shop
## price; the only limit on how many you buy is your money.
## PROVISIONAL (not in the manual / not implemented): every number below; prices
## are fixed (the original's fluctuating prices are not implemented); a stock
## cap per weapon type guards against runaway numbers.

const W := WeaponRules.Weapon

@export var start_money := 300
## Prize money for finishing 1st, 2nd, ... (positions beyond the list win nothing).
@export var prize_money: Array[int] = [550, 400, 300, 200, 125]  # 2026-11-17 economy review (was 500 / 350 / 250 / 150 / 100)
## Shop price of one round of each weapon.
@export var price_front_missile := 40
@export var price_rear_missile := 40
@export var price_homing_missile := 90
@export var price_super_missile := 150
@export var price_mine := 30
## Selling pays this fraction of the shop price (rounded down, at least 1).
@export_range(0.0, 0.99) var sell_fraction := 0.5
## Most rounds of one weapon type a player can own.
@export var max_stock := 99
## Supplies at the start of a garage session: rounds owned and equipped.
@export var start_front_missiles := 5
@export var start_mines := 5

## M6 repairs and armour (VERIFIED from the manual: repairs and armour are
## bought in the shop between races; armour came in grades). PROVISIONAL numbers.
## Price of one point of condition (a full repair from 0 % costs 100 points).
@export var repair_price_per_point := 2  # was 3 (economy review, docs/ECONOMY.md)
## Emergency patch-up: a car below this condition (%) is always patched up to
## it for free before a garage race, so a player can always race (no dead end).
@export var min_start_condition := 50.0  # was 30 (economy review)
## Armour grades: names, damage reduction and the price of each grade on top
## of the previous one (grade 0 = no armour).
@export var armour_names: PackedStringArray = PackedStringArray(["NONE", "LIGHT", "HEAVY"])
@export var armour_reduction: PackedFloat32Array = PackedFloat32Array([0.0, 0.2, 0.35])
@export var armour_price: PackedInt32Array = PackedInt32Array([0, 250, 400])


func price(w: int) -> int:
	match w:
		W.FRONT_MISSILE: return price_front_missile
		W.REAR_MISSILE: return price_rear_missile
		W.HOMING_MISSILE: return price_homing_missile
		W.SUPER_MISSILE: return price_super_missile
		W.MINE: return price_mine
	return 0


func sell_price(w: int) -> int:
	var p := price(w)
	return 0 if p <= 0 else maxi(1, int(floor(p * sell_fraction)))


## Prize for a 1-based finishing position (0 = not classified).
func prize_for(position: int) -> int:
	return prize_money[position - 1] if position >= 1 and position <= prize_money.size() else 0


## Price of repairing `points` of condition (whole points; at least 1 per point started).
func repair_price(points: float) -> int:
	return int(ceil(maxf(points, 0.0) - 0.0001)) * repair_price_per_point if points > 0.0 else 0


func max_armour() -> int:
	return armour_reduction.size() - 1


## Shop value of a loadout (used to keep rival loadouts equal in value).
func loadout_value(front_weapon: int, front_ammo: int, rear_weapon: int, rear_ammo: int) -> int:
	return price(front_weapon) * front_ammo + price(rear_weapon) * rear_ammo
