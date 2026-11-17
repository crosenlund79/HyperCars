extends GutTest
## M4 regression gate: single-player and spectator simulation fingerprints
## (fresh processes) recorded at dee9387, before the multiplayer foundation.
## They must never change unless a gameplay change is approved.
## M6 (vehicle damage, approved 2026-11-16) changes races on purpose: the
## pre-M6 fingerprints must still hold with damage switched off (the driving,
## AI and combat simulation are untouched), and the M6 ones with damage on.
## Race experience (approved 2026-11-16): the rivals' personal racing lines,
## wreck awareness, ammo pacing and race-length ammunition change every race,
## so all three sets were re-recorded then (same switches as before; the old
## values are in git history). Each set still isolates its feature: damage=0
## lock=0 contact=0 / lock=0 contact=0 / everything on.

## Re-recorded 2026-11-17 for the human (race-mode) probes only: the approved
## steering precision change ramps the scripted player's key steering. Spectator
## hashes, pit lanes, split sections and lighting change nothing here.
const FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "3d35204f54580c909e3f004940c57f6d",
	"mode=race ticks=3600 weapons=1 style=1": "fbfb18498bdb9b46746fb19b45670412",
	"mode=spectate ticks=4800 weapons=1": "2dd9c7be3970ab58f4f5baba17fd47ae",
	"mode=spectate ticks=4800 weapons=1 style=1": "f717ec515bc834f4cd8643835a6e4b22",
}


## Recorded at M6 (damage on; the hash also covers every car's condition and DNF).
const M6_FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "b37dc17e55f7edd48e25368fda14154c",
	"mode=race ticks=3600 weapons=1 style=1": "3bd67c0513e860850b9bba0ec9006b12",
	"mode=spectate ticks=4800 weapons=1": "c4fae0ca26f56e647c504cc4d00e6292",
	"mode=spectate ticks=4800 weapons=1 style=1": "c8f7fe36390d437f20b4b1883d6d0472",
}


## Recorded with Weapons Hot (start lock) and rear-quarter contact (2026-11-16),
## everything on. Both change races on purpose (the start is calmer, contacts
## turn cars); with lock=0 contact=0 the M6 values above still hold.
const CURRENT_FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "205080edcda1cc16b76e34ce49e603d1",
	"mode=race ticks=3600 weapons=1 style=1": "837f985f9a93d44472f30d242debce36",
	"mode=spectate ticks=4800 weapons=1": "f8f130a0feef918c9befd871df1264d8",
	"mode=spectate ticks=4800 weapons=1 style=1": "010b09a86e20fa81a311654ed3c9fb5a",
}


func test_current_fingerprints() -> void:
	for args in CURRENT_FINGERPRINTS:
		assert_eq(ProbeRunner.run(PackedStringArray(args.split(" "))), CURRENT_FINGERPRINTS[args], args)


func test_single_player_and_spectator_fingerprints_unchanged() -> void:
	for args in FINGERPRINTS:
		assert_eq(ProbeRunner.run(PackedStringArray((args + " damage=0 lock=0 contact=0").split(" "))), FINGERPRINTS[args],
			args + " (damage, weapons lock and contact yaw off)")


func test_m6_damage_fingerprints() -> void:
	for args in M6_FINGERPRINTS:
		assert_eq(ProbeRunner.run(PackedStringArray((args + " lock=0 contact=0").split(" "))), M6_FINGERPRINTS[args], args + " (weapons lock and contact yaw off)")
