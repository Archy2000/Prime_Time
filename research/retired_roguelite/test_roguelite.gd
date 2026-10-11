extends SceneTree
var game:Node3D
var run:Node
var results:Dictionary={}

func _init()->void:call_deferred("test")
func check(name:String,value:bool)->void:
	results[name]=value;print("CHECK ",name," ",value)

func shot(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	run.refresh_hud()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/roguelite_"+name+".png")

func test()->void:
	if FileAccess.file_exists("user://roguelite_test_records.json"):DirAccess.remove_absolute("user://roguelite_test_records.json")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	while current_scene==null:await process_frame
	game=current_scene
	while not game.ready_done:await process_frame
	game.set_physics_process(false);game.set_process(false);run=game.rogue
	check("run_loaded",run!=null)
	check("briefing_pauses",run.briefing and paused)
	await shot("briefing");run.start_run()
	# Initial screen renders the real scene, not a mockup.
	await shot("hud")
	for i in run.THRESHOLDS[0]:game._finish_meal(game.player.position)
	await process_frame
	check("first_choice_pauses",run.choosing and paused and game.paused and run.offers==run.FAMILIES)
	var before:float=game.elapsed;var seconds:float=run.seconds
	await process_frame;run.update(1)
	check("choice_freezes_world",game.elapsed==before and run.seconds==seconds)
	await shot("choice")
	run.choose(0)
	check("first_pick_hydra",run.primary=="hydra" and run.rank("hydra")==1 and run.organs.heads.size()==1 and not paused)
	# Queue a batch across two thresholds; each selection opens the next reward.
	for i in run.THRESHOLDS[2]-run.THRESHOLDS[0]:game._finish_meal(game.player.position)
	await process_frame
	check("batch_reward_first",run.choosing and run.picks==1)
	check("second_pick_cannot_rush_hydra",not run.offers.has("hydra"))
	run.choose(0);await process_frame
	check("batch_reward_second",run.choosing and run.picks==2)
	run.choose(run.offers.find("hydra"));await process_frame
	check("batch_queue_drained",run.picks==3 and not run.choosing and not paused)
	run.ranks={"hydra":4,"kraken":2};run.primary="hydra";run.organs.rebuild(run.ranks)
	check("family_limits",not run.legal("hydra") and not run.legal("kraken") and not run.legal("zombie"))
	var valid:=true
	for i in 30:
		var offers:Array=run.make_offers()
		if offers.size()!=3:valid=false
		for id in offers:
			if not run.legal(id):valid=false
	check("draft_only_legal",valid)
	check("nine_heads_and_four_arms",run.organs.heads.size()==8 and run.organs.arms.size()==4)
	# Put the camera on the source shark plus generated organs, above the water.
	game.player.position=Vector3(0,12,-35);game.visual.position=Vector3.ZERO;game.visual.scale=Vector3.ONE*2
	game.camera.position=game.player.position+Vector3(11,12,17);game.camera.look_at(game.player.position,Vector3.UP);game.camera.fov=28
	game.notice.text="程序化原型形态 · 九头鲨 × 四腕"
	await shot("hydra_kraken")
	run.ranks={"kraken":4,"zombie":2};run.primary="kraken";run.organs.rebuild(run.ranks);run.organs.animate(0.2)
	game.notice.text="程序化原型形态 · 深海八腕 × 尸化"
	check("eight_arms_zombie_skin",run.organs.arms.size()==8 and run.organs.zombie_materials.size()>0)
	await shot("kraken_zombie")
	# Verify LOS against a dedicated real physics wall, rather than fixture geometry.
	game.player.position=Vector3(0,30,-35);game.visual.scale=Vector3.ONE;game.growth=1
	var wall:=StaticBody3D.new();wall.collision_layer=1;game.add_child(wall);wall.position=Vector3(1,30.2,-35)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(0.2,3,3);collision.shape=shape;wall.add_child(collision)
	var target:Node3D=game.fx.make_civilian(991);game.add_child(target);target.position=Vector3(2,30.2,-35);game.targets.append(target)
	await physics_frame;await physics_frame
	var mouth:Vector3=game.visual.global_position+Vector3.UP*0.25
	check("tentacle_wall_blocked",not run.visible_target(mouth,target,5))
	wall.queue_free();await physics_frame;await physics_frame
	check("tentacle_clear_sight",run.visible_target(mouth,target,5))
	run.grab_cooldown=0;run.active_bite()
	check("tentacle_actually_captures",target.get_meta("captured",false) and not game.targets.has(target) and run.organs.grab_left>0)
	# A side mouth can reach food outside the normal frontal bite.
	run.ranks={"hydra":4};run.primary="hydra";run.organs.rebuild(run.ranks)
	var side_target:Node3D=game.fx.make_civilian(992);game.add_child(side_target);side_target.position=run.organs.mouths()[-1];game.targets.append(side_target)
	run.mouth_cooldown=0;run.update(0.2)
	check("extra_mouth_actually_captures",side_target.get_meta("captured",false))
	var mouth_ref:WeakRef=side_target.get_meta("mutation_socket")
	check("capture_uses_its_own_mouth",mouth_ref!=null and is_instance_valid(mouth_ref.get_ref()))
	game.fx.update(0.16)
	run.ranks={"zombie":4};run.primary="zombie";run.organs.rebuild(run.ranks)
	game.fx.update(0.20)
	check("capture_survives_model_replacement",not is_instance_valid(mouth_ref.get_ref()) and game.fx.captures.is_empty())
	check("base_model_restored",game.visual.get_node("PS1Shark").visible and run.organs.hydra_model==null)
	game.health=100;game.take_damage(10);check("zombie_damage_reduction",is_equal_approx(game.health,94))
	game.take_damage(1000);check("zombie_revives_once",game.health==45 and run.revivals==1 and not game.defeated and not run.revive())
	game.player.position=Vector3(0,12,-35);game.visual.scale=Vector3.ONE*2;game.camera.look_at(game.player.position,Vector3.UP)
	await shot("zombie")
	# Real input dispatch for card hotkeys, and guarded Escape.
	run.ranks={};run.primary="";run.picks=0;game.eaten=run.THRESHOLDS[0];run.open_choice()
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape)
	check("escape_cannot_bypass_choice",paused and run.choosing)
	var input:=InputEventKey.new();input.physical_keycode=KEY_3;input.pressed=true;root.push_input(input)
	check("keyboard_card_selection",run.rank("zombie")==1 and not run.choosing)
	# Objective requires growth, proximity, actual movement and a fresh dash.
	game.player.position=run.landmark.global_position+Vector3(0,2,-3);game.player.velocity=Vector3(0,0,10);game.boost_time=1
	game.growth=1;check("landmark_growth_gate",not run.landmark.try_hit())
	game.growth=3.2;game.player.position.x=40;check("landmark_distance_gate",not run.landmark.try_hit());game.player.position.x=0
	check("landmark_first_hit",run.landmark.try_hit())
	check("one_hit_per_dash",not run.landmark.try_hit())
	for i in 2:run.dash_serial+=1;run.landmark.try_hit()
	check("landmark_collapse_started",run.landmark.hits==3 and run.landmark.collapse_age==0)
	game.camera.position=run.landmark.global_position+Vector3(25,25,38);game.camera.look_at(run.landmark.global_position+Vector3.UP*8);game.camera.fov=30
	run.landmark.update(1.4);await shot("collapse");run.landmark.update(1.4)
	check("victory_and_record",run.finished and paused and run.records.wins==1 and run.records.best_score>0)
	await shot("victory")
	# Reload is part of the playable loop, and clears all transient build state.
	run.restart();await process_frame
	while current_scene==null:await process_frame
	game=current_scene
	while not game.ready_done:await process_frame
	game.set_physics_process(false);run=game.rogue
	check("restart_resets",run.ranks.is_empty() and run.picks==0 and not run.finished and run.briefing and game.eaten==0)
	check("record_persists",run.records.wins==1 and run.records.best_score>0)
	run.start_run()
	run.seconds=run.duration-0.1;run.update(0.2)
	check("timeout_finishes",run.finished and paused)
	run.restart();await process_frame
	while current_scene==null:await process_frame
	game=current_scene
	while not game.ready_done:await process_frame
	game.set_physics_process(false);run=game.rogue;run.start_run();game.take_damage(1000)
	check("death_finishes",run.finished and paused and game.defeated)
	var passed:=true
	for value in results.values():if not value:passed=false
	results["passed"]=passed
	FileAccess.open("res://research/roguelite_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	DirAccess.remove_absolute("user://roguelite_test_records.json")
	print("ROGUELITE_RESULT ",passed);paused=false;quit(0 if passed else 1)
