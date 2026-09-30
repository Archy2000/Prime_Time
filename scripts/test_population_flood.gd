extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.1).timeout
	var game=current_scene
	var water_count:=0;var roof_count:=0;var blocked:=0
	for npc in game.targets:
		if npc.get_meta("rooftop",false):roof_count+=1;continue
		water_count+=1
		var ray:=PhysicsRayQueryParameters3D.create(npc.position+Vector3.UP*30,npc.position-Vector3.UP*0.1,1)
		if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():blocked+=1
	var result:Dictionary={"water_npcs":water_count,"roof_npcs":roof_count,"blocked_water_spawns":blocked,"max_water":game.MAX_WATER_LEVEL}
	game.growth=3.2;game.eaten=34;game.visual.scale=Vector3.ONE*3.2
	game.player.get_child(0).shape.radius=0.55*3.2;game.player.get_child(0).position.y=0.4*3.2
	result.growth_water=game._growth_water_target()
	game.water_level=game.MAX_WATER_LEVEL
	game.player.position=Vector3(53,game._swim_body_y(game.water_level),-30)
	await create_timer(1.5).timeout
	var swimming_at_surface:=0
	for npc in game.targets:
		if not npc.get_meta("rooftop",false) and absf(npc.position.y-game.water_level)<0.5:swimming_at_surface+=1
	result.npcs_follow_high_water=swimming_at_surface>=water_count
	result.water_mesh_follows=is_equal_approx(game.water.position.y,12)
	result.passed=water_count==180 and roof_count==80 and blocked==0 and result.npcs_follow_high_water and result.water_mesh_follows
	FileAccess.open("res://research/population_flood_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("POPULATION_FLOOD ",result);quit(0 if result.passed else 1)
