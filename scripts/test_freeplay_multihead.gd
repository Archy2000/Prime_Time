extends SceneTree
var checks:Dictionary={}
func _init()->void:call_deferred("test")
func check(label:String,passed:bool)->void:
	checks[label]=passed;print("FREEPLAY ",label," ",passed)
func test()->void:
	change_scene_to_file("res://scenes/main.tscn")
	while current_scene==null:await process_frame
	var game:Node3D=current_scene
	while not game.ready_done:await process_frame
	check("immediate_play_without_briefing",not paused and not game.paused)
	check("default_three_heads",game.shark_head_count==3 and game.shark_heads.sockets.size()==3)
	check("no_roguelite_controller",not game.get_script().source_code.contains("roguelite_run.gd"))
	var no_objective:=true
	for node in game.get_children():
		if node.get_script()!=null and node.get_script().resource_path.ends_with("run_landmark.gd"):no_objective=false
	check("no_clocktower_objective",no_objective)
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/freeplay_multihead.png")
	game.set_physics_process(false);game.set_process(false)
	game.health=50
	for i in 100:game._finish_meal(game.player.position)
	await process_frame
	check("meals_do_not_open_cards_or_pause",not paused and not game.paused and game.eaten==100)
	check("original_growth_restored",is_equal_approx(game.growth,3.2))
	check("food_does_not_evolve_model",game.shark_head_count==3)
	game.health=50;game._finish_meal(game.player.position)
	check("original_heal_restored",is_equal_approx(game.health,58))
	for count in game.SHARK_FORMS:
		game._set_shark_heads(count)
		check("switch_%d_heads"%count,not is_instance_valid(game.shark_heads) if count==1 else game.shark_heads.sockets.size()==count)
	check("form_switch_keeps_stats",game.growth==3.2 and game.health==58)
	var key:=InputEventKey.new();key.physical_keycode=KEY_F4;key.pressed=true
	root.push_input(key);await process_frame
	check("f4_cycles_to_normal",game.shark_head_count==1)
	game.elapsed=600;game._physics_process(0.016)
	check("no_eight_minute_timeout",not paused and not game.paused and not game.defeated)
	game._set_shark_heads(3);game.player.position=Vector3(0,40,-35);game.visual.position=Vector3.ZERO
	game.shark_heads.update_sockets();await physics_frame;await physics_frame
	var target:Node3D=game.fx.make_civilian(999);game.add_child(target)
	target.global_position=game.shark_heads.sockets[-1].global_position;game.targets.append(target)
	check("side_mouth_can_capture",game._can_eat(target,false))
	var socket_ref:WeakRef=target.get_meta("mutation_socket")
	game._capture_target(game.targets.find(target))
	check("capture_tracks_correct_socket",socket_ref.get_ref() in game.shark_heads.sockets)
	game._set_shark_heads(1);game.fx.update(1.0)
	await process_frame
	check("capture_survives_form_switch",not is_instance_valid(target))
	game.health=100;game.take_damage(10)
	check("no_mutation_damage_reduction",game.health==90)
	game.take_damage(1000)
	check("original_death_without_revival",game.defeated and paused and game.health==0)
	var passed:=true
	for value in checks.values():if not value:passed=false
	checks["passed"]=passed
	FileAccess.open("res://research/freeplay_multihead_tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	paused=false;quit(0 if passed else 1)
