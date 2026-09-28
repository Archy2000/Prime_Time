extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(1.0).timeout
	var game=current_scene
	var result:={"roof_people":game.roof_targets,"submerged":game.player.position.y<game.water_level-0.40}
	var roof_person:Node3D
	var launch:=Vector3.ZERO
	for target in game.targets:
		if not target.get_meta("rooftop",false):continue
		if target.position.y<3.5:continue
		var roof:MeshInstance3D=target.get_meta("roof_support")
		var bounds:AABB=roof.global_transform*roof.mesh.get_aabb()
		for offset in [Vector3(bounds.size.x/2+2,0,0),Vector3(-bounds.size.x/2-2,0,0),Vector3(0,0,bounds.size.z/2+2),Vector3(0,0,-bounds.size.z/2-2)]:
			var p:Vector3=bounds.get_center()+offset;p.y=game.water_level-0.52
			var ray:=PhysicsRayQueryParameters3D.create(p,p+Vector3.UP*14,1)
			if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and p.distance_to(target.position)<8:
				roof_person=target;launch=p;break
		if roof_person:break
	var support:MeshInstance3D=roof_person.get_meta("roof_support")
	var box:AABB=support.global_transform*support.mesh.get_aabb()
	game.growth=1.0;game._break_piece(support)
	result["small_cannot_break"]=not support.get_meta("broken",false)
	game.player.position=launch
	var heading:Vector3=roof_person.position-launch;heading.y=0
	game.player.velocity=Vector3.ZERO;game.visual.rotation.y=atan2(-heading.x,-heading.z);game.camera_target=game.player.position;game.zoom=80;game._camera_update(1.0)
	result["cannot_eat_from_water"]=not game._can_eat(roof_person,true)
	var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	result["jump_started"]=game.airborne
	Input.action_press("bite")
	var peak:float=game.player.position.y
	for frame in 150:
		await physics_frame;peak=maxf(peak,game.player.position.y)
		if frame==32:
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://research/v5_roof_jump.png")
	Input.action_release("bite")
	result["peak_y"]=peak;result["roof_y"]=roof_person.position.y if is_instance_valid(roof_person) else box.end.y
	result["roof_eaten"]=game.roof_eaten
	game.growth=game.BUILDING_GROWTH;game._break_piece(support)
	result["grown_can_break"]=support.get_meta("broken",false)
	await create_timer(2.5).timeout
	result["returned_to_water"]=not game.airborne
	result["passed"]=result.submerged and result.small_cannot_break and result.cannot_eat_from_water and result.jump_started and result.roof_eaten>0 and result.grown_can_break and result.returned_to_water
	FileAccess.open("res://research/v5_gameplay_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("ROOF_TEST ",result);quit(0 if result.passed else 1)
