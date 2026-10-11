extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := "res://research/rolla_previews"
	DirAccess.make_dir_recursive_absolute(output + "/images")
	root.size = Vector2i(420, 340)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e0e6eb")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.1
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	stage.add_child(camera)
	var files := DirAccess.get_files_at("res://assets/rolla_complete/models")
	files.sort()
	var rows: Array[Dictionary] = []
	for filename in files:
		if not filename.ends_with(".gltf"):
			continue
		var packed := load("res://assets/rolla_complete/models/" + filename) as PackedScene
		var instance := packed.instantiate() as Node3D
		stage.add_child(instance)
		var bounds := AABB()
		var first := true
		for child in instance.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = child.global_transform * child.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center := bounds.get_center()
		var diameter := maxf(bounds.size.length(), 0.02)
		camera.size = diameter * 1.12
		camera.near = maxf(diameter * 0.001, 0.001)
		camera.far = diameter * 12.0
		camera.position = center + Vector3(1.2, 0.85, 1.65).normalized() * diameter * 3.0
		camera.look_at(center)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image_path := "images/" + filename.get_basename() + ".png"
		var error := root.get_texture().get_image().save_png(output + "/" + image_path)
		camera.position = center + Vector3(-1.2, 0.85, -1.65).normalized() * diameter * 3.0
		camera.look_at(center)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/images/" + filename.get_basename() + "_reverse.png")
		rows.append({"model": filename, "image": image_path, "size": [bounds.size.x, bounds.size.y, bounds.size.z], "save_error": error})
		instance.free()
		if rows.size() % 40 == 0:
			print("Rendered ", rows.size(), " / 278")
	var manifest := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(rows, "  "))
	print("Rendered all ", rows.size(), " model previews")
	quit()
