extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.7).timeout
	var game=current_scene
	game.growth=1.195;game.eaten=3;game.water_level=1.4035
	game.player.get_child(0).shape.radius=0.55*game.growth;game.player.get_child(0).position.y=0.4*game.growth
	var fixtures:Array=[]
	for key in game.buildings:
		var parts:Array=game.buildings[key].parts
		var box:AABB=parts[0].global_transform*parts[0].mesh.get_aabb()
		for part in parts:box=box.merge(part.global_transform*part.mesh.get_aabb())
		if box.size.y<3.5 and box.size.x>2 and box.size.z>2:fixtures.append({"key":key,"box":box})
	fixtures.sort_custom(func(a,b):return a.box.size.y<b.box.size.y)
	var cases:Array=[]
	for fixture in fixtures.slice(0,4):
		var box:AABB=fixture.box
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(box.get_center()+Vector3.UP*10,box.get_center()-Vector3.UP*10,1))
		if hit.is_empty():continue
		game.player.position=hit.position+Vector3.UP*(0.15*game.growth+0.015)
		game.airborne=false;game.player.velocity=Vector3.ZERO;game.trapped_time=0;game.last_swim_safe=Vector3(0,game._swim_body_y(game.water_level),-35)
		var start:Vector3=game.player.position
		await create_timer(2.5).timeout
		var expected_y:float=game._swim_body_y(game.water_level+game.wave_sim.sample_surface(game.player.position).y)
		cases.append({"key":fixture.key,"start":str(start),"end":str(game.player.position),"height_error":absf(game.player.position.y-expected_y),"passed":not game.airborne and absf(game.player.position.y-expected_y)<0.25 and game._water_column_clear(Vector3(game.player.position.x,expected_y,game.player.position.z))})
	var passed:bool=cases.size()==4
	for c in cases:
		if not c.passed:passed=false
	# Manual steering must override both roof exit and jump target assistance.
	game.player.position=Vector3(0,5,-35);game.airborne=true;game.jump_velocity=5;game.air_age=0
	game.roof_escape=true;game.escape_point=game.player.position-Vector3.RIGHT*20
	for target in game.targets:
		if target.get_meta("rooftop",false):game.leap_target=target;break
	Input.action_press("right")
	await create_timer(0.2).timeout
	Input.action_release("right")
	var wanted:Vector3=game.camera.global_basis.x;wanted.y=0
	var manual:bool=game.player.velocity.dot(wanted)>0.5 and game.leap_target==null
	var result:Dictionary={"cases":cases,"manual_steering_overrides_assist":manual,"passed":passed and manual}
	FileAccess.open("res://research/perched_shark_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PERCHED ",result);quit(0 if passed else 1)
