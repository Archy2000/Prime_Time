extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.7).timeout
	var game=current_scene
	var result:Dictionary={}
	game.cooldown=0;game._start_boost()
	result.cooldown_reduced_20_percent=is_equal_approx(game.cooldown-game.boost_time,4.0)
	game.boost_time=0
	var cases:Array=[]
	for size in [1.0,3.2]:
		game.growth=size;game.eaten=roundi((size-1)/0.065);game.water_level=game._growth_water_target()
		game.player.get_child(0).shape.radius=0.55*size;game.player.get_child(0).position.y=0.4*size
		for tower in game.tower_district.towers:
			game.player.position=tower.position+Vector3.UP*game._swim_body_y(game.water_level)
			game.airborne=false;game.player.velocity=Vector3.ZERO;game.trapped_time=0
			await create_timer(1.4).timeout
			cases.append(game._water_column_clear(game.player.position))
	result.enclosed_swim_recovers=not false in cases
	result.cases=cases
	var submerged_cases:Array=[]
	for family in ["2floor lowrise","lowrise2floors curve","lowrise2floors l","japanhighriser","japanesehome","talo_"]:
		for key in game.buildings:
			if not family in String(key).to_lower():continue
			var parts:Array=game.buildings[key].parts
			var box:AABB=parts[0].global_transform*parts[0].mesh.get_aabb()
			for part in parts:box=box.merge(part.global_transform*part.mesh.get_aabb())
			game.player.position=box.get_center();game.player.position.y=game.water_level+0.2
			game.airborne=true;game.air_age=1;game.jump_velocity=-2;game.air_drift=Vector3.ZERO;game.leap_target=null;game.roof_escape=false;game.trapped_time=0
			await create_timer(2.6).timeout
			submerged_cases.append({"family":family,"clear":not game.airborne and game._water_column_clear(game.player.position)})
			break
	result.submerged_roof_cases=submerged_cases
	result.submerged_roofs_recover=submerged_cases.size()==6
	for scenario in submerged_cases:
		if not scenario.clear:result.submerged_roofs_recover=false
	game.set_physics_process(false)
	var source:MeshInstance3D=game.tower_district.towers[0].roof
	game.fx.fracture(source,Vector3.RIGHT*5)
	var body:RigidBody3D=game.fx.fragments[-1]
	var mesh:MeshInstance3D=body.get_child(0)
	var original_mesh:Mesh=mesh.mesh
	var original_material:Material=mesh.get_active_material(0)
	game.floating_world.accept_piece(body)
	var debris:Dictionary=game.floating_world.stones[-1]
	result.original_geometry_preserved=debris.node.mesh==original_mesh
	result.original_material_preserved=debris.node.get_active_material(0)==original_material
	result.no_sandcastle_rock=not game.floating_world.sources.has("Rock_01")
	game.fx.fragments.erase(body);body.queue_free()
	result.passed=result.cooldown_reduced_20_percent and result.enclosed_swim_recovers and result.submerged_roofs_recover and result.original_geometry_preserved and result.original_material_preserved and result.no_sandcastle_rock
	FileAccess.open("res://research/rubble_unstuck_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("RUBBLE_UNSTUCK ",result);quit(0 if result.passed else 1)
