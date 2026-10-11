extends SceneTree
var results:Dictionary={}
func _init()->void:call_deferred("test")
func check(key:String,value:bool)->void:results[key]=value;print("CHECK ",key," ",value)
func test()->void:
	var shark:=Node3D.new();shark.set_script(load("res://scripts/shark.gd"));root.add_child(shark)
	var source:Node3D=shark.get_node("PS1Shark")
	var skeleton:Skeleton3D=source.find_child("Skeleton3D",true,false)
	var body_meshes:Dictionary={}
	for part in ["Torso","Abdomen","TailStart","TailEnd","PectoralFin_L","PectoralFin_R"]:body_meshes[part]=skeleton.get_node(part).mesh
	var organs:=Node3D.new();organs.set_script(load("res://scripts/mutation_visual.gd"));shark.add_child(organs)
	for level in [1,2,3,4]:
		organs.rebuild({"hydra":level})
		var helper:Node3D=organs.hydra_model
		var body_unchanged:=source.visible
		for part in body_meshes:body_unchanged=body_unchanged and skeleton.get_node(part).mesh==body_meshes[part] and skeleton.get_node(part).visible
		check("level_%d_original_body_tail_fins"%level,body_unchanged)
		var arrays_preserved:=true;var textures_preserved:=true;var rigid_skull:=true;var root_preserved:=true
		var root_vertices:=0
		for copy:MeshInstance3D in helper.generated_parts:
			var part_name:String=String(copy.name).get_slice("_",2)
			var branch:int=int(String(copy.name).get_slice("_",1))
			var original:MeshInstance3D=skeleton.get_node(part_name)
			var a:Array=original.mesh.surface_get_arrays(0);var b:Array=copy.mesh.surface_get_arrays(0)
			for key in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:arrays_preserved=arrays_preserved and a[key]==b[key]
			textures_preserved=textures_preserved and original.get_active_material(0).albedo_texture==copy.get_active_material(0).albedo_texture
			arrays_preserved=arrays_preserved and copy.skin==original.skin and copy.get_parent()==skeleton
			var spec:Vector3=helper.specifications[branch]
			for i in a[Mesh.ARRAY_VERTEX].size():
				var p:Vector3=a[Mesh.ARRAY_VERTEX][i];var q:Vector3=b[Mesh.ARRAY_VERTEX][i]
				if p.z<=helper.ROOT_Z:
					root_vertices+=1;root_preserved=root_preserved and p.is_equal_approx(q)
				if p.z>=1.30:
					var pivot:=Vector3(0,0,helper.ROOT_Z)
					var expected:=Basis(Vector3.UP,spec.x)*(p-pivot)+pivot+Vector3(spec.y,0,spec.z)
					rigid_skull=rigid_skull and expected.is_equal_approx(q)
		check("level_%d_original_uv_skin_indices"%level,arrays_preserved)
		check("level_%d_original_texture"%level,textures_preserved)
		check("level_%d_undeformed_skull"%level,rigid_skull)
		check("level_%d_shared_neck_roots"%level,root_preserved and root_vertices>0)
		check("level_%d_exact_head_count"%level,organs.heads.size()+1==[2,3,5,9][level-1])
		shark.update_motion(0.15,8,false);organs.animate(0.15)
		check("level_%d_live_mouth_pose"%level,organs.primary_mouth().is_finite() and helper.sockets[0].global_position==organs.primary_mouth())
	organs.rebuild({"hydra":2,"zombie":2})
	check("hybrid_original_head_skin_tint",organs.hydra_model.generated_parts[0].get_active_material(0).albedo_color==Color(0.43,0.68,0.33))
	organs.rebuild({})
	var clean:=true
	for part in ["Head","Jaw","TeethTop"]:clean=clean and skeleton.get_node(part).visible
	for child in skeleton.get_children():
		if String(child.name).begins_with("Mutation_"):clean=false
	check("original_restored_no_orphan_heads",clean and organs.heads.is_empty())
	var passed:=true
	for value in results.values():passed=passed and value
	results["passed"]=passed
	FileAccess.open("res://research/source_shark_hydra_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("SOURCE_HYDRA_RESULT ",passed)
	await process_frame;quit(0 if passed else 1)
