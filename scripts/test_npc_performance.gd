extends SceneTree
## Headless CPU benchmark; does not measure GPU rendering or overall game FPS.
func _init()->void:call_deferred("run")

func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	var game=current_scene
	game.set_physics_process(false)
	game.player.position=Vector3(0,game.water_level-0.52,-25)
	var saved:Array[Dictionary]=[]
	for actor in game.targets:
		var state:Dictionary={}
		for property in actor.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				state[property.name]=actor.get(property.name)
		state["position"]=actor.position;state["rotation"]=actor.rotation
		saved.append(state)
	var timings:Array[float]=[]
	var counts:Array[int]=[]
	for scheduled in [false,true]:
		for i in game.targets.size():
			for key in saved[i]:game.targets[i].set(key,saved[i][key])
		var updates:=0
		var start:=Time.get_ticks_usec()
		for frame in 120:
			for actor in game.targets:
				var dt:float=actor.scheduled_delta(game,1.0/60.0) if scheduled else 1.0/60.0
				if dt>0:
					actor.update_civilian(game,dt)
					game.npc_audio.update_actor(actor,dt)
					updates+=1
				game._can_eat(actor,false)
		timings.append(float(Time.get_ticks_usec()-start)/120000.0)
		counts.append(updates)
	# Entering the nearby band must immediately flush accumulated simulation time.
	var actor=game.targets[0]
	actor.simulation_wait=0.2;actor.simulation_elapsed=0.0
	actor.position=game.player.position+Vector3(1,0,0)
	var immediate:bool=actor.scheduled_delta(game,1.0/60.0)>0
	var capturable:bool=game._can_eat(actor,true)
	var result:Dictionary={"population":game.targets.size(),"every_frame_ms":timings[0],"scheduled_ms":timings[1],"every_frame_updates":counts[0],"scheduled_updates":counts[1],"nearby_immediate":immediate,"nearby_capturable":capturable}
	var meals_before:int=game.eaten
	for i in 16:game._capture_target(game.targets.size()-1)
	game.fx.update(0.4)
	var shared:=true
	for drop in game.fx.blood_drops:
		shared=shared and drop.node.mesh==game.fx.blood_drop_mesh and drop.node.material_override==game.fx.blood_drop_material
	result["batch_meals"]=game.eaten-meals_before
	result["shared_blood_resources"]=shared and not game.fx.blood_drops.is_empty()
	result["bounded_blood_drops"]=game.fx.blood_drops.size()<=72
	result["passed"]=counts[1]<counts[0]*0.6 and immediate and capturable and result.batch_meals==16 and result.shared_blood_resources and result.bounded_blood_drops
	FileAccess.open("res://research/npc_performance_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("NPC_PERFORMANCE ",result)
	quit(0 if result.passed else 1)
