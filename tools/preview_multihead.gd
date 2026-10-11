extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.022,0.055,0.075);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(0.58,0.72,0.80);environment.environment.ambient_light_energy=0.6;scene.add_child(environment)
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-48,-35,0);light.light_energy=1.5
	var fill:=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-15,140,0);fill.light_color=Color(0.37,0.68,0.9);fill.light_energy=0.7
	var shark:=Node3D.new();shark.set_script(load("res://scripts/shark.gd"));scene.add_child(shark)
	var organs:=Node3D.new();organs.set_script(load("res://scripts/mutation_visual.gd"));shark.add_child(organs)
	var camera:=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.5;camera.current=true
	var ui:=CanvasLayer.new();scene.add_child(ui);var label:=Label.new();label.position=Vector2(40,30);label.add_theme_font_size_override("font_size",28);ui.add_child(label)
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI"]);label.add_theme_font_override("font",font)
	var before:=OS.get_cmdline_user_args().has("--before")
	for level in [0,1,2,3,4]:
		organs.rebuild({"hydra":level});organs.animate(0.25)
		label.text="现有普通鲨鱼 · 原始模型" if level==0 else "%d 头进化 · 原鲨鱼网格与贴图"%[2,3,5,9][level-1]
		for view in ["front","top"]:
			camera.size=3.6 if view=="front" else 4.5
			camera.position=Vector3(5,4.2,-7) if view=="front" else Vector3(0,8,0.1)
			camera.look_at(Vector3.ZERO,Vector3.UP if view=="front" else Vector3.FORWARD)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://research/multihead_%s_%d_%s.png"%["before" if before else "after",level,view])
	# Side-by-side real render: the same source shark, with and without a fork.
	organs.rebuild({"hydra":2});shark.position.x=-1.55
	var ordinary:=Node3D.new();ordinary.set_script(load("res://scripts/shark.gd"));scene.add_child(ordinary);ordinary.position.x=1.55
	shark.update_motion(0.18,5,false);ordinary.update_motion(0.18,5,false);organs.animate(0.18)
	camera.size=4.0;camera.position=Vector3(0,4.5,-6);camera.look_at(Vector3.ZERO,Vector3.UP)
	label.text="普通鲨鱼 → 三头进化   /   复用现有模型、贴图和骨骼"
	for i in range(2):
		var caption:=Label.new();caption.position=Vector2(i*640,640);caption.size.x=640;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.text=["原始普通鲨鱼","基于原头部的三头变异"][i];caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",24);ui.add_child(caption)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/source_shark_comparison.png")
	quit()
