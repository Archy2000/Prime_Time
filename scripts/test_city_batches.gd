extends SceneTree
func _init()->void:call_deferred("run")

func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(0.5).timeout
	var game=current_scene
	game.set_physics_process(false);game.water_fx.set_process(false)
	var sources:Array[MeshInstance3D]=[]
	var nonuniform:=0
	for node in game.city.get_children():
		if node is MeshInstance3D and node.has_meta("render_layers"):
			sources.append(node)
			var scale:Vector3=node.global_basis.get_scale().abs()
			if absf(scale.x-scale.y)>0.0001 or absf(scale.z-scale.y)>0.0001:nonuniform+=1
	var result:Dictionary={"batched_instances":game.city_batches.instances,"batches":game.city_batches.batches,"nonuniform_instances":nonuniform,"collision_shapes":game.collision_mesh_cache.size(),"colliders":game.solids.size()}
	var renderers:Array=game.city_batches.get_children()
	# Compare exactly the same frozen scene, with only its draw representation changed.
	for batch in renderers:batch.hide()
	for node in sources:
		node.layers=int(node.get_meta("render_layers"));node.cast_shadow=int(node.get_meta("render_shadow"))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/city_batch_before.png")
	for node in sources:node.layers=0;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for batch in renderers:batch.show()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/city_batch_after.png")
	# Visibility changes must remove exactly the corresponding batch instance.
	var removed:=false;var restored:=false
	var source:=sources[0]
	var transforms:Array[Transform3D]=[]
	for batch in renderers:
		for i in batch.multimesh.instance_count:transforms.append(batch.multimesh.get_instance_transform(i))
	source.hide()
	var index:=0
	for batch in renderers:
		for i in batch.multimesh.instance_count:
			var transform:Transform3D=batch.multimesh.get_instance_transform(i)
			if transform!=transforms[index]:removed=transform.basis.determinant()==0.0
			index+=1
	source.show();index=0;restored=true
	for batch in renderers:
		for i in batch.multimesh.instance_count:
			restored=restored and batch.multimesh.get_instance_transform(i)==transforms[index];index+=1
	result["hide_removes_instance"]=removed;result["show_restores_instance"]=restored
	result["passed"]=removed and restored and sources.size()>1800 and game.collision_mesh_cache.size()<200
	FileAccess.open("res://research/city_batch_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CITY_BATCH ",result);quit(0 if result.passed else 1)
