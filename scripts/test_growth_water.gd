extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.5).timeout
	var game=current_scene;game.set_physics_process(false)
	var result:Dictionary={};var cases:Array=[]
	for size in [1.0,2.3,3.2]:
		game.growth=size;game.visual.scale=Vector3.ONE*size;game.water_level=1.15
		game.player.position=Vector3(0,0.6,-35);game.airborne=false
		game._lock_shark_to_water()
		var safe:bool=game.visual.global_position.y-game.SHARK_LOWER_EXTENT*size>=game.swim_floor_y+game.FLOOR_CLEARANCE-0.001
		var body_safe:bool=game._swim_body_y(0.5)+0.4*size-0.55*size>=game.swim_floor_y+game.FLOOR_CLEARANCE-0.001
		var before:float=game.water_level;game._update_growth_water(1.0/60.0)
		var smooth:bool=game.water_level-before<=0.45/60+0.0001
		for step in 600:game._update_growth_water(1.0/60.0)
		var target:float=game._growth_water_target()
		var arrived:bool=is_equal_approx(game.water_level,target)
		game._lower_water(10)
		var protected:bool=is_equal_approx(game.water_level,target)
		cases.append({"size":size,"water":game.water_level,"shallow_model_clearance":safe,"shallow_body_clearance":body_safe,"smooth":smooth,"reached_target":arrived,"manual_lower_protected":protected})
		game.player.position.y=game._swim_body_y(game.water_level)
		game.water.position.y=game.water_level;game._lock_shark_to_water();game._update_water(0.016)
		game.camera_target=game.visual.global_position;game.zoom=80;game._camera_update(1)
		game.status.text="体型 %.2f× / 成长水位验证"%size
		game.feed_label.text="水位 %.2fm / 地面间隙保护"%game.water_level
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://research/growth_water_"+str(size)+".png")
	game.water_level=4.8;game._update_growth_water(1)
	result["higher_manual_water_preserved"]=is_equal_approx(game.water_level,4.8)
	game.airborne=true;game.player.position.y=7;game._lock_shark_to_water()
	result["jump_not_clamped"]=is_equal_approx(game.visual.global_position.y,7)
	result["cases"]=cases;result["passed"]=result.higher_manual_water_preserved and result.jump_not_clamped
	for item in cases:
		for key in item:
			if item[key] is bool and not item[key]:result.passed=false
	FileAccess.open("res://research/growth_water_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("GROWTH_WATER ",result);quit(0 if result.passed else 1)
