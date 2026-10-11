extends SceneTree
## Async and synchronous solvers must publish identical fields, without exposing
## partially updated buffers to the gameplay/render thread.
func _init()->void:call_deferred("run")

func run()->void:
	var async_sim=load("res://scripts/water_async.gd").new()
	var sync_sim=load("res://scripts/water_hydro.gd").new()
	async_sim.swell_amplitude=0;sync_sim.swell_amplitude=0
	var immutable:=true
	var identical:=true
	for step in 12:
		var level:float=1.15+float(step)*0.05
		var boxes:Array=[AABB(Vector3(-2,-1,-25),Vector3(1,5,8))]
		async_sim.set_obstacles(boxes,level);sync_sim.set_obstacles(boxes,level)
		var pos:=Vector3(1,level,-24+float(step)*0.1)
		async_sim.disturb(pos,1.2,0.08,0.2,Vector2(0.1,0.0))
		sync_sim.disturb(pos,1.2,0.08,0.2,Vector2(0.1,0.0))
		var previous:PackedFloat32Array=async_sim.rgba.duplicate()
		async_sim.update(async_sim.STEP)
		while not WorkerThreadPool.is_task_completed(async_sim.task_id):
			immutable=immutable and async_sim.rgba==previous
			await process_frame
		immutable=immutable and async_sim.rgba==previous
		async_sim.update(0.0);sync_sim.update(sync_sim.STEP)
		identical=identical and async_sim.rgba==sync_sim.rgba
		for i in async_sim.N*async_sim.N:
			identical=identical and async_sim.flow_rgba[i*4]==sync_sim.flow_rgba[i*4] and async_sim.flow_rgba[i*4+1]==sync_sim.flow_rgba[i*4+1] and async_sim.flow_rgba[i*4+3]==sync_sim.flow_rgba[i*4+3]
	var finite:bool=is_finite(async_sim.energy())
	async_sim.shutdown()
	async_sim=null;sync_sim=null
	var result:Dictionary={"steps":12,"published_snapshots_immutable":immutable,"same_height_foam_floor_velocity_impact":identical,"finite_energy":finite,"passed":immutable and identical and finite}
	FileAccess.open("res://research/water_async_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WATER_ASYNC ",result);quit(0 if result.passed else 1)
