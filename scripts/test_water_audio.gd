extends SceneTree
var results: Dictionary = {}
func _init() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	var game = current_scene
	var audio = game.water_fx.audio
	results["assets_loaded"] = audio.clips.size() == 23 and not audio.clips.values().has(null)
	results["loops_started"] = audio.loops.all(func(p): return p.playing)
	results["listener_at_player"] = audio.listener.global_position.distance_to(game.player.global_position) < 2.0
	var before: int = audio.emitted
	game.water_fx.breach(game.player.position, 3.2, -18.0, true)
	results["heavy_entry_triggered"] = audio.voices.any(func(p): return p.playing and "WaterHeavyEntry" in p.stream.resource_path)
	var large: Dictionary = audio.last_entry.duplicate()
	await create_timer(1.3).timeout
	results["landing_and_drips"] = audio.emitted >= before + 4
	game.water_fx.breach(game.player.position, 1.0, -9.0, true)
	results["large_entry_deeper_and_louder"] = large.pitch < audio.last_entry.pitch and large.gain_db > audio.last_entry.gain_db
	await create_timer(1.3).timeout
	for i in 100: game.water_fx.splash(game.player.position, 1.0)
	results["burst_limited"] = audio.rejected > 80 and audio.voices.size() == 16
	audio.swim(game.player.position, Vector3(18,0,0), 1.0)
	audio._process(0.05)
	results["motion_rises"] = audio.intensity > 0.1
	await create_timer(1.0).timeout
	results["idle_fades"] = audio.intensity < 0.01
	paused = true
	var old: float = audio.clock
	await create_timer(0.2).timeout
	results["pause_freezes"] = is_equal_approx(old, audio.clock)
	paused = false
	audio.follow(game.player.position, game.camera, false)
	audio._process(0.01)
	results["dry_muted"] = AudioServer.is_bus_mute(AudioServer.get_bus_index("Water"))
	var count := AudioServer.bus_count
	change_scene_to_file("res://scenes/water_lab.tscn")
	await create_timer(0.8).timeout
	audio = current_scene.water_fx.audio
	results["switch_no_duplicate_buses"] = AudioServer.bus_count == count
	results["lab_enabled"] = audio.enabled and audio.loops.size() == 3 and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Water"))
	before = audio.emitted
	for i in 180:
		audio.swim(current_scene.player.position, Vector3(18,0,0), 1.0)
		audio._process(1.0 / 60.0)
	results["swim_no_repeated_splashes"] = audio.emitted == before
	results["swim_no_agitated_water"] = audio.loops[2].volume_linear < 0.001
	results["swim_quiet_even_at_boost"] = audio.loops[1].volume_linear <= 0.121
	before = audio.emitted
	audio.wave()
	results["lab_wave"] = audio.emitted > before and audio.surge == 1.0
	results["passed"] = not results.values().has(false)
	FileAccess.open("res://research/water_audio_tests.json", FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	print("WATER_AUDIO_TEST ", results)
	quit(0 if results.passed else 1)
