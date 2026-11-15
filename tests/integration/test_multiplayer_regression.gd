extends GutTest
## M4 regression gate: single-player and spectator simulation fingerprints
## (fresh processes) recorded at dee9387, before the multiplayer foundation.
## They must never change unless a gameplay change is approved.

const FINGERPRINTS := {
	"mode=race ticks=3600 weapons=0": "17d204f8cfa6293495c420fa81a16037",
	"mode=race ticks=3600 weapons=1 style=1": "9bdc6a5d9e5b8963e59eeca42e08536a",
	"mode=spectate ticks=4800 weapons=1": "cf11fd3db3da18380996dc6f41b07583",
	"mode=spectate ticks=4800 weapons=1 style=1": "7cc525dd768ded2533e41ac03eae8581",
}


func test_single_player_and_spectator_fingerprints_unchanged() -> void:
	for args in FINGERPRINTS:
		assert_eq(ProbeRunner.run(PackedStringArray(args.split(" "))), FINGERPRINTS[args], args)
