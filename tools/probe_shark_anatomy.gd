extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var shark:=Node3D.new();shark.set_script(load("res://scripts/shark.gd"));root.add_child(shark)
	var source:Node3D=shark.get_node("PS1Shark")
	var skeleton:Skeleton3D=source.find_child("Skeleton3D",true,false)
	for i in skeleton.get_bone_count():print("BONE ",i," ",skeleton.get_bone_name(i)," rest=",skeleton.get_bone_global_rest(i))
	for node in source.find_children("*","MeshInstance3D"):
		print("MESH ",node.name," transform=",node.transform," skeleton=",node.skeleton," skinbinds=",node.skin.get_bind_count() if node.skin else 0)
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			print("SURFACE ",surface," vertices=",arrays[Mesh.ARRAY_VERTEX].size()," bones=",arrays[Mesh.ARRAY_BONES].size()," mat=",node.get_active_material(surface))
	quit()
