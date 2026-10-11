extends SceneTree
## Deterministic input-driven onboarding test. No XP grants or player teleports.
func _init()->void:call_deferred("run_test")
func run_test()->void:
	change_scene_to_file("res://scenes/main.tscn")
	while current_scene==null:await process_frame
	var game:Node3D=current_scene
	while not game.ready_done:await process_frame
	var run:Node=game.rogue;run.start_run();run.rng.seed=9217
	Engine.time_scale=4
	var first_evolution:=-1.0
	var family:="hydra"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
	var start:=Time.get_ticks_msec()
	var milestones:Array[Dictionary]=[]
	var skipped_until:Dictionary={}
	var pursued_id:=0
	var pursued_since:=0.0
	var last_meals:=0
	while game.elapsed<90 and not run.finished and Time.get_ticks_msec()-start<55000:
		if run.choosing:
			if first_evolution<0:first_evolution=game.elapsed
			var index:int=run.offers.find(family)
			for support in ["tail","heal","armor","jaw","dash","frenzy"]:
				if index<0:index=run.offers.find(support)
			run.choose(maxi(0,index))
		var nearest:Node3D
		var distance:=100000.0
		for target in game.targets:
			if not is_instance_valid(target) or target.get_meta("rooftop",false):continue
			if float(skipped_until.get(target.get_instance_id(),0.0))>game.elapsed:continue
			var d:float=target.position.distance_squared_to(game.player.position)
			# The spawn canal is intentionally rich enough to start every build.
			if absf(target.position.x)>5.0:d+=300
			if d<distance:distance=d;nearest=target
		if nearest:
			if pursued_id!=nearest.get_instance_id() or game.eaten!=last_meals:
				pursued_id=nearest.get_instance_id();pursued_since=game.elapsed;last_meals=game.eaten
			elif game.elapsed-pursued_since>6.0:
				# Try other food when a building blocks the straight-line controller.
				skipped_until[pursued_id]=game.elapsed+30.0;pursued_id=0
			var delta:Vector3=nearest.position-game.player.position;delta.y=0;delta=delta.normalized()
			var right:Vector3=game.camera.global_basis.x;right.y=0;right=right.normalized()
			var back:Vector3=game.camera.global_basis.z;back.y=0;back=back.normalized()
			var x:=delta.dot(right);var y:=delta.dot(back)
			Input.action_press("right",maxf(0,x));Input.action_press("left",maxf(0,-x));Input.action_press("back",maxf(0,y));Input.action_press("forward",maxf(0,-y));Input.action_press("bite")
			if game.cooldown<=0:game._start_boost()
		if game.elapsed>=milestones.size()*15:
			milestones.append({"seconds":game.elapsed,"eaten":game.eaten,"position":str(game.player.position),"nearest":str(nearest.position) if nearest else "none"})
		await physics_frame
	for action in ["left","right","forward","back","bite"]:Input.action_release(action)
	var result:={"family":family,"eaten":game.eaten,"upgrades":run.picks,"first_evolution_seconds":first_evolution,"elapsed":game.elapsed,"health":game.health,"pick_history":run.pick_history,"milestones":milestones,"passed":game.eaten>=15 and run.picks>=2 and first_evolution>=4 and first_evolution<60 and run.rank(family)<4}
	FileAccess.open("res://research/balance_play_%s.json"%family,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PLAY_TEST ",result);Engine.time_scale=1;paused=false;quit(0 if result.passed else 1)
