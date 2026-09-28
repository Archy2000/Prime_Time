extends SceneTree

func _init()->void:call_deferred("run")

func run()->void:
	change_scene_to_file("res://scenes/water_lab.tscn")
	await scene_changed
	var lab=current_scene
	lab.set_physics_process(false)
	# Finish any outstanding worker before switching to a reproducible fixed-step run.
	if lab.sim.task_id>=0:
		WorkerThreadPool.wait_for_task_completion(lab.sim.task_id);lab.sim.task_id=-1
	lab.sim.deterministic=true
	lab.camera.size=30
	lab.camera.position=Vector3(13,23,27);lab.camera.look_at(Vector3(0,0,0))
	for frame in 270:
		if frame==30:
			for x in range(-16,17,2):lab.sim.disturb(Vector3(x,1,6),1.8,0.28,0,Vector2(0,-0.55))
		lab.sim.update(1.0/30.0)
		lab.mat.set_shader_parameter("clock",float(frame+1)/30.0)
		if frame%3==0:await process_frame
		if frame in [59,149,269]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://research/v9_surf_%03d.png" % frame)
	print("SURF_RENDER finite=",is_finite(lab.sim.energy())," emitted=",lab.water_fx.surf_emitted," live_drops=",lab.water_fx.droplets.size())
	quit()
