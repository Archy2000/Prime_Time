extends SceneTree
## Real rendered-frame benchmark. Run before/after sequentially on the same GPU.
func _init()->void:call_deferred("run")

func stats(values:Array)->Dictionary:
	if values.is_empty():return {}
	values.sort()
	var sum:=0.0
	for value in values:sum+=float(value)
	return {"mean_ms":sum/values.size(),"p50_ms":values[int(values.size()*0.5)],"p95_ms":values[int(values.size()*0.95)],"max_ms":values.back(),"samples":values.size()}

func run()->void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	var game=current_scene
	game.profile_enabled=true;game.water_fx.profile_enabled=true
	var mesh_counts:Dictionary={}
	for node in game.city.get_children():
		if node is MeshInstance3D:
			var id:int=node.mesh.get_instance_id()
			mesh_counts[id]=int(mesh_counts.get(id,0))+1
	print("CITY_MESHES unique=",mesh_counts.size()," total=",game.city.get_child_count())
	var output:Dictionary={"renderer":RenderingServer.get_video_adapter_name(),"phases":{}}
	for phase in ["idle","swim","feeding","destruction"]:
		game.player.position=Vector3(0,game.water_level-0.52,-24)
		game.player.velocity=Vector3.ZERO
		if phase!="idle":Input.action_press("forward")
		if phase=="feeding":
			for i in 16:game._capture_target(game.targets.size()-1)
		if phase=="destruction":
			game.growth=3.2;game.visual.scale=Vector3.ONE*3.2
			var parts:Array=game.buildings["JapanStage/JapanHighriser"].parts
			for part in parts:game._break_piece(part)
		game.profile_samples.clear();game.water_fx.profile_samples.clear()
		var frames:Array[float]=[]
		var deadline:=Time.get_ticks_usec()+6000000
		var previous:=Time.get_ticks_usec()
		while Time.get_ticks_usec()<deadline:
			await process_frame
			var now:=Time.get_ticks_usec()
			frames.append(float(now-previous)/1000.0);previous=now
			if game.defeated:
				game.defeated=false;game.health=100;game.paused=false;game.pause_label.hide();paused=false
		Input.action_release("forward")
		var modules:Dictionary={}
		for key in game.profile_samples:modules[key]=stats(game.profile_samples[key])
		modules["water_effects"]=stats(game.water_fx.profile_samples)
		output.phases[phase]={"frames":stats(frames),"modules":modules,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"wake_tracks":game.water_fx.tracks.size(),"wave_step_ms":game.wave_sim.last_step_ms,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
		print("PERF_PHASE ",phase," ",JSON.stringify(output.phases[phase]))
	var tag:="latest"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-tag="):tag=arg.trim_prefix("--perf-tag=")
	FileAccess.open("res://research/project_performance_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	quit()
