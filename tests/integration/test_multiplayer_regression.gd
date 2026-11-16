extends GutTest
## M4 regression gate: single-player and spectator simulation fingerprints
## (fresh processes) recorded at dee9387, before the multiplayer foundation.
## They must never change unless a gameplay change is approved.
## M6 (vehicle damage, approved 2026-11-16) changes races on purpose: the
## pre-M6 fingerprints must still hold with damage switched off (the driving,
## AI and combat simulation are untouched), and the M6 ones with damage on.

const FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "17d204f8cfa6293495c420fa81a16037",
	"mode=race ticks=3600 weapons=1 style=1": "9bdc6a5d9e5b8963e59eeca42e08536a",
	"mode=spectate ticks=4800 weapons=1": "cf11fd3db3da18380996dc6f41b07583",
	"mode=spectate ticks=4800 weapons=1 style=1": "7cc525dd768ded2533e41ac03eae8581",
}


## Recorded at M6 (damage on; the hash also covers every car's condition and DNF).
const M6_FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "8663575678f05c185b0e7572cf5fce1e",
	"mode=race ticks=3600 weapons=1 style=1": "4f16242a5a774e12857f22320c4becbe",
	"mode=spectate ticks=4800 weapons=1": "b2054bce9ce15b9d2cee135243950e90",
	"mode=spectate ticks=4800 weapons=1 style=1": "48f2373d383d7a1844afccf6ffd580ef",
}


## Recorded with Weapons Hot (start lock) and rear-quarter contact (2026-11-16),
## everything on. Both change races on purpose (the start is calmer, contacts
## turn cars); with lock=0 contact=0 the M6 values above still hold.
const CURRENT_FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "974a578e9cb4e08bb219805ecc38ba2c",
	"mode=race ticks=3600 weapons=1 style=1": "44b8c78a9c31c51dad59b9f36865b6ab",
	"mode=spectate ticks=4800 weapons=1": "4fcd259c71c63a708292e1ec608ad633",
	"mode=spectate ticks=4800 weapons=1 style=1": "2e50a2cfcb8c6485dc7f3df8982c794b",
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
