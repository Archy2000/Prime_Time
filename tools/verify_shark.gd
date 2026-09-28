extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var shark := Node3D.new()
	shark.set_script(load("res://scripts/shark.gd"))
	scene.add_child(shark)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	scene.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("263a46")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	scene.add_child(env)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(4, 2.1, -4)
	camera.look_at(Vector3(0, 0, 0.1))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.7
	camera.current = true
	await process_frame
	var player: AnimationPlayer = shark.animation_player
	assert(player.has_animation("SwimmingAction") and player.has_animation("JumpAction"))
	shark.update_motion(0.45, 8.0, false)
	assert(player.current_animation == "SwimmingAction")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/shark_swim_preview.png")
	shark.update_motion(0.7, 8.0, true)
	assert(player.current_animation == "JumpAction")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/shark_jump_preview.png")
	shark.update_motion(0.2, 0.0, false)
	assert(player.current_animation == "SwimmingAction")
	assert(is_equal_approx(player.speed_scale, 0.55))
	shark.update_motion(0.2, 18.0, false)
	assert(is_equal_approx(player.speed_scale, 2.1))
	print("SHARK PASS: imported skeleton/materials, swimming, leap, landing and speed modulation")
	quit()
