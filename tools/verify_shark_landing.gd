extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.water_level = 5.0
	game.growth = 3.2
	game.visual.scale = Vector3.ONE * game.growth
	var collider: CollisionShape3D = game.player.get_child(0)
	collider.shape.radius = 0.55 * game.growth
	collider.position.y = 0.40 * game.growth
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	roof.add_child(shape)
	root.add_child(roof)
	# Submerged roof: at contact the shark center is below the surface,
	# but its lower collision hemisphere touches the roof.
	roof.position = Vector3(150, 3.9, 150)
	await physics_frame
	game.player.position = Vector3(150, 4.89, 150)
	game.airborne = true
	game.jump_velocity = -4.0
	game.air_drift = Vector3.ZERO
	game.leap_target = null
	for i in 30:
		game._physics_process(1.0 / 60.0)
		await physics_frame
	print("SUBMERGED_ROOF airborne=", game.airborne, " y=", game.player.position.y)
	var expected_y: float = game.water_level + game.wave_sim.sample_surface(game.player.position).y - 0.78 * game.growth
	var passed: bool = not game.airborne and absf(game.visual.global_position.y - expected_y) < 0.1
	print("SUBMERGED_VISUAL depth_error=", absf(game.visual.global_position.y - expected_y))
	passed = passed and game.visual.animation_player.current_animation == "SwimmingAction"
	# A roof above the water must still support the shark, not force a dive.
	roof.position.y = 6.0
	game.player.position = Vector3(150, 7.1, 150)
	game.airborne = true
	game.jump_velocity = -4.0
	await physics_frame
	for i in 30:
		game._physics_process(1.0 / 60.0)
		await physics_frame
	print("DRY_ROOF airborne=", game.airborne, " y=", game.player.position.y)
	passed = passed and game.airborne and game.player.position.y > 5.0
	passed = passed and game.visual.global_position.y < 5.0 - 0.65 * game.growth
	passed = passed and game.visual.animation_player.current_animation == "SwimmingAction"
	# Fall from that roof into open water, without any movement input.
	game.player.position.x += 14.0
	for i in 120:
		game._physics_process(1.0 / 60.0)
		await physics_frame
	var surface: float = game.water_level + game.wave_sim.sample_surface(game.player.position).y
	var depth_error: float = absf(game.visual.global_position.y - (surface - 0.78 * game.growth))
	print("OPEN_WATER airborne=", game.airborne, " depth_error=", depth_error)
	passed = passed and not game.airborne and depth_error < 0.1
	passed = passed and game.visual.global_position.y < surface - 0.65 * game.growth
	print("LANDING_REGRESSION passed=", passed)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)


