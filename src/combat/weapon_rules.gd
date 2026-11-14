class_name WeaponRules
extends Resource
## Combat rules shared by every car (player and rivals).
##
## VERIFIED from the original Super Cars II manual (1991): one FRONT and one REAR
## weapon type per race, fired with joystick Forward / Backwards; front missiles
## fly straight ahead until they hit something and can be dodged; rear missiles
## the same, backwards; homing missiles home in on the nearest car; the super
## missile rotates round its car destroying anything that gets too close; mines
## are dropped and explode after a few seconds, destroying anything close.
## Weapons destroy cars ("blast it to pieces").
## PROVISIONAL (not in the manual): every number below, the fixed loadout (the
## original buys it in the shop), and what happens to a destroyed car (user
## decision 2026-11-14: wrecked on the spot, then continues).

enum Weapon { NONE, FRONT_MISSILE, REAR_MISSILE, HOMING_MISSILE, SUPER_MISSILE, MINE }

## Fixed loadout for everyone (user decision: front missiles + rear mines). Ammo PROVISIONAL.
@export var front_weapon: Weapon = Weapon.FRONT_MISSILE
@export var front_ammo := 5
@export var rear_weapon: Weapon = Weapon.MINE
@export var rear_ammo := 5

## Time between shots from the same car (s). PROVISIONAL.
@export var fire_cooldown := 0.6
## Missile speed (px/s; cars top out at 420). PROVISIONAL.
@export var missile_speed := 820.0
## Missile flight time before it fizzles (s). PROVISIONAL.
@export var missile_lifetime := 2.4
## Distance from a car's centre at which a missile hits it (px). PROVISIONAL.
@export var hit_radius := 24.0
## Homing missile steering (degrees/s) and how far it looks for its target (px). PROVISIONAL.
@export var homing_turn_rate_degrees := 140.0
@export var homing_range := 900.0
## "A few seconds" before a mine explodes, and its blast radius (px). PROVISIONAL numbers.
@export var mine_fuse := 3.0
@export var mine_blast_radius := 70.0
## Super missile orbit radius (px), how long it orbits (s), and its hit radius (px). PROVISIONAL.
@export var super_orbit_radius := 56.0
@export var super_orbit_speed_degrees := 360.0
@export var super_duration := 5.0
@export var super_hit_radius := 22.0
## A destroyed car stays wrecked this long (s), then continues from where it stopped,
## and cannot be destroyed again for respawn_grace s. PROVISIONAL.
@export var wreck_time := 3.0
@export var respawn_grace := 1.5


func ammo_for(slot: int) -> int:
	return front_ammo if slot == 0 else rear_ammo


func weapon_for(slot: int) -> Weapon:
	return front_weapon if slot == 0 else rear_weapon


static func weapon_name(w: Weapon) -> String:
	match w:
		Weapon.FRONT_MISSILE: return "Front missiles"
		Weapon.REAR_MISSILE: return "Rear missiles"
		Weapon.HOMING_MISSILE: return "Homing missiles"
		Weapon.SUPER_MISSILE: return "Super missile"
		Weapon.MINE: return "Mines"
	return "None"
