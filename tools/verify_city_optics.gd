extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_process(false);game.set_physics_process(false)
	game.water_fx.set_process(false);game.fx.set_process(false);game.wave_sim.deterministic=true
	game.camera_target=Vector3(0,1,-29);game.zoom=100;game._camera_update(1)
	for child in game.get_children():
		if child is CanvasLayer and child!=game.retro_filter:child.visible=false
	game._update_water(0.4)
	for frame in 90:
		game.wave_sim.update(1.0/30.0);game.water_fx._process(1.0/30.0)
		if frame%4==0:await process_frame
	for version in ["before","after"]:
		game.water_mat.shader=load("res://research/v13_before/water_v3.gdshader" if version=="before" else "res://shaders/water_v3.gdshader")
		game.water_mat.set_shader_parameter("clock",3.0)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/v13_compare/city_"+version+".png")
	print("CITY_OPTICS identical simulation state; finite=",is_finite(game.wave_sim.energy()))
	quit()
