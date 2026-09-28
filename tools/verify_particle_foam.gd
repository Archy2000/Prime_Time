extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/water_lab.tscn").instantiate();root.add_child(lab);current_scene=lab
	lab.set_physics_process(false);lab.water_fx.set_process(false);lab.sim.deterministic=true
	lab.camera.size=19;lab.camera.position=Vector3(9,18,21);lab.camera.look_at(Vector3(-1,1,0))
	for child in lab.get_children():
		if child is CanvasLayer:child.visible=false
	await physics_frame
	for frame in 150:
		lab.sim.update(1.0/30.0);lab.water_fx._process(1.0/30.0)
		if frame%3==0:await process_frame
	for version in ["before","after"]:
		lab.mat.shader=load("res://research/v12_before/water_v3.gdshader" if version=="before" else "res://shaders/water_v3.gdshader")
		lab.mat.set_shader_parameter("clock",5.0)
		lab.water_fx.whitewater.visible=version=="after"
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/v12_compare/"+version+"/objects.png")
	var particles=lab.water_fx.whitewater
	var results:={"contact_groups":particles.contact_groups,"live_particles":particles.particles.size(),"births":particles.born,"passed":particles.contact_groups>0 and particles.particles.size()>0 and particles.particles.size()<=particles.CAPACITY}
	FileAccess.open("res://research/v12_contact_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("PARTICLE_CONTACT ",results);quit(0 if results.passed else 1)
