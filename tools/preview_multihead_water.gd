extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	while current_scene==null:await process_frame
	var game:Node3D=current_scene
	while not game.ready_done:await process_frame
	game.set_physics_process(false);game.set_process(false);game.notice.hide()
	game.water_level=4.0;game.water.position.y=4.0;game.growth=2.4;game.visual.scale=Vector3.ONE*2.4
	game.player.position=Vector3(0,game._swim_body_y(4.0),-35)
	for level in [2,4]:
		game._set_shark_heads([0,2,3,5,9][level])
		game._lock_shark_to_water();game._update_water(0.016)
		game.camera.position=game.visual.global_position+Vector3(12,17,-19);game.camera.look_at(game.visual.global_position,Vector3.UP);game.camera.fov=35
		for i in 5:
			game.shark_heads.update_sockets();await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/multihead_water_%d.png"%level)
	quit()
