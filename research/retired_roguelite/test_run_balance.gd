extends SceneTree
var results:Dictionary={}
func _init()->void:call_deferred("test")
func check(label:String,passed:bool)->void:
	results[label]=passed;print("BALANCE ",label," ",passed)
func test()->void:
	change_scene_to_file("res://scenes/main.tscn")
	while current_scene==null:await process_frame
	var game:Node3D=current_scene
	while not game.ready_done:await process_frame
	game.set_physics_process(false);game.set_process(false)
	var run:Node=game.rogue;run.start_run()
	check("food_budget_leaves_objective_margin",game.targets.size()>=run.BALANCE.MAX_GROWTH_MEALS*1.3)
	# A speed-focused player cannot buy an endgame body in the first few meals.
	run.primary="hydra";run.ranks={"hydra":1};run.picks=1
	check("cannot_chain_first_two_body_ranks",not run.legal("hydra"))
	run.picks=2;check("second_body_rank_at_third_choice",run.legal("hydra"))
	run.ranks={"hydra":2};run.picks=4;check("third_body_rank_still_locked",not run.legal("hydra"))
	run.picks=5;check("third_body_rank_available_midrun",run.legal("hydra"))
	run.ranks={"hydra":3};run.picks=7;check("final_body_rank_still_locked",not run.legal("hydra"))
	run.picks=8;check("final_body_rank_available_late",run.legal("hydra"))
	# Restore the run, isolate combat fixtures above the actual city colliders.
	run.ranks={};run.picks=10;run.organs.rebuild(run.ranks)
	for target in game.targets:target.queue_free()
	game.targets.clear();game.player.position=Vector3(0,40,-35);game.visual.position=Vector3.ZERO
	await physics_frame;await physics_frame
	for i in 8:
		var target:Node3D=game.fx.make_civilian(i);game.add_child(target);target.global_position=run.organs.primary_mouth();game.targets.append(target)
	game._bite()
	check("main_bite_cannot_swallow_entire_crowd",game.fx.captures.size()==1)
	game._bite()
	check("active_spam_cannot_bypass_bite_cooldown",game.fx.captures.size()==1)
	check("passive_capture_shares_main_cooldown",not game._capture_target(0))
	run.update(0.91);game._bite()
	check("main_bite_recovers",game.fx.captures.size()==2)
	game.health=50;game.fx.update(1.0)
	check("base_healing_is_not_double_counted",is_equal_approx(game.health,54))
	for target in game.targets:target.queue_free()
	game.targets.clear();run.ranks={"hydra":4};run.organs.rebuild(run.ranks);run.mouth_cooldown=0
	for socket in run.organs.heads:
		for i in 2:
			var target:Node3D=game.fx.make_civilian(i);game.add_child(target);target.global_position=socket.global_position;game.targets.append(target)
	run.update(0.01)
	check("nine_heads_have_bounded_burst",game.fx.captures.size()==3)
	run.update(0.1)
	check("side_heads_respect_their_cooldown",game.fx.captures.size()==3)
	run.update(1.2)
	check("side_heads_recover",game.fx.captures.size()==6)
	game.fx.update(1.0)
	run.ranks={"zombie":4,"heal":2};game.health=50;game._finish_meal(game.player.position)
	check("stacked_heal_is_bounded",is_equal_approx(game.health,60))
	check("old_victory_food_no_longer_maximizes_growth",run.BALANCE.growth_for(52)<2.3)
	check("normal_building_break_unlocked_before_midrun",run.BALANCE.growth_for(27)>=game.BUILDING_GROWTH)
	game.player.position=run.landmark.global_position+Vector3(0,2,-3);game.player.velocity=Vector3(0,0,10);game.boost_time=1
	game.growth=run.BALANCE.growth_for(179);check("objective_does_not_unlock_one_meal_early",not run.landmark.try_hit())
	game.growth=run.BALANCE.growth_for(180);check("objective_unlocks_at_advertised_food",run.landmark.try_hit())
	var passed:=true
	for value in results.values():if not value:passed=false
	results["passed"]=passed
	FileAccess.open("res://research/run_balance_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	paused=false;quit(0 if passed else 1)
