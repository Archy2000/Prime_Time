extends SceneTree

func _initialize() -> void:
	var model = load("res://assets/characters/shark/SK_Great_White_Shark.glb").instantiate()
	root.add_child(model)
	model.print_tree_pretty()
	for node in model.find_children("*", "AnimationPlayer"):
		for name in node.get_animation_list():
			var animation: Animation = node.get_animation(name)
			print("ANIMATION ", name, " length=", animation.length)
			for track in animation.get_track_count():
				print(" TRACK ", animation.track_get_path(track), " type=", animation.track_get_type(track))
	for node in model.find_children("*", "MeshInstance3D"):
		print("MESH ", node.name, " ", node.get_aabb())
	quit()
