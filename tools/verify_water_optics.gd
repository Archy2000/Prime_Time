extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var lab=load("res://scenes/water_lab.tscn").instantiate();root.add_child(lab);current_scene=lab
	lab.set_physics_process(false);lab.water_fx.set_process(false);lab.sim.deterministic=true
	for child in lab.get_children():
		if child is CanvasLayer:child.visible=false
	await physics_frame
	for frame in 120:
		lab.sim.update(1.0/30.0);lab.water_fx._process(1.0/30.0)
		if frame%4==0:await process_frame
	var views:={"top":Vector3(28,39,34),"low":Vector3(28,14,36),"opposite":Vector3(-28,18,36)}
	for angle in views:
		lab.camera.size=47;lab.camera.position=views[angle];lab.camera.look_at(Vector3(0,0,1))
		for version in ["before","after"]:
			lab.mat.shader=load("res://research/v13_before/water_v3.gdshader" if version=="before" else "res://shaders/water_v3.gdshader")
			lab.mat.set_shader_parameter("clock",4.0)
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://research/v13_compare/"+angle+"_"+version+".png")
	print("WATER_OPTICS rendered three angles at identical simulation state; finite=",is_finite(lab.sim.energy()))
	quit()
