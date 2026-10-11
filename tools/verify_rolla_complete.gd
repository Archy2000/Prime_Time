extends SceneTree

func _initialize() -> void:
	var directory := DirAccess.open("res://assets/rolla_complete/models")
	var total := 0
	var failed: Array[String] = []
	for filename in directory.get_files():
		if not filename.ends_with(".gltf"):
			continue
		total += 1
		var scene := load("res://assets/rolla_complete/models/" + filename) as PackedScene
		if scene == null:
			failed.append(filename)
			continue
		var instance := scene.instantiate()
		if instance.find_children("*", "MeshInstance3D", true, false).is_empty():
			failed.append(filename + ": no mesh instance")
		instance.free()
	var scenes_checked := 0
	for filename in DirAccess.get_files_at("res://assets/rolla_complete"):
		if filename.ends_with(".gltf"):
			scenes_checked += 1
			var resource := load("res://assets/rolla_complete/" + filename) as PackedScene
			if resource == null:
				failed.append(filename)
	var report := {"models_checked": total, "scenes_checked": scenes_checked, "failed": failed}
	var output := FileAccess.open("res://research/rolla_godot_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() and total >= 278 else 1)
