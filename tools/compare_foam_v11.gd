extends SceneTree
## Same scene, poses, time step, camera and seed for both revisions. No game inputs/random timing.
func _init()->void:call_deferred("run")

func run()->void:
	var tag:="after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):tag=arg.trim_prefix("--tag=")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_physics_process(false);game.set_process(false)
	if tag=="before":
		game.wave_sim.shutdown()
		game.wave_sim=load("res://scripts/water_async.gd").new()
		game.wave_sim.seed_swell()
		game.water_mat.shader=load("res://research/v11_before/water_v3.gdshader")
		game.water_mat.set_shader_parameter("wave_field",game.wave_sim.texture)
		game.water_mat.set_shader_parameter("flow_field",game.wave_sim.flow_texture)
		game.water_fx.free()
		game.water_fx=Node3D.new();game.water_fx.set_script(load("res://research/v11_before/wake_fx_frozen.gd"))
		game.add_child(game.water_fx);game.water_fx.setup(game.wave_sim,game.water_level)
	game.water_fx.set_process(false);game.fx.set_process(false)
	game.wave_sim.deterministic=true
	game.growth=2.69;game.visual.scale=Vector3.ONE*2.69
	game.camera_target=Vector3(0,1,-29);game.zoom=100;game._camera_update(1)
	for child in game.get_children():
		if child is CanvasLayer and child!=game.retro_filter:child.visible=false
	for person in game.targets:person.visible=false
	game._update_water(0.4)
	var output:="res://research/v11_compare/"+tag+"/"
	var metrics:={"tag":tag,"dt":1.0/30.0,"npc_count":8,"npc_size":0.35,"shark_size":2.69,"shark_speed":9.5,"frames":120}
	var max_foam:=0.0
	for frame in 420:
		var t:=float(frame)/30.0
		var moving:=t<11.0
		for j in 8:
			var person:Node3D=game.targets[j];person.visible=true
			var base:=Vector3(-3+float(j%4)*2.0,game.water_level,-26-float(j/4)*5)
			var phase:=minf(t,11.0)*0.75+float(j)*0.9
			var pos:=base+Vector3(sin(phase)*0.9,0,cos(phase)*0.45)
			var velocity:=Vector3(cos(phase)*0.675,0,-sin(phase)*0.3375) if moving else Vector3.ZERO
			person.position=pos;person.rotation.y=atan2(velocity.x,velocity.z)
			if frame%2==0:
				game.wave_sim.swimmer(pos,velocity,0.35,2.0/30.0)
				game.water_fx.swimmer(j+1,pos,velocity,0.30)
		var shark_t:=clampf(t-6.0,0,2.5)
		game.player.position=Vector3(0,game.water_level-0.52*2.69,-15-shark_t*9.5)
		var shark_v:=Vector3(0,0,-9.5) if t>=6.0 and t<8.5 else Vector3.ZERO
		game.visual.update_motion(1.0/30.0,shark_v.length(),false)
		if frame%2==0:
			game.wave_sim.swimmer(game.player.position,shark_v,2.69,2.0/30.0)
			game.water_fx.swimmer(0,game.player.position,shark_v,2.69)
		game.wave_sim.update(1.0/30.0)
		game.water_mat.set_shader_parameter("clock",t)
		game.water_fx._process(1.0/30.0)
		for f in game.wave_sim.foam:max_foam=maxf(max_foam,f)
		if frame%2==0:
			await process_frame
			await RenderingServer.frame_post_draw
			if frame>=180:
				root.get_texture().get_image().save_png(output+"frame_%03d.png" % ((frame-180)/2))
			if frame==178:
				# Inspect only ordinary NPC movement before the large shark begins swimming.
				root.get_texture().get_image().save_png(output+"npc.png")
			if frame==238:root.get_texture().get_image().save_png(output+"city.png")
			if frame==418:root.get_texture().get_image().save_png(output+"settled.png")
	metrics["max_foam"]=max_foam
	metrics["energy_finite"]=is_finite(game.wave_sim.energy())
	FileAccess.open(output+"capture.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("FOAM_COMPARISON ",metrics);quit()
