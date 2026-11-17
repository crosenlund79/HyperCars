extends GutTest
## Music: the official tracks are packaged (and overridable), one player
## hands the music over between menus and races without restarting it,
## pieces fade over, and each loops at its musical end with a short crossfade.


func test_official_tracks_are_the_packaged_music() -> void:
	var r := AssetResolver.new()
	for logical in ["music/music_menu", "music/music_race"]:
		var s := r.get_audio(logical)
		assert_true(s is AudioStreamMP3, "%s: the official MP3" % logical)
	assert_almost_eq(r.get_audio("music/music_menu").get_length(), 89.6, 1.0, "HyperCars - Theme")
	assert_almost_eq(r.get_audio("music/music_race").get_length(), 179.6, 1.0, "HyperCars - Racing Theme")
	assert_true(FileAccess.file_exists("res://assets/audio/_inbox/HyperCars - Theme.mp3"), "the inbox originals stay")
	assert_true(FileAccess.file_exists("res://assets/audio/_inbox/HyperCars - Racing Theme.mp3"))


func test_same_piece_never_restarts_and_another_fades_over() -> void:
	var m := MusicPlayer.new()
	add_child_autofree(m)
	m.play("music/music_menu")
	m.play("music/music_menu")
	assert_eq(m.starts(), 1, "asking again keeps it playing")
	m.play("music/music_race")
	assert_eq(m.current, "music/music_race")
	assert_eq(m.starts(), 2)
	assert_true(m._players[0].playing and m._players[1].playing, "both play during the fade")
	await wait_seconds(MusicPlayer.FADE + 0.3)
	var on := m._players.filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_eq(on.size(), 1, "the old piece stopped after the fade")
	m.stop(0.0)
	assert_false(m.playing())


func test_loops_at_the_musical_end() -> void:
	var menu: Dictionary = MusicPlayer.LOOPS["music/music_menu"]
	assert_false(MusicPlayer.loop_due(80.0, 89.6, menu))
	assert_true(MusicPlayer.loop_due(89.6 - menu.end_trim - menu.crossfade + 0.001, 89.6, menu), "restart under the end")
	var race: Dictionary = MusicPlayer.LOOPS["music/music_race"]
	assert_gt(race.crossfade, menu.crossfade, "the race theme's reverb tail rings under its restart")
	assert_lt(race.end_trim + race.crossfade, 2.0, "nothing of the composition is cut")


func test_music_keeps_playing_through_a_race() -> void:
	var main: Node2D = load("res://src/main/main.tscn").instantiate()
	var m := MusicPlayer.new()
	add_child_autofree(m)
	main.music = m
	main.weapons_lock_enabled = false
	add_child_autofree(main)
	await wait_physics_frames(2)
	assert_eq(m.current, "music/music_menu", "the grid panel: menu music")
	main.set_weapons_enabled(true)
	main.start_race()
	await wait_physics_frames(2)
	assert_eq(m.current, "music/music_race", "the race theme from GO!")
	var starts := m.starts()
	main.combat.mines.append({"owner": 3, "pos": main.cars[0].global_position, "age": main.combat.rules.mine_fuse - 0.01})
	await wait_physics_frames(200)  # destroyed, wrecked, respawned
	main.open_race_menu()
	await wait_frames(5)
	main.resume_race()
	assert_eq(m.starts(), starts, "no restart for destructions, respawns or the pause menu")
	assert_true(m.playing())
	# a voice line ducks the music bus (an amplify effect), never the player
	assert_not_null(main.voice, "voice director in a single-player race")
	main.voice._speaking_until = main.voice.time + 1.5
	await wait_process_frames(30)
	var duck: AudioEffectAmplify = null
	for d in main.voice._ducks:
		if d[0] == "Music":
			duck = d[1]
	assert_not_null(duck)
	assert_lt(duck.volume_db, -1.0, "music ducked under the voice")
	assert_eq(m.starts(), starts, "ducking never restarts the music")
	assert_eq(m.current, "music/music_race")
