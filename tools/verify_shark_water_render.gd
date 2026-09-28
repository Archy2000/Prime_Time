extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var shark := Node3D.new()
	shark.set_script(load("res://scripts/shark.gd"))
	scene.add_child(shark)
	shark.scale = Vector3.ONE * 2.82
	shark.position.y = -1.6
	shark.update_motion(0.4, 0.0, false)
	var mats: Array[StandardMaterial3D] = []
	for mesh in shark.find_children("*", "MeshInstance3D"):
		for i in mesh.mesh.get_surface_count():
			var mat: StandardMaterial3D = mesh.get_active_material(i)
			assert(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			assert(not mat.no_depth_test)
			mats.append(mat)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("718c94")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(100, 100)
	floor_mesh.mesh = floor_plane
	floor_mesh.position.y = -10
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("727161")
	floor_mesh.material_override = floor_mat
	scene.add_child(floor_mesh)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	water.mesh = plane
	water.position.z = 25.0
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water_v3.gdshader")
	water_mat.set_shader_parameter("water_normal", load("res://assets/extracted/sandcastle_water_normal.png"))
	water_mat.set_shader_parameter("caustics_tex", load("res://assets/effects/caustics.png"))
	var field := Image.create(4, 4, false, Image.FORMAT_RGBAF)
	field.fill(Color(0, -10, 0, 0))
	water_mat.set_shader_parameter("wave_field", ImageTexture.create_from_image(field))
	field = Image.create(4, 4, false, Image.FORMAT_RGBAF)
	field.fill(Color(0, 0, 0, 0))
	water_mat.set_shader_parameter("flow_field", ImageTexture.create_from_image(field))
	water_mat.set_shader_parameter("water_height", 0.0)
	water_mat.set_shader_parameter("clarity", 0.6)
	water.material_override = water_mat
	scene.add_child(water)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	camera.current = true
	for side in [-1, 1]:
		camera.position = Vector3(side * 10, 12, -12)
		camera.look_at(Vector3(0, -1, 0))
		for legacy in [true, false]:
			for mat in mats:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if legacy else BaseMaterial3D.TRANSPARENCY_DISABLED
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://research/shark_water_%s_%s.png" % [side, "before" if legacy else "fixed"])
	print("WATER_RENDER PASS: all nine shark surfaces opaque/depth-tested; stationary before/after captured from both sides")
	quit()

