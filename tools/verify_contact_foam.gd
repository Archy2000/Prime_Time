extends SceneTree
func _init()->void:call_deferred("run")

func run()->void:
	var lab=load("res://scenes/water_lab.tscn").instantiate();root.add_child(lab);current_scene=lab
	lab.set_physics_process(false);lab.water_fx.set_process(false);lab.sim.deterministic=true
	lab.camera.size=24;lab.camera.position=Vector3(10,18,22);lab.camera.look_at(Vector3(0,1,0))
	for child in lab.get_children():
		if child is CanvasLayer:child.visible=false
	for frame in 90:lab.sim.update(1.0/30.0)
	var captures:Array[Image]=[]
	for version in ["before","after"]:
		lab.mat.shader=load("res://research/v11_before/water_v3.gdshader" if version=="before" else "res://shaders/water_v3.gdshader")
		lab.mat.set_shader_parameter("clock",3.0)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var capture:Image=root.get_texture().get_image();captures.append(capture)
		capture.save_png("res://research/v11_compare/"+version+"/objects.png")
	var brighter:=0
	for y in captures[0].get_height():
		for x in captures[0].get_width():
			if captures[1].get_pixel(x,y).get_luminance()-captures[0].get_pixel(x,y).get_luminance()>0.12:brighter+=1
	var results:={"new_bright_edge_pixels":brighter,"image_pixels":captures[0].get_width()*captures[0].get_height(),"passed":brighter>30 and brighter<20000}
	FileAccess.open("res://research/v11_contact_render_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("CONTACT_RENDER ",results);quit(0 if results.passed else 1)
