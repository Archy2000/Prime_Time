extends "res://scripts/water_hydro.gd"
## Simulation runs off the game thread. Rendering reads only completed snapshots.
var task_id:=-1
var impulses:Array=[]
var pending_obstacles:Array=[]
var pending_level:=1.15
var obstacles_pending:=false
var worker_ms:=0.0
var stopped:=false
var deterministic:=false
var completed_rgba:=PackedFloat32Array()
var completed_flow:=PackedFloat32Array()
var completed_image:Image
var completed_flow_image:Image
var worker_impulses:Array=[]
var worker_obstacles:Array=[]
var worker_level:=1.15
var worker_obstacles_pending:=false

func disturb(pos:Vector3,radius:float,power:float,white:float=0.0,momentum:Vector2=Vector2.ZERO)->void:
	impulses.append([pos,radius,power,white,momentum])

func set_obstacles(boxes:Array,water_y:float)->void:
	if deterministic:super.set_obstacles(boxes,water_y)
	else:pending_obstacles=boxes.duplicate();pending_level=water_y;obstacles_pending=true

func sample_surface(pos:Vector3)->Vector3:
	var p:Vector2=(Vector2(pos.x,pos.z)-origin)/cell
	var x:=clampi(int(p.x),1,N-2);var z:=clampi(int(p.y),1,N-2);var i:=z*N+x
	return Vector3(flow_rgba[i*4],rgba[i*4],flow_rgba[i*4+1])

func update(dt:float)->void:
	if stopped:return
	if deterministic:
		if task_id>=0:WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
		if obstacles_pending:super.set_obstacles(pending_obstacles,pending_level);obstacles_pending=false
		for p in impulses:super.disturb(p[0],p[1],p[2],p[3],p[4])
		impulses.clear();super.update(dt);return
	accumulator=minf(accumulator+dt,STEP*2)
	if task_id>=0:
		if not WorkerThreadPool.is_task_completed(task_id):return
		WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
		# Publish immutable completed buffers. Packing 25,600 cells, obstacle
		# rasterization and impulse application all belong to the worker.
		rgba=completed_rgba;flow_rgba=completed_flow
		texture.update(completed_image)
		flow_texture.update(completed_flow_image)
		last_step_ms=worker_ms
	if accumulator<STEP:return
	accumulator-=STEP
	worker_obstacles_pending=obstacles_pending
	if obstacles_pending:
		worker_obstacles=pending_obstacles;worker_level=pending_level;obstacles_pending=false
	worker_impulses=impulses;impulses=[]
	task_id=WorkerThreadPool.add_task(_worker,false,"Shallow water")

func _worker()->void:
	var begin:=Time.get_ticks_usec()
	if worker_obstacles_pending:super.set_obstacles(worker_obstacles,worker_level)
	for p in worker_impulses:super.disturb(p[0],p[1],p[2],p[3],p[4])
	worker_impulses.clear()
	_step()
	var pixels:=PackedFloat32Array();var flows:=PackedFloat32Array()
	pixels.resize(N*N*4);flows.resize(N*N*4)
	for i in N*N:
		pixels[i*4]=height[i];pixels[i*4+1]=floor_height[i];pixels[i*4+2]=foam[i];pixels[i*4+3]=float(solid[i])
		flows[i*4]=vx[i];flows[i*4+1]=vz[i];flows[i*4+2]=next_height[i];flows[i*4+3]=impact[i]
	completed_rgba=pixels;completed_flow=flows
	completed_image=Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,pixels.to_byte_array())
	completed_flow_image=Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,flows.to_byte_array())
	worker_ms=float(Time.get_ticks_usec()-begin)/1000.0

func energy()->float:
	var total:=0.0
	for i in N*N:
		if rgba[i*4+3]<0.5:total+=rgba[i*4]*rgba[i*4]
	return total

func shutdown()->void:
	stopped=true
	if task_id>=0:WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
