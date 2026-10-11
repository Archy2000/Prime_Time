extends SceneTree
func _initialize() -> void:
	for file in ["034_highriserWall_cell.gltf", "040_highriserWall_cell.gltf", "042_man_scientist.gltf", "043_man_hazard.gltf"]:
		var instance = load("res://assets/rolla_complete/models/" + file).instantiate()
		for mesh in instance.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var mat = mesh.get_active_material(i)
				print(file, " material=", mat.resource_name, " texture=", mat.albedo_texture, " color=", mat.albedo_color, " UV=", mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV])
		instance.free()
	quit()
