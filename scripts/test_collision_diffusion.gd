extends SceneTree
var result:Dictionary={}
func _init()->void:call_deferred("run")

func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/v7_blood_"+label+".png")

func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.6).timeout
	var game=current_scene;game.set_physics_process(false)
	var missing:=0;var count:=0
	for key in game.buildings:
		for part:MeshInstance3D in game.buildings[key].parts:
			count+=1
			if not game.solids.has(part.get_instance_id()):missing+=1
	result["building_parts"]=count;result["missing_building_colliders"]=missing
	result["all_building_parts_collidable"]=missing==0
	var scenarios:Array=[]
	# Exercise the real overlap-query path, not direct _break_piece calls.
	for family in ["2floor lowrise","lowrise2floors curve","lowrise2floors l","japanhighriser","japanesehome","talo_"]:
		for level in [1.15,3.3]:
			var selected:MeshInstance3D;var key_selected:=""
			for key:String in game.buildings:
				if not family in key.to_lower() or game.buildings[key].collapsing:continue
				for part:MeshInstance3D in game.buildings[key].parts:
					var box:AABB=part.global_transform*part.mesh.get_aabb()
					if box.size.y>0.6 and not part.get_meta("broken",false):selected=part;key_selected=key;break
				if selected!=null:break
			if selected==null:scenarios.append({"family":family,"level":level,"passed":false,"reason":"no fixture"});continue
			game.water_level=level;game.growth=3.2 if level>3 else 1.65
			# An actual mesh vertex is guaranteed to lie on its triangle collider.
			var arrays:=selected.mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var point:Vector3=selected.global_transform*vertices[0]
			var best:=INF
			for vertex:Vector3 in vertices:
				var world:Vector3=selected.global_transform*vertex
				if absf(world.y-level)<best:point=world;best=absf(world.y-level)
			var normal:=Vector3.RIGHT
			game.player.position=point+normal*game.growth*0.6-Vector3.UP*game.growth*0.4
			game.player.position.y=level-0.52*game.growth
			game.visual.rotation=Vector3(0,PI/2,0)
			var before:int=game.wrecked
			game.growth=1.0;game._ram_nearby(-normal*12)
			var gated:bool=game.wrecked==before
			game.growth=3.2 if level>3 else 1.65
			for attempt in 3:
				game._ram_nearby(-normal*12)
				await physics_frame
			var damaged:bool=game.buildings[key_selected].hits>0
			scenarios.append({"family":family,"level":level,"growth":game.growth,"growth_gate":gated,"passed":damaged and gated})
	result["ram_scenarios"]=scenarios
	result["all_families_ram"]=true
	for scenario in scenarios:
		if not scenario.passed:result.all_families_ram=false
	# Isolate diffusion from further emission, with a fixed camera and location.
	game.water_level=1.15;game.water.position.y=1.15;game.growth=1.0
	game.player.position=Vector3(0,0.63,-24);game.camera_target=Vector3(0,1.15,-24);game.zoom=80;game._camera_update(1)
	var fx=game.fx
	game.player.hide()
	fx._stamp_blood(Vector3(0,1.15,-24),4.0,0)
	var stain:Dictionary=fx.splats[-1];result["water_lifetime_short"]=stain.water and stain.life>=5 and stain.life<=7
	await capture("fresh")
	fx.update(2.0)
	result["cloud_expands"]=stain.node.scale.x>1.8
	result["diffusion_advances"]=is_equal_approx(stain.material.get_shader_parameter("age"),2.0)
	await capture("2s")
	fx.update(2.0);await capture("4s")
	fx.update(3.1)
	result["water_cleared_by_7s"]=fx.splats.is_empty()
	await capture("7s")
	result["passed"]=true
	for key in result:
		if result[key] is bool and not result[key]:result.passed=false
	FileAccess.open("res://research/v7_collision_diffusion_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COLLISION_DIFFUSION ",result);quit(0 if result.passed else 1)
