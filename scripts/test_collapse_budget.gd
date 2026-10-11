extends SceneTree
## Deterministic budget, lifetime and pause checks for concurrent collapses.
func _init()->void:call_deferred("run")

func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(0.8).timeout
	var game=current_scene
	game.paused=true
	var parts:Array=game.buildings["JapanStage/JapanHighriser"].parts
	game.collapse_jobs.clear()
	for part in parts:
		game.collapse_jobs.append({"node":part,"impulse":Vector3(2,0,1),"due":game.elapsed})
	var expired:=MeshInstance3D.new()
	game.collapse_jobs.push_front({"node":expired,"impulse":Vector3.ZERO,"due":game.elapsed})
	expired.free()
	var before:int=game.wrecked
	game._process_collapses()
	var checks:Dictionary={"pause_preserves_queue":game.wrecked==before and game.collapse_jobs.size()==parts.size()+1}
	game.paused=false
	# No awaits here: each call represents one physics tick, without unrelated AI.
	var peak:=0
	for tick in 200:
		before=game.wrecked
		game._process_collapses()
		peak=maxi(peak,game.wrecked-before)
		if game.collapse_jobs.is_empty():break
	checks["collapse_parts_per_tick"]=peak
	checks["collapse_budget"]=peak<=game.MAX_COLLAPSE_PARTS_PER_TICK
	checks["queue_drains"]=game.collapse_jobs.is_empty()
	checks["all_parts_collapse"]=true
	for part in parts:
		if not part.get_meta("broken",false):checks.all_parts_collapse=false
	var transfer_peak:=0
	for tick in 30:
		game.fx.update(0.8 if tick==0 else 1.0/60.0)
		transfer_peak=maxi(transfer_peak,game.fx.last_fragment_transfers)
	checks["transfers_per_tick"]=transfer_peak
	checks["transfer_budget"]=transfer_peak<=game.fx.MAX_FRAGMENT_TRANSFERS
	checks["all_masonry_transferred"]=game.fx.fragments.is_empty() and not game.floating_world.stones.is_empty()
	for i in 25:game.fx._smoke_cloud(Vector3(0,2,-24))
	game.fx.update(0.01)
	checks["smoke_capacity"]=game.fx.smoke_clouds.size()==70 and game.fx.smoke_batch.multimesh.visible_instance_count==70
	if DisplayServer.get_name()!="headless":
		game.paused=true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://research/collapse_smoke_batch.png")
	game.fx.update(5)
	checks["smoke_expires"]=game.fx.smoke_clouds.is_empty() and game.fx.smoke_batch.multimesh.visible_instance_count==0
	var children_before:int=game.fx.get_child_count()
	game.fx.burst(Vector3.ZERO,Color(0.38,0.32,0.24),20,1.4,0.2,0.75,3.0,"smoke_single")
	var emitter:CPUParticles3D=game.fx.active_bursts[-1].node
	checks["burst_uses_pool"]=game.fx.get_child_count()==children_before and emitter.emitting and emitter.visible
	game.fx.update(2)
	checks["burst_recycled"]=game.fx.active_bursts.is_empty() and game.fx.transient_count==0 and not emitter.visible
	game.fx.burst(Vector3.ZERO,Color(0.38,0.32,0.24),20,1.4,0.2,0.75,3.0,"smoke_single")
	checks["burst_reuses_emitter"]=game.fx.active_bursts[-1].node==emitter
	checks["passed"]=true
	for value in checks.values():
		if value is bool and not value:checks.passed=false
	FileAccess.open("res://research/collapse_budget_tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("COLLAPSE_BUDGET ",JSON.stringify(checks))
	quit(0 if checks.passed else 1)
